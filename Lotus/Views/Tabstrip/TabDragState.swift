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

    enum SplitDropTarget {
        case left
        case right
    }

    let tabId: UUID
    let tab: TabItem
    let source: Source
    let originalIndex: Int
    var location: CGPoint
    var isHoveringPinZone: Bool
    var targetIndex: Int
    var splitDropTarget: SplitDropTarget? = nil
    /// Atomic tab/split units captured when the drag begins. An empty value
    /// is retained for folder-header drags and compatibility with old states.
    var draggedUnits: [SidebarTabUnit] = []
    /// True when the current drop position would place the tab inside a
    /// folder — drives the floating ghost's live width preview.
    var wouldJoinFolder: Bool = false
    /// Folder membership the payload will adopt at the current insertion point.
    var targetFolderId: UUID? = nil
    /// Set when a folder header (not a tab) is being dragged; `tab` is then a
    /// synthetic placeholder and pin/split targets are disabled.
    var folder: TabFolder? = nil

    var effectiveDraggedUnits: [SidebarTabUnit] {
        if !draggedUnits.isEmpty { return draggedUnits }
        return [.tab(tab)]
    }

    var draggedTabIds: Set<UUID> {
        Set(effectiveDraggedUnits.flatMap(\.tabIds))
    }

    var draggedUnitCount: Int {
        effectiveDraggedUnits.count
    }

    var isMultiTabDrag: Bool {
        draggedUnitCount > 1
    }

    var canPinPayload: Bool {
        folder == nil
    }
}
