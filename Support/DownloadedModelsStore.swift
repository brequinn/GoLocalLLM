// Support/DownloadedModelsStore.swift
// Tracks which models have been downloaded and exposes related metadata.

import Foundation
import Hub

@MainActor
final class DownloadedModelsStore: ObservableObject {
    // Single shared instance used across the app.
    static let shared = DownloadedModelsStore()

    // Model identifiers persisted for UI and cache management.
    @Published private(set) var ids: Set<String> = []

    private let key = "downloadedModelIDs"

    private init() {
        // Restore previously persisted downloads from UserDefaults.
        if let saved = UserDefaults.standard.array(forKey: key) as? [String] {
            ids = Set(saved)
        }
    }

    func markDownloaded(_ id: String) {
        // Record that the model is now locally available.
        ids.insert(id)
        save()
    }

    func remove(_ id: String) {
        // Forget a download after the user deletes it.
        ids.remove(id)
        save()
    }

    func isDownloaded(_ id: String) -> Bool {
        ids.contains(id)
    }

    nonisolated func directory(for model: LMModel) -> URL {
        // Compute the on-disk path MLX uses for the given configuration.
        model.configuration.modelDirectory(hub: .default)
    }

    nonisolated func sizeOnDisk(for model: LMModel) -> Int64? {
        let url = directory(for: model)
        return try? url.directorySize()
    }

    private func save() {
        // Persist the set back to UserDefaults for the next launch.
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}

private extension URL {
    func directorySize() throws -> Int64 {
        var total: Int64 = 0
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: self, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [], errorHandler: nil) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            // Skip folders; only sum concrete files on disk.
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard resourceValues.isRegularFile == true else { continue }
            total += Int64(resourceValues.fileSize ?? 0)
        }

        return total
    }
}
