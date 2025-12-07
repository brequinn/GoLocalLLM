// Views/ConversationHistoryView.swift

import SwiftUI

struct ConversationHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var history = ConversationHistoryStore.shared

    var body: some View {
        NavigationStack {
            Group {
                if history.conversations.isEmpty {
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
                } else {
                    List {
                        ForEach(history.conversations) { conversation in
                            NavigationLink {
                                ConversationTranscriptView(conversation: conversation)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(conversation.displayTitle)
                                        .font(.headline)
                                    Text(conversation.updatedAt, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let conversation = history.conversations[index]
                                history.deleteConversation(id: conversation.id)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Conversation History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if history.conversations.isEmpty == false {
                        Button("Clear All", role: .destructive) { history.clearAll() }
                    }
                }
            }
        }
    }
}

private struct ConversationTranscriptView: View {
    let conversation: ConversationRecord

    var body: some View {
        List {
            Section {
                ForEach(conversation.messages) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Label(message.roleLabel, systemImage: message.roleIcon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(message.roleColor)
                            Spacer()
                            Text(message.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let reasoning = message.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines),
                           reasoning.isEmpty == false {
                            Text(reasoning)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                        if message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                            Text(message.content)
                                .font(.body)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(conversation.displayTitle)
    }
}

private extension StoredMessage {
    var roleLabel: String {
        switch role {
        case .user: return "You"
        case .assistant: return "Assistant"
        case .system: return "System"
        }
    }

    var roleIcon: String {
        switch role {
        case .user: return "person"
        case .assistant: return "sparkles"
        case .system: return "gearshape"
        }
    }

    var roleColor: Color {
        switch role {
        case .user: return .blue
        case .assistant: return .green
        case .system: return .orange
        }
    }
}
