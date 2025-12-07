// GoLocalLLMApp.swift
// Application entry point that wires the service and primary chat view together.

import SwiftUI

@main
struct GoLocalLLMApp: App {
    // Shared MLX runtime responsible for model downloads and inference.
    @State private var service = MLXService()
    // Top-level observable view model driving all screen state.
    @State private var vm: ChatViewModel
    // Track whether splash screen animation has completed
    @State private var showSplash = true

    init() {
        // Build the service once, then keep a single ChatViewModel for the app lifecycle.
        let s = MLXService()
        _service = State(initialValue: s)
        _vm = State(initialValue: ChatViewModel(mlxService: s))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main chat interface
                ChatHomeView(viewModel: vm)
                    .opacity(showSplash ? 0 : 1)

                // Animated splash screen overlay
                if showSplash {
                    SplashScreenView {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
