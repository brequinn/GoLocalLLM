import SwiftUI

struct AssistantsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        List {
            ForEach(AssistantProfile.all, id: \.id) { assistant in
                assistantRow(for: assistant)
            }
        }
        .navigationTitle("Personalities")
    }

    private func assistantRow(for assistant: AssistantProfile) -> some View {
        Button {
            settings.selectedAssistantID = assistant.id
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assistant.title)
                        .font(.headline)
                    Text(assistant.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if settings.selectedAssistantID == assistant.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
