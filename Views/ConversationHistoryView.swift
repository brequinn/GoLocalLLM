// Views/ConversationHistoryView.swift

import SwiftUI

struct ConversationHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "tray")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("No Conversations")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("Conversation History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
        }
    }
}

