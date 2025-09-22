//
//  ShimmeringLogoView.swift
//  Displays the GoLocalLLM wordmark with a periodic shimmer highlight.
//

import SwiftUI

struct ShimmeringLogoView: View {
    @State private var shimmerTask: Task<Void, Never>?
    @State private var shimmerPhase: CGFloat = -1

    private let baseColor = Color.primary.opacity(0.18)
    private let highlightColor = Color(red: 0.25, green: 0.55, blue: 1.0)

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let dynamicSize = min(max(width * 0.16, 24), 32)

            ZStack {
                Text("GoLocalLLM")
                    .font(.system(size: dynamicSize, weight: .semibold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(baseColor)
                    .overlay(alignment: .center) {
                        LinearGradient(
                            colors: [Color.clear, highlightColor.opacity(0.85), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .mask(
                            Text("GoLocalLLM")
                                .font(.system(size: dynamicSize, weight: .semibold, design: .rounded))
                                .tracking(1.1)
                        )
                        .offset(x: shimmerPhase * width)
                        .opacity(shimmerPhase == -1 ? 0 : 1)
                    }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .onAppear { startShimmering() }
        .onDisappear { shimmerTask?.cancel() }
    }

    private func startShimmering() {
        shimmerTask?.cancel()
        shimmerTask = Task { @MainActor in
            while !Task.isCancelled {
                shimmerPhase = -1
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation(.linear(duration: 1.5)) {
                    shimmerPhase = 1.2
                }
                try? await Task.sleep(nanoseconds: 4_500_000_000)
            }
        }
    }
}

#Preview {
    ShimmeringLogoView()
        .padding()
}
