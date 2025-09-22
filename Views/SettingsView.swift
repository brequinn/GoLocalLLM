//
//  SettingsView.swift
//  GoLocalLLM
//

import SwiftUI

struct SettingsView: View {
    // Share the app state
    @Environment(ChatViewModel.self) private var vm

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Ask a question using your voice with Siri. Activate Siri and say “Hey GoLocalLLM”.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("App") {
                    // Open ManageModelsView inside this sheet
                    NavigationLink("Manage models") {
                        ManageModelsView()
                            .environment(vm)
                    }

                    NavigationLink("Personalization") {
                        PersonalizationView()
                    }

                    Button(role: .destructive) {
                        vm.clear([.chat, .meta])
                    } label: {
                        Text("Delete conversation history")
                    }
                }

                Section("About") {
                    NavigationLink("Term & Conditions") {
                        LicensesText("Terms go here.")
                            .navigationTitle("Terms & Conditions")
                    }
                    NavigationLink("Privacy Policy") {
                        LicensesText("Privacy policy goes here.")
                            .navigationTitle("Privacy Policy")
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0").foregroundStyle(.secondary)
                    }

                    Link("Follow us on X", destination: URL(string: "https://x.com")!)
                }
            }
            .navigationTitle("Settings")
        }
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
