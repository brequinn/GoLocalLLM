//
//  ChatViewModel.swift
//  Central state machine that orchestrates chat messaging, model lifecycle, and UI feedback.
//

import Foundation
import MLXLMCommon
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@Observable
@MainActor
class ChatViewModel {
    // MLX integration layer used for loading models and generating responses.
    private let mlxService: MLXService
    private let historyStore = ConversationHistoryStore.shared
    // Model currently active in the UI.
    var selectedModel: LMModel = MLXService.defaultModel
    private var activeConversationID: UUID?

    // Persists the user's last picked model between launches.
    private let lastModelKey = "lastSelectedModelID"

    init(mlxService: MLXService) {
        self.mlxService = mlxService
        self.downloadingModelID = mlxService.downloadingModelID
        self.modelDownloadProgress = mlxService.modelDownloadProgress

        mlxService.downloadStateDidChange = { @MainActor [weak self] id, progress in
            guard let self else { return }
            self.downloadingModelID = id
            self.modelDownloadProgress = progress
        }

        // Try to restore the last-used model, otherwise pick a sensible downloaded/default option.
        if let saved = UserDefaults.standard.string(forKey: lastModelKey),
           let match = MLXService.availableModels.first(where: { $0.id == saved }) {
            self.selectedModel = match
        } else if let downloaded = MLXService.availableModels.first(where: {
            DownloadedModelsStore.shared.isDownloaded($0.id)
        }) {
            self.selectedModel = downloaded
        } else {
            self.selectedModel = MLXService.defaultModel
        }

        if DownloadedModelsStore.shared.isDownloaded(selectedModel.id) {
            isModelLoaded = true
        }

        if let storedID = historyStore.activeConversationID,
           let record = historyStore.conversation(for: storedID) {
            self.activeConversationID = storedID
            self.messages = record.messages.map { $0.asMessage() }
        } else {
            self.activeConversationID = historyStore.beginNewConversation()
        }
    }

    // High-level UI state mirrored into SwiftUI views.
    var prompt: String = ""
    var messages: [Message] = []
    var mediaSelection = MediaSelection()
    var isGenerating = false
    var isModelLoaded = false
    var downloadingModelID: String?
    var modelDownloadProgress: Progress?

    // Handles streaming tasks and completion metadata.
    private var generateTask: Task<Void, any Error>?
    private var generateCompletionInfo: GenerateCompletionInfo?
    var errorMessage: String?

    // Helpers for filtering tool thoughts and gating haptics.
    private var droppingThought = false
    private var didFireResponseHaptic = false
    private var didUserCancelGeneration = false

    // Queue of prompts typed while a previous request is still running.
    private var sendQueue: [Message] = []
    private let maxQueueSize = 10

    // Track preload task for cancellation
    private var preloadTask: Task<Void, Never>?
    // Remember if we've already kicked off the initial auto-download so we don't loop
    private var didAutoStartFirstDownload = false

    var tokensPerSecond: Double { generateCompletionInfo?.tokensPerSecond ?? 0 }
    // Entire catalog exposed for menus.
    var availableModels: [LMModel] { MLXService.availableModels }
    // Filtered subset for quick switching.
    var downloadedModels: [LMModel] {
        MLXService.availableModels.filter { DownloadedModelsStore.shared.isDownloaded($0.id) }
    }

    func setModel(_ model: LMModel) {
        // Update selection and remember the choice.
        selectedModel = model
        isModelLoaded = DownloadedModelsStore.shared.isDownloaded(model.id)
        UserDefaults.standard.set(model.id, forKey: lastModelKey)
    }

    func refreshDefaultFromDownloads() {
        // If the current pick disappeared, fall back to the first downloaded option.
        if DownloadedModelsStore.shared.isDownloaded(selectedModel.id) { return }
        if let downloaded = MLXService.availableModels.first(where: {
            DownloadedModelsStore.shared.isDownloaded($0.id)
        }) {
            selectedModel = downloaded
            UserDefaults.standard.set(downloaded.id, forKey: lastModelKey)
        } else {
            let fallback = MLXService.defaultModel
            selectedModel = fallback
            UserDefaults.standard.set(fallback.id, forKey: lastModelKey)
        }
    }

