//
//  ManageModelsView.swift
//  GoLocalLLM
//

import SwiftUI

struct ManageModelsView: View {
    @Environment(ChatViewModel.self) private var vm
    @ObservedObject private var downloads = DownloadedModelsStore.shared
    @AppStorage("ManageModelsView.showModelSizeEducation") private var showModelSizeEducation = true

    @State private var storageByID: [String: Int64] = [:]
    @State private var totalStorage: Int64 = 0
    @State private var pendingDownloadID: String?
    @State private var modelFilter: ModelFilter = .all

    private var storageLimit: Int64 { MLXService.storageLimitBytes }
    private var storageLimitString: String? {
        storageLimit > 0 ? formatBytes(storageLimit) : nil
    }
    private var isAtStorageLimit: Bool {
        storageLimit > 0 && totalStorage >= storageLimit
    }

    private var backgroundColor: Color { Color(uiColor: .systemGroupedBackground) }
    private var cardBackgroundColor: Color { Color(uiColor: .secondarySystemGroupedBackground) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if showModelSizeEducation {
                    understandingModelSizesCard
                }
                storageSummaryCard
                featuredSection
                modelDirectorySizeFooter
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Manage models")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(backgroundColor, for: .navigationBar)
        .task { await refreshStorage() }
        .onChange(of: downloads.ids) { _, _ in
            Task { await refreshStorage() }
        }
    }

