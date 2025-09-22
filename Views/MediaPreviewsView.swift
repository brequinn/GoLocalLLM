// Views/MediaPreviewsView.swift

import AVFoundation
import AVKit
import SwiftUI

struct MediaPreviewsView: View {
    let mediaSelection: MediaSelection

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(mediaSelection.images, id: \.self) { imageURL in
                    MediaPreviewView(
                        mediaURL: imageURL,
                        type: .image,
                        onRemove: { mediaSelection.images.removeAll { $0 == imageURL } }
                    )
                }
                ForEach(mediaSelection.videos, id: \.self) { videoURL in
                    MediaPreviewView(
                        mediaURL: videoURL,
                        type: .video,
                        onRemove: { mediaSelection.videos.removeAll { $0 == videoURL } }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

struct MediaPreviewView: View {
    let mediaURL: URL
    let type: MediaPreviewType
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            switch type {
            case .image:
                AsyncImage(url: mediaURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    ProgressView().frame(width: 150, height: 100)
                }
            case .video:
                VideoPlayer(player: AVPlayer(url: mediaURL))
                    .frame(width: 150, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            RemoveButton(action: onRemove)
        }
    }
}

struct RemoveButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
                .imageScale(.large)
        }
        .buttonStyle(.plain)
        .padding(4)
    }
}

extension MediaPreviewView {
    enum MediaPreviewType { case image, video }
}

#Preview("Remove Button") { RemoveButton {} }

