//
//  TabDragState.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

struct TabDragState: Equatable {
    enum Source {
        case pinned
        case unpinned
    }

    let tabId: UUID
    let tab: TabItem
    let source: Source
    let originalIndex: Int
    var location: CGPoint
    var isHoveringPinZone: Bool
    var targetIndex: Int
}