    private var understandingModelSizesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Understanding Model Sizes")
                        .font(.headline)
                    Text("Local models come in different sizes, defined by their number of parameters, usually measured in billions (e.g., 0.6B, 1B, 3B). Bigger models are usually smarter, but also slower, as they use more memory and processing power. Choose a model that balances speed and quality for your needs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        showModelSizeEducation = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss size overview")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var storageSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage")
                .font(.headline)
            HStack {
                Text("Used")
                Spacer()
                Text(formatBytes(totalStorage))
                    .foregroundStyle(.secondary)
            }
            if let limitString = storageLimitString {
                HStack {
                    Text("Limit")
                    Spacer()
                    Text(limitString)
                        .foregroundStyle(.secondary)
                }
                if isAtStorageLimit {
                    Text("Storage limit reached. Remove a download before adding another.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if downloads.ids.isEmpty {
                Text("No models downloaded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FEATURED")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Picker("Model filter", selection: $modelFilter) {
                ForEach(ModelFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Filter models")
            ForEach(filteredModels, id: \.id) { model in
                modelCard(for: model)
            }
        }
    }

    private var modelDirectorySizeFooter: some View {
        VStack {
            Text("Model directory size: \(formatBytes(totalStorage))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            cardBackgroundColor,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    @ViewBuilder
    private func modelCard(for model: LMModel) -> some View {
        let isDownloaded = downloads.isDownloaded(model.id)
        let isDownloading = vm.downloadingModelID == model.id || pendingDownloadID == model.id
        let storageCapped = isAtStorageLimit && !isDownloaded
        let isActive = vm.selectedModel.id == model.id
        let progress = isDownloading ? vm.modelDownloadProgress : nil

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                iconView(for: model.icon)
                VStack(alignment: .leading, spacing: 6) {
                    let parts = nameParts(for: model.name)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(parts.main)
                            .font(.headline)
                        if let suffix = parts.suffix, suffix.isEmpty == false {
                            Text(suffix)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if isActive {
                            statusChip(label: "In use", foreground: .white, background: Color.accentColor)
                        } else if isDownloaded {
                            statusChip(label: "Downloaded", foreground: .green, background: Color.green.opacity(0.15))
                        }
                    }
                    Text(model.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(variantLabel(for: model.variantCount))
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.badges.isEmpty == false {
                badgesView(for: model.badges)
            }

            statusSection(
                progress: progress,
                model: model,
                isDownloaded: isDownloaded,
                storageCapped: storageCapped
            )

            actionRow(
                for: model,
                isDownloaded: isDownloaded,
                isDownloading: isDownloading,
                storageCapped: storageCapped,
                isActive: isActive
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isActive ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 2)
        )
    }

    private func nameParts(for name: String) -> (main: String, suffix: String?) {
        if let idx = name.firstIndex(of: ":") {
            return (String(name[..<idx]), String(name[name.index(after: idx)...]))
        }
        if let space = name.firstIndex(of: " ") {
            return (String(name[..<space]), String(name[name.index(after: space)...]))
        }
        return (name, nil)
    }

    @ViewBuilder
    private func iconView(for icon: LMModel.Icon) -> some View {
        let container = RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
            .frame(width: 48, height: 48)

        switch icon.representation {
        case .emoji(let value):
            Text(value)
                .font(.system(size: 28))
                .frame(width: 48, height: 48)
                .background(container)
        case .systemImage(let name):
            Image(systemName: name)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(container)
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .background(container)
        }
    }

    @ViewBuilder
    private func statusChip(label: String, foreground: Color, background: Color) -> some View {
        Text(label)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(background, in: Capsule(style: .continuous))
    }

    @ViewBuilder
    private func badgesView(for badges: [LMModel.Badge]) -> some View {
        HStack(spacing: 8) {
            ForEach(badges, id: \.self) { badge in
                let style = badgeStyle(for: badge.kind)
                if let iconName = style.iconName {
                    Label(badge.label, systemImage: iconName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(style.foreground)
                        .background(style.background, in: Capsule(style: .continuous))
                } else {
                    Text(badge.label)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(style.foreground)
                        .background(style.background, in: Capsule(style: .continuous))
                }
            }
        }
    }

    private struct BadgeStyle {
        let iconName: String?
        let foreground: Color
        let background: Color
    }

    private func badgeStyle(for kind: LMModel.Badge.Kind) -> BadgeStyle {
        switch kind {
        case .new:
            return BadgeStyle(iconName: "sparkles", foreground: .orange, background: Color.orange.opacity(0.15))
        case .vision:
            return BadgeStyle(iconName: "eye.fill", foreground: .indigo, background: Color.indigo.opacity(0.15))
        case .reasoning:
            return BadgeStyle(iconName: "lightbulb.fill", foreground: .purple, background: Color.purple.opacity(0.18))
        case .recommended:
            return BadgeStyle(iconName: "checkmark.seal.fill", foreground: .green, background: Color.green.opacity(0.18))
        case .custom:
            return BadgeStyle(iconName: nil, foreground: .accentColor, background: Color.accentColor.opacity(0.15))
        }
    }

    private func variantLabel(for count: Int) -> String {
        count == 1 ? "1 model" : "\(count) models"
    }

    @ViewBuilder
    private func statusSection(progress: Progress?, model: LMModel, isDownloaded: Bool, storageCapped: Bool) -> some View {
        if let progress {
            VStack(alignment: .leading, spacing: 8) {
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
                .foregroundStyle(.secondary)
            }
        } else if isDownloaded {
            HStack(spacing: 6) {
                Image(systemName: "internaldrive.fill")
                Text("On device")
                if let size = storageByID[model.id] {
                    Text(formatBytes(size))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if storageCapped {
            Label("Storage limit reached", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Text("Download to run this model locally.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func actionRow(
        for model: LMModel,
        isDownloaded: Bool,
        isDownloading: Bool,
        storageCapped: Bool,
        isActive: Bool
    ) -> some View {
        if isDownloading {
            HStack(spacing: 8) {
                ProgressView().progressViewStyle(.circular)
                Text("Preparing download…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else if isDownloaded {
            HStack(spacing: 12) {
                Button(isActive ? "In use" : "Use model") {
                    vm.setModel(model)
                    Task { await vm.preload(model: model) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isActive)

                Button("Remove") {
                    Task { await vm.removeDownload(for: model) }
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()
            }
        } else {
            HStack(spacing: 12) {
                Button("Download") {
                    guard storageCapped == false else { return }
                    pendingDownloadID = model.id
                    vm.setModel(model)
                    // Explicitly download when user taps Download button
                    Task {
                        await vm.downloadModel(model)
                        await MainActor.run { pendingDownloadID = nil }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(storageCapped)

                Spacer()
            }
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

    private var filteredModels: [LMModel] {
        switch modelFilter {
        case .all:
            return MLXService.availableModels
        case .vision:
            return MLXService.availableModels.filter { $0.isVisionModel }
        }
    }
}

private enum ModelFilter: String, CaseIterable, Identifiable {
    case all
    case vision

    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .vision: return "Vision"
        }
    }
}
