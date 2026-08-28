//
//  BrowserState+Media.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI
import WebKit

extension BrowserState {

    // MARK: - Media State Handling

    func updateMediaState(for tabId: UUID, isPlaying: Bool, isMuted: Bool, hasAudio: Bool, hasVideo: Bool, mediaTitle: String?) {
        let state = TabMediaState(
            isPlaying: isPlaying,
            isMuted: isMuted,
            hasAudio: hasAudio,
            hasVideo: hasVideo,
            mediaTitle: mediaTitle
        )
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tabMediaStates[tabId] = state
        }
    }

    var hasActiveAudioPlaying: Bool {
        tabMediaStates.values.contains(where: { $0.isPlayingAudio })
    }

    var mediaTabs: [UUID] {
        tabs.map(\.id).filter { tabId in
            guard let state = tabMediaStates[tabId] else { return false }
            return state.isPlaying || state.hasVideo || state.isMuted
        }
    }

    // MARK: - Media Controls

    func togglePlayPauseMedia(for tabId: UUID) {
        let script = "if (window.__lotusToggleMediaPlayPause) { window.__lotusToggleMediaPlayPause(); }"
        webViewStore[tabId]?.evaluateJavaScript(script, in: nil, in: .defaultClient, completionHandler: nil)
    }

    func triggerPictureInPicture(for tabId: UUID) {
        let script = "if (window.__lotusTriggerPiP) { window.__lotusTriggerPiP(); }"
        webViewStore[tabId]?.evaluateJavaScript(script, in: nil, in: .defaultClient, completionHandler: nil)
    }
}
