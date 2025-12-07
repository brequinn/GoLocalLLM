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

enum MLXServiceError: LocalizedError {
    case storageLimitReached(limit: Int64)

    var errorDescription: String? {
        switch self {
        case .storageLimitReached(let limit):
            let formatted = ByteCountFormatter.string(fromByteCount: limit, countStyle: .file)
            return "Downloading this model would exceed the storage limit of \(formatted). Remove an existing download first."
        }
    }
}

@Observable
class MLXService {
    // Curated catalog of models the app knows how to run on-device.
    static let availableModels: [LMModel] = [
        LMModel(
            name: "llama3.2:1b",
            configuration: LLMRegistry.llama3_2_1B_4bit,
            type: .llm,
            summary: "Meta's efficient 1B-parameter Llama that balances speed and helpfulness for everyday chats.",
            icon: .init(representation: .emoji("🦙")),
            badges: [.init(kind: .recommended, label: "Balanced")]
        ),
        LMModel(
            name: "gemma3:1b",
            configuration: LLMRegistry.gemma3_1B_qat_4bit,
            type: .llm,
            summary: "Google's latest Gemma 3 1B model tuned for on-device use—great quality while staying fast. Recommended pick.",
            icon: .init(representation: .emoji("💡")),
            badges: [.init(kind: .recommended, label: "Recommended")]
        ),
        LMModel(
            name: "gemma2:2b",
            configuration: LLMRegistry.gemma_2_2b_it_4bit,
            type: .llm,
            summary: "Reliable 2B Gemma model that trades a bit of speed for richer, more expressive answers.",
            icon: .init(representation: .emoji("💎"))
        ),
        LMModel(
            name: "qwen2.5:1.5b",
            configuration: LLMRegistry.qwen2_5_1_5b,
            type: .llm,
            summary: "AliBaba's multilingual 1.5B model tuned for strong reasoning across long conversations.",
            icon: .init(representation: .emoji("🐼")),
            badges: [.init(kind: .reasoning, label: "Thinking")]
        ),
       // LMModel(name: "smolLM:135m", configuration: LLMRegistry.smolLM_135M_4bit, type: .llm),
        LMModel(
            name: "qwen3:0.6b",
            configuration: LLMRegistry.qwen3_0_6b_4bit,
            type: .llm,
            summary: "Ultra-fast 600M Qwen family model—great for lightweight summarization and drafting.",
            icon: .init(representation: .emoji("⚡️")),
            badges: []
        ),
        LMModel(
            name: "lfm2:700m",
            configuration: LLMRegistry.lfm2_700m_4bit,
            type: .llm,
            summary: "LiquidAI's compact 700M LFM2 assistant for fun wordplay, creative riffs, and casual chatting.",
            icon: .init(representation: .emoji("💧"))
        ),
       // LMModel(name: "qwen3:1.7b", configuration: LLMRegistry.qwen3_1_7b_4bit, type: .llm),
        LMModel(
            name: "qwen3:4b",
            configuration: LLMRegistry.qwen3_4b_4bit,
            type: .llm,
            summary: "Higher-capacity Qwen 3 model for deeper reasoning and code assistance when you need more quality.",
            icon: .init(representation: .emoji("🧠")),
            badges: [.init(kind: .reasoning, label: "Thinking")]
        ),
        LMModel(
            name: "deepseek-r1:qwen-1.5b",
            configuration: LLMRegistry.deepseek_r1_distill_qwen_1_5b_4bit,
            type: .llm,
            summary: "DeepSeek's reasoning-focused R1 distilled into a nimble 1.5B Qwen variant. Excellent for structured thinking. Recommended.",
            icon: .init(representation: .emoji("🧭")),
            badges: [
                .init(kind: .recommended, label: "Recommended"),
                .init(kind: .reasoning, label: "Thinking")
            ]
        ),
//        LMModel(name: "qwen3:8b", configuration: LLMRegistry.qwen3_8b_4bit, type: .llm),
//        LMModel(name: "qwen2.5VL:3b", configuration: VLMRegistry.qwen2_5VL3BInstruct4Bit, type: .vlm),
        LMModel(
            name: "qwen2VL:2b",
            configuration: VLMRegistry.qwen2VL2BInstruct4Bit,
            type: .vlm,
            summary: "Vision-enabled Qwen model that can understand images alongside text for multimodal tasks.",
            icon: .init(representation: .emoji("🖼️")),
            badges: [.init(kind: .vision, label: "Vision")]
        ),
       // LMModel(name: "smolVLM", configuration: VLMRegistry.smolvlminstruct4bit, type: .vlm),
       // LMModel(name: "acereason:7B", configuration: LLMRegistry.acereason_7b_4bit, type: .llm),
       // LMModel(name: "gemma3n:E2B", configuration: LLMRegistry.gemma3n_E2B_it_lm_4bit, type: .llm),
       // LMModel(name: "gemma3n:E4B", configuration: LLMRegistry.gemma3n_E4B_it_lm_4bit, type: .llm),
    ]

