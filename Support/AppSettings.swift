//
//  AppSettings.swift
//  User preferences stored in UserDefaults
//

import SwiftUI

@Observable
class AppSettings {
    static let shared = AppSettings()

    private let showReasoningKey = "showModelReasoning"
    private let hapticsEnabledKey = "settings.hapticsEnabled"
    private let temperatureKey = "settings.temperature"
    private let contextWindowKey = "settings.contextWindow"
    private let selectedAssistantKey = "settings.selectedAssistant"

    var showModelReasoning: Bool {
        didSet {
            UserDefaults.standard.set(showModelReasoning, forKey: showReasoningKey)
        }
    }

    var hapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: hapticsEnabledKey)
        }
    }

    var temperature: Double {
        didSet {
            UserDefaults.standard.set(temperature, forKey: temperatureKey)
        }
    }

    var contextWindow: Int {
        didSet {
            UserDefaults.standard.set(contextWindow, forKey: contextWindowKey)
        }
    }

    var selectedAssistantID: String {
        didSet {
            UserDefaults.standard.set(selectedAssistantID, forKey: selectedAssistantKey)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        // Default to true (show reasoning) for users who want to see model thoughts
        self.showModelReasoning = defaults.object(forKey: showReasoningKey) as? Bool ?? true
        self.hapticsEnabled = defaults.object(forKey: hapticsEnabledKey) as? Bool ?? true
        self.temperature = defaults.object(forKey: temperatureKey) as? Double ?? 0.5
        self.contextWindow = defaults.object(forKey: contextWindowKey) as? Int ?? 8_192
        self.selectedAssistantID = defaults.object(forKey: selectedAssistantKey) as? String ?? AssistantProfile.default.id
    }
}

extension AppSettings {
    var selectedAssistant: AssistantProfile {
        AssistantProfile.all.first(where: { $0.id == selectedAssistantID }) ?? .default
    }
}
