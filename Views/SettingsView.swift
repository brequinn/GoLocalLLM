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
        .alert("Something went wrong", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "Unknown error")
        }
    }
}

private extension SettingsView {
    var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { newValue in
                if newValue == false {
                    vm.errorMessage = nil
                }
            }
        )
    }

    var assistantSection: some View {
        Section("Personality") {
            NavigationLink {
                AssistantsView()
            } label: {
                SettingsRow(title: settings.selectedAssistant.title,
                            subtitle: settings.selectedAssistant.subtitle)
            }
        }
    }

    var intelligenceSection: some View {
        let currentModel = vm.selectedModel

        return Section("Models") {
            NavigationLink {
                ManageModelsView()
                    .environment(vm)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(currentModel.displayName)
                            .font(.headline)
                        Spacer()
                        Label("Local", systemImage: "lock.fill")
                            .font(.caption)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.secondary)
                    }
                    Text(currentModel.summary)
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
