//
//  MLXService.swift
//  Central service that handles downloading, caching, and running MLX models.
//

import Foundation
import Hub
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM

@Observable
class MLXService {
    // Curated catalog of models the app knows how to run on-device.
    static let availableModels: [LMModel] = [
        LMModel(name: "llama3.2:1b", configuration: LLMRegistry.llama3_2_1B_4bit, type: .llm),
        LMModel(name: "qwen2.5:1.5b", configuration: LLMRegistry.qwen2_5_1_5b, type: .llm),
        LMModel(name: "smolLM:135m", configuration: LLMRegistry.smolLM_135M_4bit, type: .llm),
        LMModel(name: "qwen3:0.6b", configuration: LLMRegistry.qwen3_0_6b_4bit, type: .llm),
        LMModel(name: "qwen3:1.7b", configuration: LLMRegistry.qwen3_1_7b_4bit, type: .llm),
        LMModel(name: "qwen3:4b", configuration: LLMRegistry.qwen3_4b_4bit, type: .llm),
        LMModel(name: "qwen3:8b", configuration: LLMRegistry.qwen3_8b_4bit, type: .llm),
        LMModel(name: "qwen2.5VL:3b", configuration: VLMRegistry.qwen2_5VL3BInstruct4Bit, type: .vlm),
        LMModel(name: "qwen2VL:2b", configuration: VLMRegistry.qwen2VL2BInstruct4Bit, type: .vlm),
        LMModel(name: "smolVLM", configuration: VLMRegistry.smolvlminstruct4bit, type: .vlm),
        LMModel(name: "acereason:7B", configuration: LLMRegistry.acereason_7b_4bit, type: .llm),
        LMModel(name: "gemma3n:E2B", configuration: LLMRegistry.gemma3n_E2B_it_lm_4bit, type: .llm),
        LMModel(name: "gemma3n:E4B", configuration: LLMRegistry.gemma3n_E4B_it_lm_4bit, type: .llm),
    ]

    // Cache hydrated model containers to avoid redundant disk loads.
    private let modelCache = NSCache<NSString, ModelContainer>()

    @MainActor
    // Download progress exposed to the UI for the currently active task.
    private(set) var modelDownloadProgress: Progress?

    @MainActor
    // Identifier of the model that is presently being fetched.
    private(set) var downloadingModelID: String?

    private func load(model: LMModel) async throws -> ModelContainer {
        // Cap GPU cache usage so the MLX runtime keeps memory in check.
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        ensureDownloadDirectory(for: model)

        // Prefer any in-memory instance already created by earlier calls.
        if let container = modelCache.object(forKey: model.name as NSString) {
            await MainActor.run {
                if DownloadedModelsStore.shared.isDownloaded(model.id) == false {
                    DownloadedModelsStore.shared.markDownloaded(model.id)
                }
            }
            return container
        }

        // Select the correct MLX factory for the requested capability.
        let factory: ModelFactory =
            switch model.type {
            case .llm: LLMModelFactory.shared
            case .vlm: VLMModelFactory.shared
            }

        let shouldIndicateDownload = await MainActor.run { DownloadedModelsStore.shared.isDownloaded(model.id) == false }

        await MainActor.run {
            // Surface which model is in flight only when a fresh download is required.
            if shouldIndicateDownload {
                self.downloadingModelID = model.id
                self.modelDownloadProgress = nil
            } else if self.downloadingModelID == model.id {
                self.downloadingModelID = nil
                self.modelDownloadProgress = nil
            }
        }

        do {
            // Kick off the potentially long-running load, reporting progress back to the main actor.
            let container = try await factory.loadContainer(
                hub: .default,
                configuration: model.configuration
            ) { progress in
                Task { @MainActor in
                    self.modelDownloadProgress = progress
                }
            }

            modelCache.setObject(container, forKey: model.name as NSString)

            await MainActor.run {
                // Reset progress state and mark the download as completed locally.
                self.modelDownloadProgress = nil
                if self.downloadingModelID == model.id {
                    self.downloadingModelID = nil
                }
                DownloadedModelsStore.shared.markDownloaded(model.id)
            }

            return container
        } catch {
            // Clean up partially written artifacts so a retry can succeed cleanly.
            cleanupIncompleteArtifacts(for: model)
            await MainActor.run {
                if self.downloadingModelID == model.id {
                    self.downloadingModelID = nil
                }
                self.modelDownloadProgress = nil
            }
            throw error
        }
    }

    func generate(messages: [Message], model: LMModel) async throws -> AsyncStream<Generation> {
        // Ensure we have a loaded container (cached or fresh) before streaming tokens.
        let modelContainer = try await load(model: model)

        let trimmed: [Message] = {
            if let last = messages.last, last.role == .assistant, last.content.isEmpty {
                // Drop the empty placeholder message used while streaming.
                return Array(messages.dropLast())
            }
            return messages
        }()

        let chat = trimmed.map { message in
            let role: Chat.Message.Role =
                switch message.role {
                case .assistant: .assistant
                case .user: .user
                case .system: .system
                }

            // Map local attachment URLs into MLX-compatible typed inputs.
            let images: [UserInput.Image] = message.images.map { .url($0) }
            let videos: [UserInput.Video] = message.videos.map { .url($0) }

            return Chat.Message(
                role: role,
                content: message.content,
                images: images,
                videos: videos
            )
        }

        let userInput = UserInput(
            chat: chat,
            processing: .init(resize: .init(width: 1024, height: 1024))
        )

        return try await modelContainer.perform { (context: ModelContext) in
            // Prepare tensors, then hand off to the shared generation helper.
            let lmInput = try await context.processor.prepare(input: userInput)
            let parameters = GenerateParameters(temperature: 0.7)
            return try MLXLMCommon.generate(input: lmInput, parameters: parameters, context: context)
        }
    }

    func preload(model: LMModel) async throws {
        // Reuse load() to prime the cache; the discardable result keeps signature simple.
        _ = try await load(model: model)
    }

    func removeDownload(for model: LMModel) async throws {
        // Forget the cached container so a future request reloads from disk.
        modelCache.removeObject(forKey: model.name as NSString)

        let directory = model.configuration.modelDirectory(hub: .default)
        if FileManager.default.fileExists(atPath: directory.path()) {
            // Remove the previously downloaded weight files.
            try FileManager.default.removeItem(at: directory)
        }

        await MainActor.run {
            if self.downloadingModelID == model.id {
                self.downloadingModelID = nil
                self.modelDownloadProgress = nil
            }
            // Persist that the model is no longer available offline.
            DownloadedModelsStore.shared.remove(model.id)
        }
    }

    private func ensureDownloadDirectory(for model: LMModel) {
        let directory = model.configuration.modelDirectory(hub: .default)
        let parent = directory.deletingLastPathComponent()
        do {
            // Ensure both the parent cache directory and target folder exist before downloading.
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            print("⚠️ [MLXService] Failed to create directory: \(directory.path) – \(error)")
        }
    }

    private func cleanupIncompleteArtifacts(for model: LMModel) {
        let root = model.configuration.modelDirectory(hub: .default).deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.path()),
              let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return }
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "incomplete" {
            // MLX writes temporary `.incomplete` files; nuke them so retries are clean.
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
