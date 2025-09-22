// Models/Message.swift
// Reactive model describing one entry in the chat transcript.

import Foundation

@Observable
class Message: Identifiable {
    // Stable identifier so SwiftUI lists diff correctly.
    let id: UUID
    // Who authored the message.
    let role: Role
    // Textual body shown in chat bubbles or streaming updates.
    var content: String
    // Optional local image attachments referenced by URL.
    var images: [URL]
    // Optional local video attachments referenced by URL.
    var videos: [URL]
    // Capture when the message was generated for ordering and metadata.
    let timestamp: Date

    init(role: Role, content: String, images: [URL] = [], videos: [URL] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.images = images
        self.videos = videos
        self.timestamp = .now
    }

    enum Role { case user, assistant, system }
}

extension Message {
    // Convenience factories keep the call-sites terse and consistent.
    static func user(_ content: String, images: [URL] = [], videos: [URL] = []) -> Message {
        Message(role: .user, content: content, images: images, videos: videos)
    }
    static func assistant(_ content: String) -> Message { Message(role: .assistant, content: content) }
    static func system(_ content: String) -> Message { Message(role: .system, content: content) }
}
