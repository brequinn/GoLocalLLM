// Support/HubApi+default.swift
// Configures where the HuggingFace hub client stores downloaded assets per platform.

import Foundation
@preconcurrency import Hub

extension HubApi {
#if os(macOS)
    // On macOS we keep weights inside the user's Downloads folder for easier inspection.
    static let `default` = HubApi(
        downloadBase: URL.downloadsDirectory.appending(path: "huggingface")
    )
#else
    // On iOS we prefer the caches directory so the system can reclaim space if needed.
    static let `default` = HubApi(
        downloadBase: URL.cachesDirectory.appending(path: "huggingface")
    )
#endif
}
