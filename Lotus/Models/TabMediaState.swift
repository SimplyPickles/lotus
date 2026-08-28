//
//  TabMediaState.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import Foundation

struct TabMediaState: Equatable {
    var isPlaying: Bool = false
    var isMuted: Bool = false
    var hasAudio: Bool = false
    var hasVideo: Bool = false
    var mediaTitle: String? = nil

    var isPlayingAudio: Bool {
        isPlaying && hasAudio && !isMuted
    }
}
