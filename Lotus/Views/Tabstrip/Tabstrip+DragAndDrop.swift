//
//  Tabstrip+DragAndDrop.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

// MARK: - Drag Handling

extension Tabstrip {
    var pinZoneThresholdY: CGFloat {
        let count = browserState.pinnedTabs.count
        let currentPinnedHeight: CGFloat
        if count == 0 {
            currentPinnedHeight = (activeDrag?.isHoveringPinZone == true) ? 46 : 0
        } else {
            let cols = count <= 4 ? count : 3
            let rows = (count + cols - 1) / cols
            currentPinnedHeight = CGFloat(rows) * 38 + CGFloat(max(0, rows - 1)) * 8 + 10
        }
        return headerHeight + currentPinnedHeight
    }

    func handleDragChanged(tab: TabItem, source: TabDragState.Source, value: DragGesture.Value) {
        let index: Int
        if source == .pinned {
            index = browserState.pinnedTabs.firstIndex(where: { $0.id == tab.id }) ?? 0
        } else {
            index = browserState.unpinnedTabs.firstIndex(where: { $0.id == tab.id }) ?? 0
        }
        handleDragChanged(tab: tab, source: source, index: index, value: value)
    }

    func handleDragChanged(tab: TabItem, source: TabDragState.Source, index: Int, value: DragGesture.Value) {
        if activeDrag == nil {
            browserState.selectTab(tab)
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }

        let location = value.location
        let isAbove = location.y < pinZoneThresholdY
        let wasAbove = activeDrag?.isHoveringPinZone ?? (source == .pinned)

        if activeDrag != nil && wasAbove != isAbove {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }

        let targetIdx: Int
        if isAbove {
            targetIdx = calculatePinnedTargetIndex(location: location, source: source)
        } else {
            targetIdx = calculateUnpinnedTargetIndex(location: location, source: source, originalIndex: index)
        }

        let previousTarget = activeDrag?.targetIndex
        let targetChanged = (previousTarget != targetIdx) || (wasAbove != isAbove)

        if targetChanged {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }

        let newDragState = TabDragState(
            tabId: tab.id,
            tab: tab,
            source: source,
            originalIndex: index,
            location: location,
            isHoveringPinZone: isAbove,
            targetIndex: targetIdx
        )

        if targetChanged || activeDrag == nil {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                activeDrag = newDragState
            }
        } else {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                activeDrag = newDragState
            }
        }
    }

    func handleDragEnded(value: DragGesture.Value) {
        guard let drag = activeDrag else { return }

        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            var newTabs = browserState.tabs

            if drag.isHoveringPinZone {
                // Dropped in Pinned Zone
                if drag.source == .unpinned {
                    // Pin the tab & insert into target pinned position
                    if let mainIndex = newTabs.firstIndex(where: { $0.id == drag.tab.id }) {
                        newTabs[mainIndex].isPinned = true
                        let movedTab = newTabs.remove(at: mainIndex)

                        let currentPinned = newTabs.filter { $0.isPinned && $0.id != movedTab.id }
                        if drag.targetIndex < currentPinned.count {
                            let targetTab = currentPinned[drag.targetIndex]
                            if let mainTargetIndex = newTabs.firstIndex(where: { $0.id == targetTab.id }) {
                                newTabs.insert(movedTab, at: mainTargetIndex)
                            } else {
                                newTabs.insert(movedTab, at: 0)
                            }
                        } else {
                            if let lastPinned = currentPinned.last, let lastIndex = newTabs.firstIndex(where: { $0.id == lastPinned.id }) {
                                newTabs.insert(movedTab, at: lastIndex + 1)
                            } else {
                                newTabs.insert(movedTab, at: 0)
                            }
                        }
                    }
                } else {
                    // Reorder within pinned tabs
                    let otherPinned = newTabs.filter { $0.isPinned && $0.id != drag.tabId }
                    if let mainFrom = newTabs.firstIndex(where: { $0.id == drag.tabId }) {
                        let movedTab = newTabs.remove(at: mainFrom)
                        if drag.targetIndex < otherPinned.count {
                            let targetTab = otherPinned[drag.targetIndex]
                            if let mainTo = newTabs.firstIndex(where: { $0.id == targetTab.id }) {
                                newTabs.insert(movedTab, at: mainTo)
                            } else {
                                newTabs.insert(movedTab, at: 0)
                            }
                        } else {
                            if let lastPinned = otherPinned.last, let lastIndex = newTabs.firstIndex(where: { $0.id == lastPinned.id }) {
                                newTabs.insert(movedTab, at: lastIndex + 1)
                            } else {
                                newTabs.insert(movedTab, at: 0)
                            }
                        }
                    }
                }
            } else {
                // Dropped in Unpinned Zone
                if drag.source == .pinned {
                    // Unpin the tab & insert into target unpinned position
                    if let mainIndex = newTabs.firstIndex(where: { $0.id == drag.tab.id }) {
                        newTabs[mainIndex].isPinned = false
                        let movedTab = newTabs.remove(at: mainIndex)

                        let currentUnpinned = newTabs.filter { !$0.isPinned && $0.id != movedTab.id }
                        if drag.targetIndex < currentUnpinned.count {
                            let targetTab = currentUnpinned[drag.targetIndex]
                            if let mainTargetIndex = newTabs.firstIndex(where: { $0.id == targetTab.id }) {
                                newTabs.insert(movedTab, at: mainTargetIndex)
                            } else {
                                newTabs.append(movedTab)
                            }
                        } else {
                            newTabs.append(movedTab)
                        }
                    }
                } else {
                    // Reorder within unpinned tabs
                    let unpinned = newTabs.filter { !$0.isPinned }
                    if drag.originalIndex < unpinned.count && drag.targetIndex < unpinned.count && drag.originalIndex != drag.targetIndex {
                        let movedTab = unpinned[drag.originalIndex]
                        if let mainFrom = newTabs.firstIndex(where: { $0.id == movedTab.id }) {
                            newTabs.remove(at: mainFrom)
                            let currentUnpinned = newTabs.filter { !$0.isPinned }
                            let targetIndex = min(drag.targetIndex, currentUnpinned.count)
                            if targetIndex < currentUnpinned.count {
                                let targetTab = currentUnpinned[targetIndex]
                                if let mainTo = newTabs.firstIndex(where: { $0.id == targetTab.id }) {
                                    newTabs.insert(movedTab, at: mainTo)
                                } else {
                                    newTabs.append(movedTab)
                                }
                            } else {
                                newTabs.append(movedTab)
                            }
                        }
                    }
                }
            }

            browserState.tabs = newTabs
            activeDrag = nil
        }
    }

    func calculatePinnedTargetIndex(location: CGPoint, source: TabDragState.Source) -> Int {
        let cols = pinnedColumnCount
        let colWidth = (browserState.sidebarWidth - 16 - CGFloat(cols - 1) * 8) / CGFloat(cols)
        let relativeX = location.x - 8
        let relativeY = location.y - headerHeight

        let col = min(max(0, Int(relativeX / (colWidth + 8))), cols - 1)
        let row = max(0, Int(relativeY / pinnedRowHeight))
        let index = row * cols + col
        let count = source == .pinned ? max(0, browserState.pinnedTabs.count - 1) : browserState.pinnedTabs.count
        return max(0, min(count, index))
    }

    func calculateUnpinnedTargetIndex(location: CGPoint, source: TabDragState.Source, originalIndex: Int) -> Int {
        let unpinnedStartY = headerHeight + pinnedGridHeight + newTabButtonHeight + 3
        let relativeY = location.y - unpinnedStartY
        let rawIndex = Int((relativeY / rowHeight).rounded())
        let maxIndex = max(0, browserState.unpinnedTabs.count - (source == .unpinned ? 1 : 0))
        return max(0, min(maxIndex, rawIndex))
    }

    func pinnedShiftOffset(for tabId: UUID) -> CGSize {
        guard let drag = activeDrag, drag.isHoveringPinZone,
              let index = browserState.pinnedTabs.firstIndex(where: { $0.id == tabId }) else {
            return .zero
        }
        return pinnedShiftOffset(for: index)
    }

    func unpinnedShiftOffset(for tabId: UUID) -> CGFloat {
        guard let drag = activeDrag,
              let index = browserState.unpinnedTabs.firstIndex(where: { $0.id == tabId }) else {
            return 0
        }
        return unpinnedShiftOffset(for: index)
    }

    func pinnedShiftOffset(for index: Int) -> CGSize {
        guard let drag = activeDrag, drag.isHoveringPinZone else { return .zero }

        let cols = pinnedColumnCount
        let cardWidth = (browserState.sidebarWidth - 16 - CGFloat(cols - 1) * 8) / CGFloat(cols)
        let slotSpacingX = cardWidth + 8
        let slotSpacingY: CGFloat = 46 // 38pt card + 8pt spacing

        if drag.source == .pinned {
            let origin = drag.originalIndex
            let target = drag.targetIndex

            var visualSlot = index
            if index == origin {
                visualSlot = target
            } else if origin < target {
                if index > origin && index <= target {
                    visualSlot = index - 1
                }
            } else if origin > target {
                if index >= target && index < origin {
                    visualSlot = index + 1
                }
            }

            let originCol = index % cols
            let originRow = index / cols
            let targetCol = visualSlot % cols
            let targetRow = visualSlot / cols

            let offsetX = CGFloat(targetCol - originCol) * slotSpacingX
            let offsetY = CGFloat(targetRow - originRow) * slotSpacingY
            return CGSize(width: offsetX, height: offsetY)
        } else {
            // drag.source == .unpinned
            if index >= drag.targetIndex {
                let visualSlot = index + 1
                let originCol = index % cols
                let originRow = index / cols
                let targetCol = visualSlot % cols
                let targetRow = visualSlot / cols

                let offsetX = CGFloat(targetCol - originCol) * slotSpacingX
                let offsetY = CGFloat(targetRow - originRow) * slotSpacingY
                return CGSize(width: offsetX, height: offsetY)
            }
            return .zero
        }
    }

    func unpinnedShiftOffset(for index: Int) -> CGFloat {
        guard let drag = activeDrag else { return 0 }

        if drag.source == .unpinned {
            if drag.isHoveringPinZone {
                if index > drag.originalIndex {
                    return -rowHeight
                }
                return 0
            } else {
                if index == drag.originalIndex {
                    return CGFloat(drag.targetIndex - drag.originalIndex) * rowHeight
                }
                let origin = drag.originalIndex
                let target = drag.targetIndex
                if origin < target {
                    if index > origin && index <= target {
                        return -rowHeight
                    }
                } else if origin > target {
                    if index >= target && index < origin {
                        return rowHeight
                    }
                }
                return 0
            }
        } else {
            if !drag.isHoveringPinZone {
                if index >= drag.targetIndex {
                    return rowHeight
                }
            }
            return 0
        }
    }
}
