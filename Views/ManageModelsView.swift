//
//  ManageModelsView.swift
//  GoLocalLLM
//

import SwiftUI

struct ManageModelsView: View {
    @Environment(ChatViewModel.self) private var vm
    @ObservedObject private var downloads = DownloadedModelsStore.shared

    @State private var storageByID: [String: Int64] = [:]
    @State private var totalStorage: Int64 = 0

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Storage used")
                    Spacer()
                    Text(formatBytes(totalStorage))
                        .foregroundStyle(.secondary)
                }
                if downloads.ids.isEmpty {
                    Text("No models downloaded yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Featured") {
                ForEach(MLXService.availableModels, id: \.id) { model in
                    let isDownloaded = downloads.isDownloaded(model.id)
                    let isDownloading = vm.downloadingModelID == model.id
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(titleMain(model.name)).font(.headline)
                            HStack(spacing: 6) {
                                Text(titleSuffix(model.name))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if isDownloaded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            statusView(for: model, isDownloaded: isDownloaded, isDownloading: isDownloading)
                        }
                        Spacer()
                        Menu {
                            Button("Use this model") {
                                vm.setModel(model)
                                Task { await vm.preload(model: model) }
                            }
                            if isDownloaded {
                                Button("Remove Download", role: .destructive) {
                                    Task { await vm.removeDownload(for: model) }
                                }
                            } else {
                                Button("Download") {
                                    Task { await vm.preload(model: model) }
                                }
                                .disabled(isDownloading)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle").font(.title3)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.setModel(model)
                        Task { await vm.preload(model: model) }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if isDownloaded {
                            Button(role: .destructive) {
                                Task { await vm.removeDownload(for: model) }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        } else {
                            Button {
                                Task { await vm.preload(model: model) }
                            } label: {
                                Label("Download", systemImage: "arrow.down.circle")
                            }
                            .tint(.blue)
                            .disabled(isDownloading)
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage models")
        .task { await refreshStorage() }
        .onChange(of: downloads.ids) { _, _ in
            Task { await refreshStorage() }
        }
    }

    private func titleMain(_ full: String) -> String {
        if let idx = full.firstIndex(of: ":") { return String(full[..<idx]) }
        if let space = full.firstIndex(of: " ") { return String(full[..<space]) }
        return full
    }

    private func titleSuffix(_ full: String) -> String {
        if let idx = full.firstIndex(of: ":") { return String(full[full.index(after: idx)...]) }
        if let space = full.firstIndex(of: " ") { return String(full[full.index(after: space)...]) }
        return ""
    }

    @ViewBuilder
    private func statusView(for model: LMModel, isDownloaded: Bool, isDownloading: Bool) -> some View {
        if isDownloading {
            if let progress = vm.modelDownloadProgress {
                VStack(alignment: .leading, spacing: 4) {
                    if progress.totalUnitCount > 0 {
                        ProgressView(
                            value: Double(progress.completedUnitCount),
                            total: Double(progress.totalUnitCount)
                        )
                            .progressViewStyle(.linear)
                    } else {
                        ProgressView().progressViewStyle(.linear)
                    }

                    HStack {
                        Text("Downloading…")
                        Spacer()
                        if let description = progressDescription(progress) {
                            Text(description)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView().progressViewStyle(.circular)
                    Text("Preparing download…")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else if isDownloaded {
            HStack(spacing: 6) {
                Text("Downloaded")
                if let size = storageByID[model.id] {
                    Text(formatBytes(size))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            Text("Not downloaded")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func progressDescription(_ progress: Progress) -> String? {
        guard progress.totalUnitCount > 0 else { return nil }
        let percent = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
        guard percent.isFinite else { return nil }
        return String(format: "%.0f%%", percent * 100)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func refreshStorage() async {
        let ids = await MainActor.run { downloads.ids }
        var perModel: [String: Int64] = [:]
        for id in ids {
            guard let model = MLXService.availableModels.first(where: { $0.id == id }),
                  let size = DownloadedModelsStore.shared.sizeOnDisk(for: model) else { continue }
            perModel[id] = size
        }
        let total = perModel.values.reduce(0, +)
        await MainActor.run {
            storageByID = perModel
            totalStorage = total
        }
    }
}
