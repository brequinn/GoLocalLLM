//
//  SettingsView.swift
//  GoLocalLLM
//

import SwiftUI

struct SettingsView: View {
    // Share the app state
    @Environment(ChatViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.shared

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            List {
                assistantSection
                intelligenceSection
                chatSettingsSection
                helpSection
                aboutSection
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private extension SettingsView {
    var assistantSection: some View {
        Section("Assistant") {
            NavigationLink {
                AssistantsView()
            } label: {
                SettingsRow(title: settings.selectedAssistant.title,
                            subtitle: settings.selectedAssistant.subtitle)
            }
        }
    }

    var intelligenceSection: some View {
        Section("Models") {
            NavigationLink {
                ManageModelsView()
                    .environment(vm)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Meta Llama 3.2 - 1B")
                            .font(.headline)
                        Spacer()
                        Label("Local", systemImage: "lock.fill")
                            .font(.caption)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.secondary)
                    }
                    Text("Very small and fast chat model. Runs well on most mobile devices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    var chatSettingsSection: some View {
        Section("Chat Settings") {
            Toggle(isOn: $settings.hapticsEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Haptic feedback")
                    Text("Vibrate lightly for send, receive, and important moments.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(String(format: "%.1f", settings.temperature))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.temperature, in: 0...1, step: 0.05)
                Text("Controls the creativity of responses; lower values make answers more focused, while higher values increase randomness.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Context window: \(settings.contextWindow.formatted())")
                    Spacer()
                }
                Slider(value: contextWindowBinding, in: 2_048...16_384, step: 256)
                Text("Maximum number of tokens the model can process at once. Higher values use more memory but allow longer conversations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: $settings.showModelReasoning) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Show model reasoning")
                    Text("Display the model's thinking process in reasoning bubbles.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var helpSection: some View {
        Section("Help Improve GoLocalLLM") {
            Link("Email feedback", destination: URL(string: "mailto:brendanquinn89@gmail.com?subject=GoLocalLLM%20Feedback")!)
                .font(.headline)
        }
    }

    var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0").foregroundStyle(.secondary)
            }
        }
    }

    var contextWindowBinding: Binding<Double> {
        Binding {
            Double(settings.contextWindow)
        } set: { newValue in
            let clamped = min(16_384, max(2_048, Int(newValue.rounded())))
            settings.contextWindow = clamped
        }
    }
}

private struct SettingsRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// Simple text wrapper for static pages
private struct LicensesText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        ScrollView {
            Text(text)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
    }
}
