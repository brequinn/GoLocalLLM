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
    // Optional status describing placeholder states (e.g. analyzing media).
    var status: Status?
    // Optional reasoning emitted within <think> sections.
    var reasoning: String?
    // Optional local image attachments referenced by URL.
    var images: [URL]
    // Optional local video attachments referenced by URL.
    var videos: [URL]
    // Capture when the message was generated for ordering and metadata.
    let timestamp: Date

    init(role: Role, content: String, status: Status? = nil, reasoning: String? = nil, images: [URL] = [], videos: [URL] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.status = status
        self.reasoning = reasoning
        self.images = images
        self.videos = videos
        self.timestamp = .now
    }

    enum Role: String, Codable { case user, assistant, system }
    enum Status: String, Equatable, Codable { case thinking, analyzingImage }
}

extension Message {
    // Convenience factories keep the call-sites terse and consistent.
    static func user(_ content: String, images: [URL] = [], videos: [URL] = []) -> Message {
        Message(role: .user, content: content, images: images, videos: videos)
    }
    static func assistant(_ content: String, status: Status? = nil, reasoning: String? = nil) -> Message {
        Message(role: .assistant, content: content, status: status, reasoning: reasoning)
    }
    static func system(_ content: String) -> Message { Message(role: .system, content: content) }
}
