//
//  BrowserState+TabReordering.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

extension BrowserState {

    /// Moves an ordered drag payload in one model assignment. Destination
    /// attributes apply to the complete payload so folder members stay
    /// contiguous and split pairs are never separated.
    @discardableResult
    func moveTabUnits(_ units: [SidebarTabUnit], to destination: SidebarTabDropDestination) -> Bool {
        guard !units.isEmpty else { return false }
        if case .pinned = destination, units.contains(where: \.isSplit) {
            return false
        }

        var seenIds = Set<UUID>()
        let orderedIds = units.flatMap(\.tabIds).filter { seenIds.insert($0).inserted }
        guard orderedIds.allSatisfy({ tab(for: $0) != nil }) else { return false }

        let movedIdSet = Set(orderedIds)
        var remaining = tabs.filter { !movedIdSet.contains($0.id) }
        var moved = orderedIds.compactMap { id in tabs.first(where: { $0.id == id }) }

        switch destination {
        case .pinned(let requestedIndex):
            for index in moved.indices {
                moved[index].isPinned = true
                moved[index].folderId = nil
            }

            let remainingPinned = remaining.filter(\.isPinned)
            let targetIndex = min(max(0, requestedIndex), remainingPinned.count)
            let insertionIndex: Int
            if targetIndex < remainingPinned.count,
               let target = remaining.firstIndex(where: { $0.id == remainingPinned[targetIndex].id }) {
                insertionIndex = target
            } else if let lastPinned = remaining.lastIndex(where: \.isPinned) {
                insertionIndex = lastPinned + 1
            } else {
                insertionIndex = 0
            }
            remaining.insert(contentsOf: moved, at: insertionIndex)

        case .unpinned(let beforeTabId, let folderId):
            if let folderId, folder(for: folderId) == nil { return false }
            for index in moved.indices {
                moved[index].isPinned = false
                moved[index].folderId = folderId
            }

            let insertionIndex: Int
            if let beforeTabId,
               let target = remaining.firstIndex(where: { $0.id == beforeTabId }) {
                insertionIndex = target
            } else if let folderId,
                      let lastMember = remaining.lastIndex(where: { $0.folderId == folderId }) {
                insertionIndex = lastMember + 1
            } else {
                insertionIndex = remaining.count
            }
            remaining.insert(contentsOf: moved, at: insertionIndex)
        }

        tabs = remaining
        removeEmptyFolders()
        selectedSidebarTabIds = movedIdSet
        if let folderId = moved.first?.folderId {
            expandFolder(id: folderId)
        }
        return true
    }
}
