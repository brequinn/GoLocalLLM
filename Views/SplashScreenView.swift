//
//  SplashScreenView.swift
//  Animated splash screen with particle effects and gradient mesh
//

import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var particlesOpacity: Double = 0
    @State private var gradientRotation: Double = 0
    @State private var isComplete = false

    let onComplete: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let minDimension = min(proxy.size.width, proxy.size.height)
            let logoSize = min(max(minDimension * 0.12, 36), 56)
            let taglineSize = min(max(minDimension * 0.04, 12), 18)

            ZStack {
                // Animated gradient mesh background
                AnimatedGradientMesh(rotation: gradientRotation, size: proxy.size)
                    .ignoresSafeArea()

                // Particle effect layer
                ParticleField()
                    .opacity(particlesOpacity)
                    .ignoresSafeArea()

                // Logo and tagline
                VStack(spacing: 24) {
                    // Main logo with glow effect
                    ZStack {
                        // Glow layers
                        Text("GoLocalLLM")
                            .font(.system(size: logoSize, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.7, blue: 1.0),
                                        Color(red: 0.2, green: 0.5, blue: 0.95)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blur(radius: 20)
                            .opacity(0.6)

                        // Main logo
                        Text("GoLocalLLM")
                            .font(.system(size: logoSize, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color(red: 0.9, green: 0.95, blue: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.5), radius: 20, y: 10)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    // Tagline
                    Text("Local AI • Private • Powerful")
                        .font(.system(size: taglineSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .opacity(logoOpacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Phase 1: Fade in particles (0-0.3s)
        withAnimation(.easeOut(duration: 0.3)) {
            particlesOpacity = 1.0
        }

        // Phase 2: Logo scale and fade in (0.3-1.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                logoScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5)) {
                logoOpacity = 1.0
            }
        }

        // Phase 3: Rotate gradient continuously
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            gradientRotation = 360
        }

        // Phase 4: Complete animation after 2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                isComplete = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onComplete()
            }
        }
    }
}

// MARK: - Animated Gradient Mesh Background

private struct AnimatedGradientMesh: View {
    let rotation: Double
    let size: CGSize

    var body: some View {
        let minDimension = min(size.width, size.height)
        let overlayStart = minDimension * 0.2
        let overlayEnd = minDimension * 1.1
        let glowSmall = minDimension * 0.75
        let glowLarge = minDimension * 1.0

        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.2),
                    Color(red: 0.1, green: 0.15, blue: 0.3),
                    Color(red: 0.05, green: 0.1, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Animated overlay gradient
            RadialGradient(
                colors: [
                    Color(red: 0.2, green: 0.5, blue: 0.95).opacity(0.3),
                    Color(red: 0.1, green: 0.3, blue: 0.6).opacity(0.2),
                    Color.clear
                ],
                center: .center,
                startRadius: overlayStart,
                endRadius: overlayEnd
            )
            .rotationEffect(.degrees(rotation))
            .scaleEffect(1.5)

            // Additional glow spots
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.0, green: 0.7, blue: 0.9).opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: glowSmall * 0.5
                    )
                )
                .frame(width: glowSmall, height: glowSmall)
                .offset(x: -minDimension * 0.25, y: -minDimension * 0.45)
                .blur(radius: 40)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: glowLarge * 0.5
                    )
                )
                .frame(width: glowLarge, height: glowLarge)
                .offset(x: minDimension * 0.3, y: minDimension * 0.5)
                .blur(radius: 50)
        }
    }
}

// MARK: - Particle Field

private struct ParticleField: View {
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var speed: CGFloat
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.7, blue: 1.0),
                                    Color(red: 0.2, green: 0.5, blue: 0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                        .blur(radius: 2)
                }
            }
            .onAppear {
                generateParticles(in: geometry.size)
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        particles = (0..<60).map { _ in
            Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.2...0.6),
                speed: CGFloat.random(in: 20...60)
            )
        }

        // Animate particles floating
        animateParticles(in: size)
    }

    private func animateParticles(in size: CGSize) {
        for index in particles.indices {
            let duration = Double.random(in: 3...8)
            let delay = Double.random(in: 0...2)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    particles[index].y -= particles[index].speed
                }

                // Fade in and out
                withAnimation(.easeInOut(duration: duration / 2).repeatForever(autoreverses: true)) {
                    particles[index].opacity = Double.random(in: 0.1...0.8)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SplashScreenView {
        print("Splash complete")
    }
}
