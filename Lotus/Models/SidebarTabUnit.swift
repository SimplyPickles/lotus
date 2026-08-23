//
//  SidebarTabUnit.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import Foundation

/// Atomic tabstrip item used by range selection and group dragging. Split
/// pairs remain one unit so reordering never separates their tabs.
enum SidebarTabUnit: Identifiable, Equatable {
    case tab(TabItem)
    case split(TabItem, TabItem)

    var id: String {
        switch self {
        case .tab(let tab):
            return tab.id.uuidString
        case .split(let first, let second):
            return "split_\(first.id.uuidString)_\(second.id.uuidString)"
        }
    }

    var tabs: [TabItem] {
        switch self {
        case .tab(let tab):
            return [tab]
        case .split(let first, let second):
            return [first, second]
        }
    }

    var tabIds: [UUID] {
        tabs.map(\.id)
    }

    var primaryTab: TabItem {
        tabs[0]
    }

    var isSplit: Bool {
        if case .split = self { return true }
        return false
    }

    var isPinned: Bool {
        tabs.allSatisfy(\.isPinned)
    }

    var folderId: UUID? {
        tabs.first?.folderId
    }

    func contains(_ tabId: UUID) -> Bool {
        tabIds.contains(tabId)
    }
}

enum SidebarTabDropDestination: Equatable {
    case pinned(index: Int)
    case unpinned(beforeTabId: UUID?, folderId: UUID?)
}