    static var defaultModel: LMModel {
        guard let fallback = availableModels.first else {
            fatalError("MLXService.availableModels must not be empty")
        }

        guard let smallest = availableModels.min(by: { lhs, rhs in
            switch (lhs.parameterCountBillionsEstimate, rhs.parameterCountBillionsEstimate) {
            case let (l?, r?):
                if l == r { return lhs.name < rhs.name }
                return l < r
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.name < rhs.name
            }
        }) else {
            return fallback
        }

        return smallest
    }

    // Maximum storage budget allocated for downloaded models (4 GB by default).
    static let storageLimitBytes: Int64 = 4 * 1024 * 1024 * 1024

    // Cache hydrated model containers to avoid redundant disk loads.
    private let modelCache: NSCache<NSString, ModelContainer> = {
        let cache = NSCache<NSString, ModelContainer>()
        cache.countLimit = 1
        return cache
    }()

    @MainActor
    private var loadTasks: [String: Task<ModelContainer, Error>] = [:]

    @MainActor
    // Download progress exposed to the UI for the currently active task.
    private(set) var modelDownloadProgress: Progress?

    @MainActor
    // Identifier of the model that is presently being fetched.
    private(set) var downloadingModelID: String?

    @MainActor
    // Track if user manually cancelled download
    private var cancelledDownloads: Set<String> = []

    @MainActor
    // Tracks the last percentage we logged per model to avoid spamming the console.
    private var lastLoggedProgress: [String: Int] = [:]

    @MainActor
    // Tracks the last completed unit count logged for each model to debug stalls.
    private var lastLoggedUnitCount: [String: Int64] = [:]

    private func load(model: LMModel) async throws -> ModelContainer {
        // Clear cancelled flag on new load attempt
        await MainActor.run { _ = cancelledDownloads.remove(model.id) }

        if let existingTask = await MainActor.run(body: { loadTasks[model.id] }) {
            return try await existingTask.value
        }

        let loadTask = Task { () -> ModelContainer in
            defer { Task { @MainActor in self.loadTasks[model.id] = nil } }
            return try await self.performLoad(model: model)
        }

        await MainActor.run { loadTasks[model.id] = loadTask }

        return try await loadTask.value
    }

