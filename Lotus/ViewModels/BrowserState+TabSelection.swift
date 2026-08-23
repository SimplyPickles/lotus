//
//  BrowserState+TabSelection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import Foundation

extension BrowserState {

    // MARK: - Sidebar Units

    var visibleSidebarUnits: [SidebarTabUnit] {
        var units = pinnedTabs.map { SidebarTabUnit.tab($0) }
        var handledIds = Set<UUID>()
        let unpinned = unpinnedTabs

        for item in unpinned where !handledIds.contains(item.id) {
            if let folderId = item.folderId, folder(for: folderId)?.isCollapsed == true {
                handledIds.insert(item.id)
                continue
            }

            if let group = splitGroup(containing: item.id),
               group.count == 2,
               let first = tab(for: group[0]),
               let second = tab(for: group[1]),
               !first.isPinned,
               !second.isPinned {
                units.append(.split(first, second))
                handledIds.formUnion(group)
            } else {
                units.append(.tab(item))
                handledIds.insert(item.id)
            }
        }

        return units
    }

    func sidebarUnit(containing tabId: UUID) -> SidebarTabUnit? {
        if let group = splitGroup(containing: tabId),
           group.count == 2,
           let first = tab(for: group[0]),
           let second = tab(for: group[1]) {
            return .split(first, second)
        }
        return tab(for: tabId).map { .tab($0) }
    }

    // MARK: - Sidebar Selection

    func selectSidebarTab(_ tabId: UUID, extendingRange: Bool) {
        guard let clickedUnit = visibleSidebarUnits.first(where: { $0.contains(tabId) }) else {
            selectTab(tabId)
            return
        }

        if extendingRange,
           let anchorId = sidebarSelectionAnchorId,
           let anchorIndex = visibleSidebarUnits.firstIndex(where: { $0.contains(anchorId) }),
           let clickedIndex = visibleSidebarUnits.firstIndex(where: { $0.id == clickedUnit.id }) {
            let range = min(anchorIndex, clickedIndex)...max(anchorIndex, clickedIndex)
            selectedSidebarTabIds = Set(range.flatMap { visibleSidebarUnits[$0].tabIds })
        } else {
            selectedSidebarTabIds = Set(clickedUnit.tabIds)
            sidebarSelectionAnchorId = tabId
        }

        activateTabContent(tabId)
    }

    func selectOnlySidebarUnit(containing tabId: UUID) {
        guard let unit = sidebarUnit(containing: tabId) else {
            selectedSidebarTabIds = []
            sidebarSelectionAnchorId = nil
            return
        }
        selectedSidebarTabIds = Set(unit.tabIds)
        sidebarSelectionAnchorId = tabId
    }

    func clearSidebarSelection() {
        selectedSidebarTabIds = []
        sidebarSelectionAnchorId = nil
    }

    func selectedUnitsForDrag(startingAt tabId: UUID) -> [SidebarTabUnit] {
        if !selectedSidebarTabIds.contains(tabId) {
            selectOnlySidebarUnit(containing: tabId)
        }

        let selected = selectedSidebarTabIds
        let units = visibleSidebarUnits.filter { unit in
            unit.tabIds.contains(where: selected.contains)
        }
        if units.isEmpty, let unit = sidebarUnit(containing: tabId) {
            return [unit]
        }
        return units
    }

    func normalizeSidebarSelection() {
        let visibleIds = Set(visibleSidebarUnits.flatMap(\.tabIds))
        var normalized = selectedSidebarTabIds.intersection(visibleIds)

        for id in Array(normalized) {
            if let group = splitGroup(containing: id) {
                normalized.formUnion(group.filter(visibleIds.contains))
            }
        }

        selectedSidebarTabIds = normalized
        if let anchorId = sidebarSelectionAnchorId, !visibleIds.contains(anchorId) {
            sidebarSelectionAnchorId = normalized.first
        }
    }
}
