// Support/SampleData.swift
// Provides seed transcript content and starter prompts for previews/demos.
import Foundation

@MainActor
struct SampleData {
    // Short canned conversation used for previews or debugging.
    static let conversation: [Message] = [
        .system("You are a helpful assistant specializing in on device AI."),
        .user("Give me three tips for smartphone photography."),
        .assistant("Use natural light when possible. Clean the lens. Tap to focus, then lower exposure a bit for better detail.")
    ]

    static let starterChips: [StarterChip] = [
        // Quick prompts shown as suggestion chips on the home screen.
        .init(title: "Master", subtitle: "smartphone photography",
              prompt: "Give me three tips for smartphone photography."),
        .init(title: "Plan", subtitle: "a trip to Paris",
              prompt: "Plan a three day trip to Paris, include food and museums."),
        .init(title: "Beginner", subtitle: "meditation",
              prompt: "Teach me a simple ten minute meditation."),
        .init(title: "Improve", subtitle: "my resume",
              prompt: "Rewrite my resume summary for a product role.")
    ]
}

struct StarterChip: Identifiable {
    // Identifiable so SwiftUI can present the chips in a ForEach.
    let id = UUID()
    let title: String
    let subtitle: String
    let prompt: String
}
