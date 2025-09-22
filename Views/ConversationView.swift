//
//  ConversationView.swift
//  GoLocalLLM
//

import SwiftUI

/// Displays the chat conversation as a scrollable list of messages,
/// without jitter while the assistant is streaming.
struct ConversationView: View {
    let messages: [Message]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Disable implicit animations for size changes so the list does not float
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageView(message: message)
                            .padding(.horizontal, 12)
                            .id(message.id)
                    }
                }
                .transaction { txn in txn.animation = nil }
                .padding(.vertical, 8)
            }
            // Scroll when message count changes, for example user sends or assistant adds a new bubble
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy, animated: true)
            }
            // During streaming, only the last assistant message grows.
            // Scroll to bottom again, without animation, to avoid jitter.
            .onChange(of: messages.last?.content) { _, _ in
                scrollToBottom(proxy, animated: false)
            }
            .onAppear {
                scrollToBottom(proxy, animated: false)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let lastID = messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

#Preview {
    ConversationView(messages: [
        .user("Hello"),
        .assistant("Hi there. How can I help?"),
        .user("Show me a typing bubble next."),
        .assistant("")
    ])
}
