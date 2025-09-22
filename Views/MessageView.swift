//
//  MessageView.swift
//  GoLocalLLM
//

import AVKit
import SwiftUI

struct MessageView: View {
    @Bindable var message: Message

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    if let firstImage = message.images.first {
                        AsyncImage(url: firstImage) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { ProgressView() }
                        .frame(maxWidth: 250, maxHeight: 200)
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    if let firstVideo = message.videos.first {
                        VideoPlayer(player: AVPlayer(url: firstVideo))
                            .frame(width: 250, height: 340)
                            .clipShape(.rect(cornerRadius: 12))
                    }

                    Text(LocalizedStringKey(message.content))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.tint, in: .rect(cornerRadius: 16))
                        .textSelection(.enabled)
                }
            }

        case .assistant:
            HStack {
                if message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    TypingIndicatorBubble()
                } else {
                    Text(LocalizedStringKey(message.content))
                        .textSelection(.enabled)
                }
                Spacer()
            }

        case .system:
            EmptyView()
        }
    }
}

// Small assistant bubble while the model is replying
private struct TypingIndicatorBubble: View {
    var body: some View {
        HStack(spacing: 8) {
            PulsingDot()
            Text("Thinking")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
    }
}

// The only PulsingDot in the project
private struct PulsingDot: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.6

    var body: some View {
        Circle()
            .fill(Color.primary)
            .frame(width: 10, height: 10)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    scale = 1.15
                    opacity = 1.0
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        MessageView(message: .user("Hi there"))
        MessageView(message: .assistant(""))
        MessageView(message: .assistant("Hello. How can I help?"))
    }
    .padding()
}

