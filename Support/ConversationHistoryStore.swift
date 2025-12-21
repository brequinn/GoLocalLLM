// Support/ConversationHistoryStore.swift
// Persists chat transcripts locally and exposes them for the history UI.

import Foundation

struct StoredMessage: Codable, Identifiable {
    let id: UUID
    let role: Message.Role
    let content: String
    let status: Message.Status?
    let reasoning: String?
    let images: [String]
    let videos: [String]
    let timestamp: Date

    init(message: Message) {
        self.id = message.id
        self.role = message.role
        self.content = message.content
        self.status = message.status
        self.reasoning = message.reasoning
        self.images = message.images.map { $0.absoluteString }
        self.videos = message.videos.map { $0.absoluteString }
        self.timestamp = message.timestamp
    }

    func asMessage() -> Message {
        let imageURLs = images.compactMap { URL(string: $0) ?? URL(fileURLWithPath: $0) }
        let videoURLs = videos.compactMap { URL(string: $0) ?? URL(fileURLWithPath: $0) }
        return Message(role: role,
                       content: content,
                       status: status,
                       reasoning: reasoning,
                       images: imageURLs,
                       videos: videoURLs)
    }
}

struct ConversationRecord: Codable, Identifiable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [StoredMessage]

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false { return trimmed }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Conversation on \(formatter.string(from: createdAt))"
    }
}

@MainActor
final class ConversationHistoryStore: ObservableObject {
    static let shared = ConversationHistoryStore()

    @Published private(set) var conversations: [ConversationRecord] = []
    @Published private(set) var isLoading = true

    var activeConversationID: UUID? { storage.activeConversationID }

    private struct StoragePayload: Codable {
        var conversations: [ConversationRecord]
        var activeConversationID: UUID?
    }

    private var storage: StoragePayload
    private let storeURL: URL
    private var persistTask: Task<Void, Never>?

    private init() {
        // Use Application Support directory (persistent), with Documents directory as fallback
        // NEVER use temporary directory as it can be cleared by the system!
        let support: URL
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            support = appSupport
        } else if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            support = documents
            print("⚠️ [HistoryStore] Using Documents directory as fallback")
        } else {
            fatalError("Cannot access persistent storage directories")
        }

        storeURL = support.appendingPathComponent("ConversationHistory", isDirectory: true)
            .appendingPathComponent("history.json")

        print("💾 [HistoryStore] Storing conversations at: \(storeURL.path)")

        // Initialize with empty storage, load asynchronously
        storage = StoragePayload(conversations: [], activeConversationID: nil)

        // Load history in background to avoid blocking UI
        Task {
            await self.loadHistory()
        }
    }

    private func loadHistory() async {
        let url = storeURL
        let payload = await Task.detached {
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(StoragePayload.self, from: data) else {
                return StoragePayload(conversations: [], activeConversationID: nil)
            }
            return decoded
        }.value

        await MainActor.run {
            self.storage = payload
            self.conversations = payload.conversations.sorted { $0.updatedAt > $1.updatedAt }
            self.isLoading = false
            print("📚 [HistoryStore] Loaded \(self.conversations.count) conversations")
        }
    }

    func beginNewConversation() -> UUID {
        let id = UUID()
        storage.activeConversationID = id
        persist()
        return id
    }

    func setActiveConversation(_ id: UUID) {
        storage.activeConversationID = id
        persist()
    }

    func updateConversation(id: UUID, messages: [Message]) {
        guard messages.isEmpty == false else { return }
        let storedMessages = messages.map(StoredMessage.init)
        let title = Self.makeTitle(from: storedMessages)
        let now = Date()

        if let index = storage.conversations.firstIndex(where: { $0.id == id }) {
            storage.conversations[index].messages = storedMessages
            storage.conversations[index].title = title
            storage.conversations[index].updatedAt = now
        } else {
            let record = ConversationRecord(id: id,
                                            title: title,
                                            createdAt: now,
                                            updatedAt: now,
                                            messages: storedMessages)
            storage.conversations.append(record)
        }

        storage.conversations.sort { $0.updatedAt > $1.updatedAt }
        conversations = storage.conversations
        persist()
    }

    func conversation(for id: UUID) -> ConversationRecord? {
        storage.conversations.first { $0.id == id }
    }

    func deleteConversation(id: UUID) {
        storage.conversations.removeAll { $0.id == id }
        if storage.activeConversationID == id {
            storage.activeConversationID = nil
        }
        conversations = storage.conversations
        persist()
    }

    func clearAll() {
        storage = StoragePayload(conversations: [], activeConversationID: nil)
        conversations = []
        persist()
    }

    private func persist() {
        let payload = storage
        let url = storeURL
        let previousTask = persistTask

        persistTask = Task.detached(priority: .utility) {
            if let previousTask {
                _ = await previousTask.value
            }
            do {
                let data = try JSONEncoder().encode(payload)
                let directory = url.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

                // Write to a temporary file first for atomic replacement.
                let tempURL = directory.appendingPathComponent("history.tmp")
                try data.write(to: tempURL, options: .atomic)
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
            } catch {
                print("❌ [HistoryStore] Persist failed: \(error.localizedDescription)")
            }
        }
    }

    private static func makeTitle(from messages: [StoredMessage]) -> String {
        if let userMessage = messages.first(where: { $0.role == .user })?.content {
            let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return String(trimmed.prefix(80))
            }
        }
        if let assistantMessage = messages.first(where: { $0.role == .assistant })?.content {
            let trimmed = assistantMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return String(trimmed.prefix(80))
            }
        }
        return "Untitled Conversation"
    }
}
