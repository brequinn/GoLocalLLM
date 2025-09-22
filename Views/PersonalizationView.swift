// Views/PersonalizationView.swift

import SwiftUI

struct PersonalizationView: View {
    @State private var showSuggestions = true
    @State private var safeAnswers = true
    @State private var quickActions = true

    var body: some View {
        Form {
            Section("Assistant") {
                Toggle("Show helpful suggestions", isOn: $showSuggestions)
                Toggle("Prefer safer answers", isOn: $safeAnswers)
                Toggle("Show quick actions", isOn: $quickActions)
            }

            Section {
                Text("These options affect only the presentation. They do not change the model itself.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Personalization")
    }
}
