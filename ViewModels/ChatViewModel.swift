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
    // Model currently active in the UI.
    var selectedModel: LMModel

    // Persists the user's last picked model between launches.
    private let lastModelKey = "lastSelectedModelID"

    init(mlxService: MLXService) {
        self.mlxService = mlxService

        // Try to restore the last-used model, otherwise pick a sensible downloaded/default option.
        if let saved = UserDefaults.standard.string(forKey: lastModelKey),
           let match = MLXService.availableModels.first(where: { $0.id == saved }) {
            self.selectedModel = match
        } else if let downloaded = MLXService.availableModels.first(where: {
            DownloadedModelsStore.shared.isDownloaded($0.id)
        }) {
            self.selectedModel = downloaded
        } else {
            self.selectedModel = MLXService.availableModels.first!
        }
    }

    // High-level UI state mirrored into SwiftUI views.
    var prompt: String = ""
    var messages: [Message] = []
    var mediaSelection = MediaSelection()
    var isGenerating = false
    var isModelLoaded = false

    // Handles streaming tasks and completion metadata.
    private var generateTask: Task<Void, any Error>?
    private var generateCompletionInfo: GenerateCompletionInfo?
    var errorMessage: String?

    // Helpers for filtering tool thoughts and gating haptics.
    private var droppingThought = false
    private var didFireResponseHaptic = false

    // Queue of prompts typed while a previous request is still running.
    private var sendQueue: [Message] = []

    var tokensPerSecond: Double { generateCompletionInfo?.tokensPerSecond ?? 0 }
    var modelDownloadProgress: Progress? { mlxService.modelDownloadProgress }
    var downloadingModelID: String? { mlxService.downloadingModelID }
    // Entire catalog exposed for menus.
    var availableModels: [LMModel] { MLXService.availableModels }
    // Filtered subset for quick switching.
    var downloadedModels: [LMModel] {
        MLXService.availableModels.filter { DownloadedModelsStore.shared.isDownloaded($0.id) }
    }

    func setModel(_ model: LMModel) {
        // Update selection and remember the choice.
        selectedModel = model
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
        }
    }

    // Download heavy models in the background so switching feels instant.
    func preload(model: LMModel) async {
        do {
            if model.id == selectedModel.id {
                isModelLoaded = false
            }
            try await mlxService.preload(model: model)
            if model.id == selectedModel.id {
                isModelLoaded = true
            }
            print("📦 [ChatVM] Preloaded model: \(model.name)")
        } catch {
            if model.id == selectedModel.id {
                isModelLoaded = false
            }
            print("❌ [ChatVM] Preload failed: \(error.localizedDescription)")
        }
    }

    // Called when the app launches or the picker chooses a new model.
    func preloadSelected() async {
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
            print("🗑️ [ChatVM] Removed download: \(model.name)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [ChatVM] Remove failed: \(error.localizedDescription)")
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
            sendQueue.append(userMsg)
            print("⏳ [ChatVM] Busy, queued prompt, queue size: \(sendQueue.count)")
            return
        }

        isGenerating = true
        droppingThought = false
        didFireResponseHaptic = false

        // Append user message to the transcript so it shows immediately.
        messages.append(userMsg)
        print("✉️ [ChatVM] User -> \"\(userMsg.content)\"")

        // Placeholder assistant line used for streaming tokens in-place.
        let assistant = Message.assistant("")
        messages.append(assistant)

        // History passed to the model excludes the empty streaming placeholder.
        let messagesForModel = Array(messages.dropLast())
        print("📚 [ChatVM] Sending \(messagesForModel.count) messages as context to \(selectedModel.name)")

        // Cancel any orphaned tasks to avoid double streaming.
        if let existing = generateTask {
            existing.cancel()
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
                            let visible = self.filterThinking(from: chunk)
                            if !visible.isEmpty {
                                if !self.didFireResponseHaptic {
                                    self.didFireResponseHaptic = true
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                last.content += visible
                            }
                        }
                        print("📝 [ChatVM] Chunk: \(chunk.replacingOccurrences(of: "\n", with: "\\n"))")
                    case .info(let info):
                        self.generateCompletionInfo = info
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        print("ℹ️ [ChatVM] Done. \(info.tokensPerSecond) tok/s")
                    case .toolCall:
                        print("🛠️ [ChatVM] Tool call")
                    }
                }
                print("✅ [ChatVM] Generation complete")
            } catch is CancellationError {
                print("🚫 [ChatVM] Generation cancelled")
                if let last = self.messages.last { last.content += "\n[Cancelled]" }
            } catch {
                self.errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                print("❌ [ChatVM] Generation failed: \(error.localizedDescription)")
            }
        }
    }

    private func processQueueIfNeeded() async {
        // Run the next queued prompt if the pipeline is idle.
        guard !isGenerating, sendQueue.isEmpty == false else { return }
        let next = sendQueue.removeFirst()
        print("📤 [ChatVM] Dequeuing prompt, remaining: \(sendQueue.count)")
        await generate(with: next)
    }

    // Filter out <think> ... </think> meta sections the model may emit.
    private func filterThinking(from chunk: String) -> String {
        var out = ""
        var i = chunk.startIndex
        while i < chunk.endIndex {
            if !droppingThought, let start = chunk[i...].range(of: "<think>") {
                out += chunk[i..<start.lowerBound]
                i = start.upperBound
                droppingThought = true
            } else if droppingThought, let end = chunk[i...].range(of: "</think>") {
                i = end.upperBound
                droppingThought = false
            } else {
                if !droppingThought { out.append(chunk[i]) }
                i = chunk.index(after: i)
            }
        }
        return out
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
        if options.contains(.chat) { messages = []; generateTask?.cancel(); print("🧹 [ChatVM] Cleared chat history") }
        if options.contains(.meta) { generateCompletionInfo = nil; print("🧹 [ChatVM] Cleared metadata") }
        errorMessage = nil
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