    private func performLoad(model: LMModel) async throws -> ModelContainer {
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
                self.lastLoggedProgress[model.id] = nil
                self.lastLoggedUnitCount[model.id] = nil
                print("⬇️ [MLXService] Starting download for \(model.name)")
            } else if self.downloadingModelID == model.id {
                self.downloadingModelID = nil
                self.modelDownloadProgress = nil
                self.lastLoggedUnitCount[model.id] = nil
            }
        }

        if shouldIndicateDownload, Self.storageLimitBytes > 0 {
            let currentUsage = await currentStorageUsage()
            if currentUsage >= Self.storageLimitBytes {
                throw MLXServiceError.storageLimitReached(limit: Self.storageLimitBytes)
            }
        }

        do {
            print("⬇️ [MLXService] loadContainer begin for \(model.name) → \(model.configuration.modelDirectory(hub: .default).path())")
            // Kick off the potentially long-running load, reporting progress back to the main actor.
            let container = try await factory.loadContainer(
                hub: .default,
                configuration: model.configuration
            ) { progress in
                Task { @MainActor in
                    let percent: Int
                    if progress.totalUnitCount > 0 && progress.totalUnitCount >= progress.completedUnitCount {
                        let ratio = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                        percent = Int((ratio * 100).rounded())
                    } else {
                        percent = -1
                    }

                    if self.lastLoggedUnitCount[model.id] != progress.completedUnitCount {
                        self.lastLoggedUnitCount[model.id] = progress.completedUnitCount
                        let unitText: String
                        if progress.totalUnitCount > 0 {
                            let fraction = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                            unitText = String(format: "%.2f", fraction)
                        } else {
                            unitText = "n/a"
                        }
                        let additionalDescription = progress.localizedAdditionalDescription ?? "N/A"
                        let description = progress.localizedDescription ?? "N/A"
                        print("⬇️ [MLXService] \(model.name) units: \(progress.completedUnitCount)/\(progress.totalUnitCount) (fraction \(unitText)) — \(description) | \(additionalDescription)")
                    }

                    if percent == -1 {
                        if self.lastLoggedProgress[model.id] != percent {
                            print("⬇️ [MLXService] \(model.name) progress: awaiting size (completed \(progress.completedUnitCount))")
                            self.lastLoggedProgress[model.id] = percent
                        }
                    } else {
                        let last = self.lastLoggedProgress[model.id] ?? -2
                        if percent >= 100 || percent >= last + 5 {
                            print("⬇️ [MLXService] \(model.name) progress: \(percent)% (\(progress.completedUnitCount)/\(progress.totalUnitCount))")
                            self.lastLoggedProgress[model.id] = percent
                        }
                    }

                    self.modelDownloadProgress = progress
                }
            }

            if modelCache.object(forKey: model.name as NSString) == nil {
                modelCache.removeAllObjects()
            }
            modelCache.setObject(container, forKey: model.name as NSString)

            await MainActor.run {
                // Reset progress state and mark the download as completed locally.
                self.modelDownloadProgress = nil
                if self.downloadingModelID == model.id {
                    self.downloadingModelID = nil
                }
                self.lastLoggedProgress[model.id] = nil
                self.lastLoggedUnitCount[model.id] = nil
                DownloadedModelsStore.shared.markDownloaded(model.id)
                print("✅ [MLXService] Finished download for \(model.name)")
            }

            print("⬆️ [MLXService] loadContainer finished for \(model.name)")

            if Self.storageLimitBytes > 0 {
                let updatedUsage = await currentStorageUsage()
                if updatedUsage > Self.storageLimitBytes {
                    modelCache.removeObject(forKey: model.name as NSString)
                    try await removeDownload(for: model)
                    throw MLXServiceError.storageLimitReached(limit: Self.storageLimitBytes)
                }
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
                self.lastLoggedProgress[model.id] = nil
                self.lastLoggedUnitCount[model.id] = nil
            }
            if let serviceError = error as? MLXServiceError {
                print("⚠️ [MLXService] Download blocked for \(model.name): \(serviceError.localizedDescription)")
            } else {
                print("❌ [MLXService] Download failed for \(model.name): \(error.localizedDescription)")
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
        print("🗑️ [MLXService] Starting removal for \(model.name)")

        // Step 1: Cancel any ongoing tasks first
        await MainActor.run {
            self.loadTasks[model.id]?.cancel()
            self.loadTasks[model.id] = nil
            if self.downloadingModelID == model.id {
                self.downloadingModelID = nil
                self.modelDownloadProgress = nil
            }
        }

        // Step 2: Remove from memory cache to release MLX resources
        modelCache.removeObject(forKey: model.name as NSString)
        // Also clear all cache to ensure no references remain
        modelCache.removeAllObjects()
        print("🧹 [MLXService] Cleared cache for \(model.name)")

        // Step 3: Mark as not downloaded immediately
        await MainActor.run {
            DownloadedModelsStore.shared.remove(model.id)
        }

        // Step 4: Small delay to let MLX framework release file handles
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Step 5: Remove files from disk
        let directory = model.configuration.modelDirectory(hub: .default)
        if FileManager.default.fileExists(atPath: directory.path()) {
            do {
                try FileManager.default.removeItem(at: directory)
                print("✅ [MLXService] Successfully removed files for \(model.name)")
            } catch {
                print("⚠️ [MLXService] Failed to remove files for \(model.name): \(error.localizedDescription)")
                // Even if file removal fails, we've already marked it as not downloaded
                // This allows retry on next attempt
                throw error
            }
        }
    }

    @MainActor
    func cancelDownload(for model: LMModel) {
        // Mark as cancelled and cancel the task
        cancelledDownloads.insert(model.id)
        loadTasks[model.id]?.cancel()
        loadTasks[model.id] = nil

        if downloadingModelID == model.id {
            downloadingModelID = nil
            modelDownloadProgress = nil
        }

        print("🚫 [MLXService] Cancelled download for \(model.name)")
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
            if (try? FileManager.default.removeItem(at: fileURL)) != nil {
                print("🧹 [MLXService] Removed incomplete artifact: \(fileURL.lastPathComponent)")
            }
        }
    }

    private func currentStorageUsage() async -> Int64 {
        await MainActor.run {
            let store = DownloadedModelsStore.shared
            return store.ids.reduce(into: Int64(0)) { total, id in
                guard let model = Self.availableModels.first(where: { $0.id == id }),
                      let size = store.sizeOnDisk(for: model) else { return }
                total += size
            }
        }
    }
}

private extension LLMRegistry {
    static let lfm2_700m_4bit = ModelConfiguration(
        id: "mlx-community/LiquidAI-LFM2-0.7B-Instruct-4bit",
        defaultPrompt: "Give me a creativity exercise I can finish in a minute."
    )

    static let deepseek_r1_distill_qwen_1_5b_4bit = ModelConfiguration(
        id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit",
        defaultPrompt: "Explain your reasoning as you solve: Why is 9.11 less than 9.9?"
    )
}
