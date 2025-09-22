// GoLocalLLMApp.swift
// Application entry point that wires the service and primary chat view together.

import SwiftUI

@main
struct GoLocalLLMApp: App {
    // Shared MLX runtime responsible for model downloads and inference.
    @State private var service = MLXService()
    // Top-level observable view model driving all screen state.
    @State private var vm: ChatViewModel

    init() {
        // Build the service once, then keep a single ChatViewModel for the app lifecycle.
        let s = MLXService()
        _service = State(initialValue: s)
        _vm = State(initialValue: ChatViewModel(mlxService: s))
    }

    var body: some Scene {
        WindowGroup {
            // Launch directly into the custom home experience.
            ChatHomeView(viewModel: vm)
        }
    }
}
