//
//  MessageView.swift
//  GoLocalLLM - Enhanced with refined typography and visual polish
//

import AVKit
import SwiftUI

struct MessageView: View {
    @Bindable var message: Message
    @Bindable private var settings = AppSettings.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    if let firstImage = message.images.first {
                        AsyncImage(url: firstImage) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                                .frame(maxWidth: mediaMaxWidth, maxHeight: mediaMaxHeight)
                        }
                        .frame(maxWidth: mediaMaxWidth, maxHeight: mediaMaxHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
                    }

                    if let firstVideo = message.videos.first {
                        VideoPlayer(player: AVPlayer(url: firstVideo))
                            .frame(width: mediaMaxWidth, height: mediaVideoHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
                    }

                    if !message.content.isEmpty {
                        Text(LocalizedStringKey(message.content))
                            .font(.system(size: 16, design: .default))
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.2, green: 0.5, blue: 0.95),
                                        Color(red: 0.3, green: 0.6, blue: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                            .shadow(color: Color(red: 0.2, green: 0.5, blue: 0.95).opacity(0.3), radius: 8, y: 4)
                            .textSelection(.enabled)
                    }
                }
            }

        case .assistant:
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    let hasReasoning = message.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    let contentIsEmpty = message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                    // Show reasoning based on user preference
                    if hasReasoning {
                        if settings.showModelReasoning {
                            // Full reasoning bubble with content
                            ReasoningBubble(
                                text: message.reasoning!.trimmingCharacters(in: .whitespacesAndNewlines),
                                isStreaming: contentIsEmpty
                            )
                        } else {
                            // Compact thinking indicator only
                            CompactThinkingIndicator(
                                isStreaming: contentIsEmpty
                            )
                        }
                    }

                    // Show content or typing indicator (but NOT both if reasoning is showing)
                    if contentIsEmpty {
                        // Only show typing indicator if there's no reasoning
                        if !hasReasoning {
                            TypingIndicatorBubble(text: placeholderText(for: message.status))
                        }
                    } else {
                        Text(LocalizedStringKey(message.content))
                            .font(.system(size: 16, design: .default))
                            .foregroundStyle(.primary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .textSelection(.enabled)
                    }
                }
                Spacer()
            }

        case .system:
            EmptyView()
        }
    }

    private func placeholderText(for status: Message.Status?) -> LocalizedStringKey {
        switch status {
        case .analyzingImage:
            return "Analyzing image"
        default:
            return "Thinking"
        }
    }

    private var mediaMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 360 : 250
    }

    private var mediaMaxHeight: CGFloat {
        horizontalSizeClass == .regular ? 260 : 200
    }

    private var mediaVideoHeight: CGFloat {
        horizontalSizeClass == .regular ? 480 : 340
    }
}

// Small assistant bubble while the model is replying
private struct TypingIndicatorBubble: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 10) {
            PulsingDot()
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// The only PulsingDot in the project - enhanced with gradient
private struct PulsingDot: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.65, blue: 1.0),
                            Color(red: 0.2, green: 0.5, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 10, height: 10)
                .scaleEffect(scale)
                .opacity(opacity)

            Circle()
                .fill(Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.3))
                .frame(width: 20, height: 20)
                .scaleEffect(scale * 1.5)
                .opacity(opacity * 0.4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                scale = 1.2
                opacity = 1.0
            }
        }
    }
}

// Compact indicator when user has disabled full reasoning display
private struct CompactThinkingIndicator: View {
    let isStreaming: Bool
    @State private var dotScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 8) {
            // Animated thinking dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.9, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.7, blue: 0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 6, height: 6)
                        .scaleEffect(dotScale)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: dotScale
                        )
                }
            }

            Text(isStreaming ? "Thinking..." : "Thought about this")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.98, green: 0.95, blue: 0.9).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(red: 0.9, green: 0.6, blue: 0.2).opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            dotScale = 1.3
        }
    }
}

// Card that surfaces reasoning emitted by models supporting <think> streams - enhanced
private struct ReasoningBubble: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: isStreaming ? "brain.head.profile" : "lightbulb.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.9, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.7, blue: 0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(isStreaming ? "Thinking…" : "Model thoughts")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.98, green: 0.95, blue: 0.9).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(red: 0.9, green: 0.6, blue: 0.2).opacity(0.3), Color(red: 1.0, green: 0.7, blue: 0.3).opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: Color(red: 0.9, green: 0.6, blue: 0.2).opacity(0.1), radius: 6, y: 3)
    }
}

#Preview {
    VStack(spacing: 20) {
        MessageView(message: .user("Hi there"))
        MessageView(message: .assistant("", status: .thinking, reasoning: "Drafting a reply for you."))
        MessageView(message: .assistant("", status: .analyzingImage))
        MessageView(message: .assistant("Hello. How can I help?", reasoning: "Wrapped up reasoning."))
    }
    .padding()
}
