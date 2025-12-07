//
//  EnhancedStatusView.swift
//  Refined status indicator with progress ring and better visual feedback
//

import SwiftUI

struct EnhancedStatusView: View {
    let type: StatusType
    let progress: Double?

    enum StatusType {
        case downloading(String)
        case loading(String)
        case ready
        case error(String)

        var message: String {
            switch self {
            case .downloading(let model): return "Downloading \(model)"
            case .loading(let model): return "Loading \(model)"
            case .ready: return "Ready"
            case .error(let msg): return msg
            }
        }

        var color: Color {
            switch self {
            case .downloading: return Color(red: 0.0, green: 0.8, blue: 0.9)
            case .loading: return Color(red: 0.5, green: 0.7, blue: 1.0)
            case .ready: return Color(red: 0.4, green: 0.9, blue: 0.6)
            case .error: return Color(red: 1.0, green: 0.4, blue: 0.4)
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Animated indicator
            ZStack {
                if let progress = progress {
                    // Progress ring
                    Circle()
                        .stroke(type.color.opacity(0.2), lineWidth: 2.5)
                        .frame(width: 20, height: 20)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(type.color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                } else {
                    // Pulsing dot
                    Circle()
                        .fill(type.color)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .fill(type.color.opacity(0.3))
                                .frame(width: 20, height: 20)
                                .scaleEffect(pulseScale)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(type.message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)

                if let progress = progress, progress > 0 {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(type.color.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: type.color.opacity(0.15), radius: 8, y: 4)
        )
        .transition(.scale.combined(with: .opacity))
    }

    @State private var pulseScale: CGFloat = 1.0

    private var pulseAnimation: Animation {
        .easeInOut(duration: 1.2)
        .repeatForever(autoreverses: true)
    }

    init(type: StatusType, progress: Double? = nil) {
        self.type = type
        self.progress = progress
        _pulseScale = State(initialValue: 1.0)
    }

    var onAppear: some View {
        self.onAppear {
            withAnimation(pulseAnimation) {
                pulseScale = 1.6
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        EnhancedStatusView(type: .downloading("Llama 3.2"), progress: 0.65)
        EnhancedStatusView(type: .loading("Qwen 2.5"))
        EnhancedStatusView(type: .ready)
        EnhancedStatusView(type: .error("Network error"))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