    // Explicitly download a model (called when user taps "Download" button)
    func downloadModel(_ model: LMModel) async {
        // Cancel any existing preload task
        preloadTask?.cancel()

        preloadTask = Task {
            do {
                if model.id == selectedModel.id {
                    isModelLoaded = false
                }
                print("⬇️ [ChatVM] Starting explicit download for: \(model.name)")
                try await mlxService.preload(model: model)
                if model.id == selectedModel.id {
                    isModelLoaded = true
                }
                print("✅ [ChatVM] Downloaded and loaded model: \(model.name)")
            } catch is CancellationError {
                print("🚫 [ChatVM] Download cancelled for: \(model.name)")
            } catch {
                if model.id == selectedModel.id {
                    isModelLoaded = false
                }
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                print("❌ [ChatVM] Download failed: \(error.localizedDescription)")
            }
        }

        await preloadTask?.value
    }

    // Load models in the background so switching feels instant (only for downloaded models).
    func preload(model: LMModel) async {
        // Only preload models that are already downloaded
        guard DownloadedModelsStore.shared.isDownloaded(model.id) else {
            print("⏭️ [ChatVM] Skipping preload for \(model.name) - not downloaded")
            if model.id == selectedModel.id {
                isModelLoaded = false
            }
            return
        }

        // Cancel any existing preload task to avoid concurrent loads
        preloadTask?.cancel()

        preloadTask = Task {
            do {
                if model.id == selectedModel.id {
                    isModelLoaded = false
                }
                try await mlxService.preload(model: model)
                if model.id == selectedModel.id {
                    isModelLoaded = true
                }
                print("📦 [ChatVM] Preloaded model: \(model.name)")
            } catch is CancellationError {
                print("🚫 [ChatVM] Preload cancelled for: \(model.name)")
            } catch {
                if model.id == selectedModel.id {
                    isModelLoaded = false
                }
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                print("❌ [ChatVM] Preload failed: \(error.localizedDescription)")
            }
        }

        await preloadTask?.value
    }

    // Called when the app launches or the picker chooses a new model.
    func preloadSelected() async {
        // Only preload if the model is already downloaded to avoid auto-downloading
        guard DownloadedModelsStore.shared.isDownloaded(selectedModel.id) else {
            if DownloadedModelsStore.shared.ids.isEmpty && didAutoStartFirstDownload == false {
                didAutoStartFirstDownload = true
                print("⬇️ [ChatVM] First launch auto-download for \(selectedModel.name)")
                await downloadModel(selectedModel)
            } else {
                print("⏭️ [ChatVM] Skipping preload for \(selectedModel.name) - not downloaded yet")
                isModelLoaded = false
            }
            return
        }
        await preload(model: selectedModel)
    }

    func removeDownload(for model: LMModel) async {
        do {
            try await mlxService.removeDownload(for: model)
            if model.id == selectedModel.id {
                isModelLoaded = false
                refreshDefaultFromDownloads()
                await preloadSelected()
            }
            print("🗑️ [ChatVM] Removed local copy: \(model.name)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [ChatVM] Remove failed: \(error.localizedDescription)")
        }
    }

    func cancelDownload(for model: LMModel) {
        mlxService.cancelDownload(for: model)
        if model.id == selectedModel.id {
            isModelLoaded = false
        }
    }

    // Public helpers used by the view

    func generateFromCurrentPrompt() async {
        // Validate there is either text or media before kicking off inference.
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && mediaSelection.isEmpty {
            print("⚠️ [ChatVM] Nothing to send")
            return
        }
        let userMsg = Message.user(trimmed, images: mediaSelection.images, videos: mediaSelection.videos)
        clear(.prompt)
        await generate(with: userMsg)
    }

