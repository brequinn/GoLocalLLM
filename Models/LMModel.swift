// Models/LMModel.swift
// Lightweight description of a locally runnable language or vision model.

import MLXLMCommon

struct LMModel {
    // Canonical name used for lookups and analytics.
    let name: String
    // MLX configuration describing where to fetch weights and how to run them.
   let configuration: ModelConfiguration
    // High-level capability used to gate UI affordances.
    let type: ModelType

    enum ModelType {
        case llm
        case vlm
    }
}

extension LMModel {
    // Friendly string displayed in the picker, tagging vision-capable models.
    var displayName: String { isVisionModel ? "\(name) (Vision)" : name }
    var isLanguageModel: Bool { type == .llm }
    var isVisionModel: Bool { type == .vlm }
}

extension LMModel: Identifiable, Hashable {
    // Use the name as the unique identifier so SwiftUI can diff collections.
    var id: String { name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}
