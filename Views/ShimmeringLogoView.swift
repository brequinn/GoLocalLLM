//
//  ShimmeringLogoView.swift
//  Displays the GoLocalLLM wordmark with a periodic shimmer highlight and floating particles.
//

import SwiftUI

struct ShimmeringLogoView: View {
    @State private var shimmerTask: Task<Void, Never>?
    @State private var shimmerPhase: CGFloat = -1
    @State private var floatOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    private let baseColor = Color.primary.opacity(0.15)
    private let highlightColor = Color(red: 0.3, green: 0.6, blue: 1.0)

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let dynamicSize = min(max(width * 0.16, 24), 32)

            ZStack {
                // Subtle glow background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.2, green: 0.5, blue: 0.95).opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .scaleEffect(pulseScale)

                VStack(spacing: 12) {
                    // Main logo text
                    ZStack {
                        // Base text with glow
                        Text("GoLocalLLM")
                            .font(.system(size: dynamicSize, weight: .bold, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(baseColor)
                            .overlay(alignment: .center) {
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        highlightColor.opacity(0.9),
                                        highlightColor.opacity(0.9),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .mask(
                                    Text("GoLocalLLM")
                                        .font(.system(size: dynamicSize, weight: .bold, design: .rounded))
                                        .tracking(1.5)
                                )
                                .offset(x: shimmerPhase * width)
                                .opacity(shimmerPhase == -1 ? 0 : 1)
                            }
                    }

                    // Tagline with fade
                    Text("Ready to chat")
                        .font(.system(size: dynamicSize * 0.35, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .offset(y: floatOffset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .onAppear {
            startShimmering()
            startFloating()
            startPulsing()
        }
        .onDisappear {
            shimmerTask?.cancel()
        }
    }

    private func startShimmering() {
        shimmerTask?.cancel()
        shimmerTask = Task { @MainActor in
            while !Task.isCancelled {
                shimmerPhase = -1
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation(.linear(duration: 1.8)) {
                    shimmerPhase = 1.2
                }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    private func startFloating() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            floatOffset = -8
        }
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
    }
}

#Preview {
    ShimmeringLogoView()
        .padding()
}
