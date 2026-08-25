//
//  TabDropDelegate.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI

struct TabDropDelegate: DropDelegate {
    let currentTab: TabItem
    @ObservedObject var browserState: BrowserState
    @Binding var draggedTab: TabItem?

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedTab,
              dragged.id != currentTab.id,
              let from = browserState.tabs.firstIndex(where: { $0.id == dragged.id }),
              let to = browserState.tabs.firstIndex(where: { $0.id == currentTab.id }) else { return }

        if browserState.tabs[to].id != dragged.id {
            HapticFeedback.perform(.alignment, performanceTime: .default)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                browserState.tabs.move(
                    fromOffsets: IndexSet(integer: from),
                    toOffset: to > from ? to + 1 : to
                )
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTab = nil
        return true
    }

    func dropExited(info: DropInfo) {}
}