    func enqueueCurrentPrompt() async {
        // Queue the prompt so it runs immediately after the current turn.
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && mediaSelection.isEmpty { return }

        // Prevent unbounded queue growth
        guard sendQueue.count < maxQueueSize else {
            errorMessage = "Queue full. Please wait for current responses to complete."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            print("⚠️ [ChatVM] Queue full, rejecting new prompt")
            return
        }

        let userMsg = Message.user(trimmed, images: mediaSelection.images, videos: mediaSelection.videos)
        sendQueue.append(userMsg)
        clear(.prompt)
        print("📥 [ChatVM] Queued prompt, queue size: \(sendQueue.count)")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // Core generation pipeline that accepts a prepared user message
    private func generate(with userMsg: Message) async {
        // If a run is in progress, just queue and return
        if isGenerating {
            guard sendQueue.count < maxQueueSize else {
                errorMessage = "Queue full. Please wait for current responses to complete."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                print("⚠️ [ChatVM] Queue full, rejecting prompt")
                return
            }
            sendQueue.append(userMsg)
            print("⏳ [ChatVM] Busy, queued prompt, queue size: \(sendQueue.count)")
            return
        }

        isGenerating = true
        droppingThought = false
        didFireResponseHaptic = false
        didUserCancelGeneration = false

        // Append user message to the transcript so it shows immediately.
        messages.append(userMsg)
        print("✉️ [ChatVM] User -> \"\(userMsg.content)\"")
        persistConversationIfNeeded()

        // Placeholder assistant line used for streaming tokens in-place.
        let placeholderStatus: Message.Status = userMsg.images.isEmpty ? .thinking : .analyzingImage
        let assistant = Message.assistant("", status: placeholderStatus)
        messages.append(assistant)

        // History passed to the model excludes the empty streaming placeholder.
        let messagesForModel = prepareMessagesForModel(from: messages)
        print("📚 [ChatVM] Sending \(messagesForModel.count) messages as context to \(selectedModel.name)")

        // Cancel any orphaned tasks to avoid double streaming.
        if let existing = generateTask {
            existing.cancel()
            // Await cancellation to ensure cleanup completes
            _ = await existing.result
            generateTask = nil
        }

        generateTask = Task {
            defer {
                Task { @MainActor in
                    self.isGenerating = false
                    self.generateTask = nil
                    await self.processQueueIfNeeded()
                }
            }

            do {
                for await generation in try await mlxService.generate(messages: messagesForModel, model: selectedModel) {
                    switch generation {
                    case .chunk(let chunk):
                        if let last = self.messages.last {
                            let parsed = self.extractVisibleAndReasoning(from: chunk)
                            if let reasoning = parsed.reasoning, !reasoning.isEmpty {
                                if last.reasoning == nil {
                                    last.reasoning = reasoning
                                } else {
                                    last.reasoning? += reasoning
                                }
                            }

                            if !parsed.visible.isEmpty {
                                if !self.didFireResponseHaptic {
                                    self.didFireResponseHaptic = true
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                last.content += parsed.visible
                            }
                        }
                        #if DEBUG
                        print("📝 [ChatVM] Chunk: \(chunk.replacingOccurrences(of: "\n", with: "\\n"))")
                        #endif
                    case .info(let info):
                        self.generateCompletionInfo = info
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        print("ℹ️ [ChatVM] Done. \(info.tokensPerSecond) tok/s")
                    case .toolCall:
                        print("🛠️ [ChatVM] Tool call")
                    }
                }
                print("✅ [ChatVM] Generation complete")
                self.persistConversationIfNeeded()
            } catch is CancellationError {
                print("🚫 [ChatVM] Generation cancelled")
                if self.didUserCancelGeneration {
                    self.didUserCancelGeneration = false
                } else if let last = self.messages.last {
                    last.content += "\n[Cancelled]"
                }
                self.persistConversationIfNeeded()
            } catch {
                self.errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                print("❌ [ChatVM] Generation failed: \(error.localizedDescription)")
                self.persistConversationIfNeeded()
            }
        }
    }

    func cancelGeneration() {
        guard isGenerating else { return }
        didUserCancelGeneration = true
        sendQueue.removeAll()
        generateTask?.cancel()
        print("🛑 [ChatVM] Stop requested by user")
    }

    private func processQueueIfNeeded() async {
        // Run the next queued prompt if the pipeline is idle.
        guard !isGenerating, sendQueue.isEmpty == false else { return }
        let next = sendQueue.removeFirst()
        print("📤 [ChatVM] Dequeuing prompt, remaining: \(sendQueue.count)")
        await generate(with: next)
    }

    // Split streaming chunks into visible text and hidden reasoning emitted inside <think> tags.
    private func extractVisibleAndReasoning(from chunk: String) -> (visible: String, reasoning: String?) {
        var visible = ""
        var reasoning = ""
        var i = chunk.startIndex
        while i < chunk.endIndex {
            if !droppingThought, let start = chunk[i...].range(of: "<think>") {
                visible += chunk[i..<start.lowerBound]
                i = start.upperBound
                droppingThought = true
            } else if droppingThought, let end = chunk[i...].range(of: "</think>") {
                i = end.upperBound
                droppingThought = false
            } else {
                if droppingThought {
                    reasoning.append(chunk[i])
                } else {
                    visible.append(chunk[i])
                }
                i = chunk.index(after: i)
            }
        }
        return (visible, reasoning.isEmpty ? nil : reasoning)
    }

    private func prepareMessagesForModel(from messages: [Message]) -> [Message] {
        let trimmed = Array(messages.dropLast())
        var systemMessages: [Message] = []

        let personalityPrompt = AppSettings.shared.selectedAssistant.systemPrompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if personalityPrompt.isEmpty == false {
            systemMessages.append(Message.system(personalityPrompt))
        }

        systemMessages.append(
            Message.system("Respond in English only.")
        )

        if AppSettings.shared.showModelReasoning == false {
            systemMessages.append(
                Message.system("Do not reveal your chain-of-thought or internal reasoning. Reply with the final answer only.")
            )
        }

        guard systemMessages.isEmpty == false else { return trimmed }
        return systemMessages + trimmed
    }

    func attachCapturedImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        do {
            try data.write(to: url, options: .atomic)
            mediaSelection.images = [url]
            mediaSelection.videos = []
            print("📸 [ChatVM] Captured image added")
        } catch {
            print("❌ [ChatVM] Failed to persist captured image: \(error.localizedDescription)")
        }
    }

    func loadMedia(from item: PhotosPickerItem) async {
        // Handle images and videos; unsupported types trigger a warning.
        do {
            if let imageType = item.supportedContentTypes.first(where: { $0.conforms(to: UTType.image) }),
               let data = try await item.loadTransferable(type: Data.self) {
                let ext = imageType.preferredFilenameExtension ?? "img"
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(ext)
                try data.write(to: url, options: .atomic)
                mediaSelection.images = [url]
                mediaSelection.videos = []
                print("🖼️ [ChatVM] Added image from Photos picker")
                return
            }

            if let _ = item.supportedContentTypes.first(where: { $0.conforms(to: UTType.movie) }),
               let url = try await item.loadTransferable(type: URL.self) {
                mediaSelection.images = []
                mediaSelection.videos = [url]
                print("🎬 [ChatVM] Added video from Photos picker")
                return
            }

            errorMessage = "Unsupported media type selected."
            print("⚠️ [ChatVM] Unsupported media type from Photos picker")
        } catch {
            errorMessage = "Failed to load media item.\n\nError: \(error.localizedDescription)"
            print("❌ [ChatVM] Failed to load media: \(error.localizedDescription)")
        }
        mediaSelection.isShowing = false
    }

    func clear(_ options: ClearOption) {
        // Reset specific slices of state depending on the flags provided.
        if options.contains(.prompt) { prompt = ""; mediaSelection = .init(); print("🧹 [ChatVM] Cleared prompt and media") }
        if options.contains(.chat) {
            if messages.isEmpty == false { persistConversationIfNeeded() }
            messages = []
            generateTask?.cancel()
            activeConversationID = historyStore.beginNewConversation()
            print("🧹 [ChatVM] Cleared chat history")
        }
        if options.contains(.meta) { generateCompletionInfo = nil; print("🧹 [ChatVM] Cleared metadata") }
        errorMessage = nil
    }

    private func persistConversationIfNeeded() {
        guard messages.isEmpty == false else { return }
        let id = ensureActiveConversationID()
        historyStore.updateConversation(id: id, messages: messages)
    }

    private func ensureActiveConversationID() -> UUID {
        if let id = activeConversationID { return id }
        if let storedID = historyStore.activeConversationID {
            activeConversationID = storedID
            return storedID
        }
        let newID = historyStore.beginNewConversation()
        activeConversationID = newID
        return newID
    }
}

@Observable
class MediaSelection {
    // Whether the photo picker sheet is currently open.
    var isShowing = false
    // Security-scoped URLs for image attachments chosen by the user.
    var images: [URL] = [] { didSet { didSetURLs(oldValue, images) } }
    // Security-scoped URLs for video attachments.
    var videos: [URL] = [] { didSet { didSetURLs(oldValue, videos) } }
    var isEmpty: Bool { images.isEmpty && videos.isEmpty }

    private func didSetURLs(_ old: [URL], _ new: [URL]) {
        // Start accessing new security-scoped resources and release any that were removed.
        new.filter { !old.contains($0) }.forEach { _ = $0.startAccessingSecurityScopedResource() }
        old.filter { !new.contains($0) }.forEach { $0.stopAccessingSecurityScopedResource() }
    }
}

struct ClearOption: RawRepresentable, OptionSet {
    let rawValue: Int
    // Reset the input prompt and attachments.
    static let prompt = ClearOption(rawValue: 1 << 0)
    // Remove all transcript messages.
    static let chat = ClearOption(rawValue: 1 << 1)
    // Drop any stored metadata like token timings.
    static let meta = ClearOption(rawValue: 1 << 2)
}
