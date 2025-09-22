// Views/Badges.swift

import SwiftUI

struct Badge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.15), in: .capsule)
    }
}

