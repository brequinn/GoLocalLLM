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
    // Short marketing blurb shown in the Manage Models catalogue.
    let summary: String
    // Visual identifier rendered next to the model title.
    let icon: Icon
    // Badges surfaced in the catalogue to communicate capabilities.
    let badges: [Badge]
    // Number of variants bundled under the listing (defaults to 1).
    let variantCount: Int

    enum ModelType {
        case llm
        case vlm
    }

    init(
        name: String,
        configuration: ModelConfiguration,
        type: ModelType,
        summary: String,
        icon: Icon,
        badges: [Badge] = [],
        variantCount: Int = 1
    ) {
        self.name = name
        self.configuration = configuration
        self.type = type
        self.summary = summary
        self.icon = icon
        self.badges = badges
        self.variantCount = max(variantCount, 1)
    }
}

extension LMModel {
    // Friendly string displayed in the picker, tagging vision-capable models.
    var displayName: String { isVisionModel ? "\(name) (Vision)" : name }
    var isLanguageModel: Bool { type == .llm }
    var isVisionModel: Bool { type == .vlm }

    // Best-effort parsing of the parameter scale from the model name (in billions).
    var parameterCountBillionsEstimate: Double? {
        guard let suffix = name.split(separator: ":").last else { return nil }

        var digits = ""
        var unit: Character?
        for character in suffix {
            if character.isNumber || character == "." {
                digits.append(character)
            } else {
                unit = character
                break
            }
        }

        guard let unit, digits.isEmpty == false, let value = Double(digits) else { return nil }

        switch String(unit).lowercased() {
        case "b":
            return value
        case "m":
            return value / 1_000
        case "k":
            return value / 1_000_000
        default:
            return nil
        }
    }
}

extension LMModel: Identifiable, Hashable {
    // Use the name as the unique identifier so SwiftUI can diff collections.
    var id: String { name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

extension LMModel {
    struct Icon: Hashable {
        let representation: Representation

        enum Representation: Hashable {
            case emoji(String)
            case systemImage(String)
            case asset(String)
        }
    }

    struct Badge: Hashable {
        let kind: Kind
        let label: String

        enum Kind: Hashable {
            case new
            case vision
            case reasoning
            case recommended
            case custom
        }
    }
}
