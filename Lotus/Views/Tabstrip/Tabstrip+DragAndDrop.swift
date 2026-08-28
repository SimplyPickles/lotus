//
//  Tabstrip+DragAndDrop.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

// MARK: - Drag Handling

extension Tabstrip {

    func prospectivePinnedCount(for units: [SidebarTabUnit]) -> Int {
        let draggedIds = Set(units.flatMap(\.tabIds))
        let remainingCount = browserState.pinnedTabs.filter { !draggedIds.contains($0.id) }.count
        return remainingCount + draggedIds.count
    }

    func pinnedHeight(for count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let columns = count <= 4 ? count : 3
        let rows = (count + columns - 1) / columns
        return CGFloat(rows) * 38 + CGFloat(max(0, rows - 1)) * 8 + 10
    }

    func handleDragChanged(tab: TabItem, source: TabDragState.Source, rowIndex: Int? = nil, value: DragGesture.Value) {
        let index: Int
        if source == .pinned {
            index = browserState.pinnedTabs.firstIndex(where: { $0.id == tab.id }) ?? 0
        } else {
            index = rowIndex ?? (unpinnedRows.firstIndex(where: { $0.contains(tab.id) }) ?? 0)
        }
        handleDragChanged(tab: tab, source: source, index: index, value: value)
    }

    func handleDragChanged(tab: TabItem, source: TabDragState.Source, index: Int, value: DragGesture.Value) {
        let isStartingDrag = activeDrag == nil
        if isStartingDrag {
            HapticFeedback.perform(.alignment, performanceTime: .now)
        }

        let location = value.location
        let sidebarW = browserState.sidebarWidth
        let isOverSidebar = location.x < sidebarW
        let draggedUnits = activeDrag?.draggedUnits.isEmpty == false
            ? (activeDrag?.draggedUnits ?? [])
            : browserState.selectedUnitsForDrag(startingAt: tab.id)

        var splitTarget: TabDragState.SplitDropTarget? = nil
        var isAbove = false
        var targetIdx: Int = index

        let canSplit = draggedUnits.count == 1
            && draggedUnits.first?.isSplit == false
            && browserState.canOpenInSplit(id: tab.id)
        // Pinning a split pair is allowed; `moveTabUnits` dissolves its split
        // group as it converts the payload into pinned tabs.
        let canPin = true

        let currentRows = unpinnedRows

        if !isOverSidebar {
            if canSplit {
                // Dragging over browser container area with valid split conditions
                let windowWidth = NSApp.keyWindow?.contentView?.bounds.width ?? 800
                let windowHeight = NSApp.keyWindow?.contentView?.bounds.height ?? 600
                let (leftFrame, rightFrame) = browserState.splitTargetFrames(windowWidth: windowWidth, windowHeight: windowHeight)

                // Magnetic catch bounds for split target drop zones
                if leftFrame.insetBy(dx: -28, dy: -28).contains(location) {
                    splitTarget = .left
                } else if rightFrame.insetBy(dx: -28, dy: -28).contains(location) {
                    splitTarget = .right
                } else {
                    splitTarget = nil
                }
            } else {
                splitTarget = nil
            }
            targetIdx = index
            isAbove = (source == .pinned)
        } else {
            // Dragging inside sidebar
            let prospectivePinThreshold = headerHeight + max(
                pinnedGridHeight,
                pinnedHeight(for: prospectivePinnedCount(for: draggedUnits))
            )
            isAbove = canPin && (location.y < prospectivePinThreshold)
            if isAbove {
                targetIdx = calculatePinnedTargetIndex(location: location, draggedUnits: draggedUnits)
            } else {
                targetIdx = calculateUnpinnedTargetIndex(location: location, draggedUnits: draggedUnits, in: currentRows)
            }
        }

        // Live preview: would this drop position put the tab inside a
        // folder? Drives real-time shrink/grow of the floating ghost.
        var targetFolderId: UUID? = nil
        if isOverSidebar && !isAbove {
            let draggedIds = Set(draggedUnits.flatMap(\.tabIds))
            let reducedRows = currentRows.filter { !$0.containsAny(draggedIds) }
            let relativeY = unpinnedContentY(for: location)
            let hoverTarget = folderMembershipForHover(
                at: relativeY,
                in: currentRows,
                excluding: draggedIds
            )

            if hoverTarget.forcesLoosePlacement {
                // The upper half of a folder header is an intentional loose
                // slot before it. Do not let the preceding folder's tail
                // adoption pull the tab into the wrong group.
                targetFolderId = nil
            } else if let folderId = hoverTarget.folderId {
                targetFolderId = folderId
            } else {
                let insertAt = min(targetIdx, reducedRows.count)
                targetFolderId = adoptedFolderIdForInsertion(at: insertAt, in: reducedRows)
            }
        }

        let previousTarget = activeDrag?.targetIndex
        let previousTargetFolderId = activeDrag?.targetFolderId
        let previousSplitTarget = activeDrag?.splitDropTarget
        let wasAbove = activeDrag?.isHoveringPinZone ?? (source == .pinned)

        let targetChanged: Bool
        if isOverSidebar {
            targetChanged = (previousTarget != targetIdx)
                || (previousTargetFolderId != targetFolderId)
                || (wasAbove != isAbove)
                || (previousSplitTarget != nil)
        } else if canSplit {
            targetChanged = (previousSplitTarget != splitTarget)
        } else {
            targetChanged = false
        }

        if targetChanged && !isStartingDrag {
            HapticFeedback.perform(.alignment, performanceTime: .now)
        }

        let newDragState = TabDragState(
            tabId: tab.id,
            tab: tab,
            source: source,
            originalIndex: index,
            location: location,
            isHoveringPinZone: isAbove,
            targetIndex: targetIdx,
            splitDropTarget: splitTarget,
            draggedUnits: draggedUnits,
            wouldJoinFolder: targetFolderId != nil,
            targetFolderId: targetFolderId
        )

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            browserState.activeTabDrag = newDragState
            activeDrag = newDragState
        }
    }

    // MARK: - Folder Dragging

    /// The dragged folder's block in the current row list: header index plus
    /// the number of rows it spans (1 for the header, + visible member rows).
    func folderBlockInfo(_ folderId: UUID, in rows: [UnpinnedTabRow]) -> (start: Int, rowCount: Int)? {
        guard let start = rows.firstIndex(where: {
            if case .folderHeader(let folder) = $0 { return folder.id == folderId }
            return false
        }) else { return nil }
        var count = 1
        var next = start + 1
        while next < rows.count, rows[next].memberFolderId == folderId {
            count += 1
            next += 1
        }
        return (start, count)
    }

    /// Drag handler for folder header rows. The folder previews as a single
    /// collapsed header while dragging, but its complete member block is
    /// preserved for the final reorder. Pin-zone and split targets don't
    /// apply, and the drag stays local to the tabstrip.
    func handleFolderDragChanged(folder: TabFolder, rowIndex: Int, value: DragGesture.Value) {
        if activeDrag == nil {
            HapticFeedback.perform(.alignment, performanceTime: .now)
            browserState.clearSidebarSelection()
        }

        let location = value.location
        let rows = unpinnedRows
        guard let block = folderBlockInfo(folder.id, in: rows) else { return }

        // Target is an insertion position in the row list *without* the block.
        var targetIdx = block.start
        if location.x < browserState.sidebarWidth {
            let relativeY = unpinnedContentY(for: location)
            let raw = Int((relativeY + rowHeight * 0.5) / rowHeight)
            let reducedCount = rows.count - block.rowCount
            let target = min(max(0, raw), reducedCount)
            targetIdx = snappedFolderTargetIndex(target, blockStart: block.start, blockCount: block.rowCount, rows: rows)
        }

        if let previous = activeDrag?.targetIndex, previous != targetIdx {
            HapticFeedback.perform(.alignment, performanceTime: .now)
        }

        let placeholder = TabItem(id: folder.id, title: folder.name)
        let newDrag = TabDragState(
            tabId: folder.id,
            tab: placeholder,
            source: .unpinned,
            originalIndex: block.start,
            location: location,
            isHoveringPinZone: false,
            targetIndex: targetIdx,
            splitDropTarget: nil,
            folder: folder
        )

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            browserState.activeTabDrag = newDrag
            activeDrag = newDrag
        }
    }

    /// Folders are top-level: a folder block may not land inside another
    /// folder's member span. Walks forward past the blocked span; bails back
    /// to the original position when nothing fits.
    func snappedFolderTargetIndex(_ raw: Int, blockStart: Int, blockCount: Int, rows: [UnpinnedTabRow]) -> Int {
        var reduced = rows
        let headerRow = reduced[blockStart]
        reduced.removeSubrange(blockStart..<blockStart + blockCount)
        guard !reduced.isEmpty else { return 0 }

        var target = min(max(0, raw), reduced.count)
        var iterations = 0
        while iterations <= reduced.count {
            iterations += 1
            var hypothetical = reduced
            let insertAt = min(target, hypothetical.count)
            hypothetical.insert(headerRow, at: insertAt)
            if adoptedFolderId(at: insertAt, in: hypothetical) == nil {
                return target
            }
            target += 1
            if target > reduced.count {
                return blockStart
            }
        }
        return blockStart
    }

    func handleDragEnded(value: DragGesture.Value) {
        // SwiftUI can deliver a final gesture location that is newer than the
        // last onChanged value. Resolve it once before committing so a release
        // on a folder boundary uses the same target the cursor is over.
        let dragBeforeFinalResolution = activeDrag
        if let currentDrag = dragBeforeFinalResolution {
            if let folder = currentDrag.folder {
                handleFolderDragChanged(
                    folder: folder,
                    rowIndex: currentDrag.originalIndex,
                    value: value
                )
            } else {
                handleDragChanged(
                    tab: currentDrag.tab,
                    source: currentDrag.source,
                    index: currentDrag.originalIndex,
                    value: value
                )
            }
        }

        let didResolveFinalTargetChange: Bool
        if let dragBeforeFinalResolution, let resolvedDrag = activeDrag {
            didResolveFinalTargetChange = dragBeforeFinalResolution.targetIndex != resolvedDrag.targetIndex
                || dragBeforeFinalResolution.targetFolderId != resolvedDrag.targetFolderId
                || dragBeforeFinalResolution.isHoveringPinZone != resolvedDrag.isHoveringPinZone
                || dragBeforeFinalResolution.splitDropTarget != resolvedDrag.splitDropTarget
        } else {
            didResolveFinalTargetChange = false
        }

        guard let drag = activeDrag else { return }

        // Folder header drop: reorder the whole folder block.
        if let folder = drag.folder {
            if !didResolveFinalTargetChange {
                HapticFeedback.perform(.alignment, performanceTime: .now)
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                if drag.location.x < browserState.sidebarWidth {
                    let rows = unpinnedRows
                    if let block = folderBlockInfo(folder.id, in: rows) {
                        let target = min(max(0, drag.targetIndex), rows.count - block.rowCount)
                        if target != block.start {
                            var reduced = rows
                            let blockRows = Array(reduced[block.start..<block.start + block.rowCount])
                            reduced.removeSubrange(block.start..<block.start + block.rowCount)
                            reduced.insert(contentsOf: blockRows, at: min(target, reduced.count))
                            let currentProfId = browserState.currentProfileId
                            let otherProfileTabs = browserState.tabs.filter { ($0.profileId ?? browserState.defaultProfileId) != currentProfId }
                            let currentPinnedTabs = browserState.tabs.filter { ($0.profileId ?? browserState.defaultProfileId) == currentProfId && $0.isPinned }
                            browserState.tabs = currentPinnedTabs + flattenUnpinnedRows(reduced, movedRowIndex: nil) + otherProfileTabs
                        }
                    }
                }
                activeDrag = nil
                browserState.activeTabDrag = nil
            }
            return
        }

        if let splitSide = drag.splitDropTarget,
           drag.draggedUnitCount == 1,
           drag.effectiveDraggedUnits.first?.isSplit == false,
           browserState.canOpenInSplit(id: drag.tab.id) {
            if !didResolveFinalTargetChange {
                HapticFeedback.perform(.alignment, performanceTime: .now)
            }
            activeDrag = nil
            browserState.activeTabDrag = nil
            browserState.openInSplit(id: drag.tab.id, side: splitSide == .left ? .left : .right)
            return
        }

        let destination: SidebarTabDropDestination?
        if drag.location.x < browserState.sidebarWidth {
            if !didResolveFinalTargetChange {
                HapticFeedback.perform(.alignment, performanceTime: .now)
            }

            if drag.isHoveringPinZone && drag.canPinPayload {
                destination = .pinned(index: drag.targetIndex)
            } else {
                let reducedRows = unpinnedRows.filter { !$0.containsAny(drag.draggedTabIds) }
                let target = min(max(0, drag.targetIndex), reducedRows.count)
                let beforeTabId = firstTabId(startingAt: target, in: reducedRows, excluding: drag.draggedTabIds)
                destination = .unpinned(beforeTabId: beforeTabId, folderId: drag.targetFolderId)
            }
        } else {
            destination = nil
        }

        // The live preview has already placed every row at its final visual
        // position. Commit the model and remove offsets atomically without a
        // second layout animation, which would make rows jump vertically.
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            if let destination {
                browserState.moveTabUnits(drag.effectiveDraggedUnits, to: destination)
            }
            activeDrag = nil
            browserState.activeTabDrag = nil
        }
    }

    /// Flattens sidebar rows back into the unpinned tab order. The moved row
    /// adopts folder membership from its drop position; every other row keeps
    /// its own. Folder headers contribute no tabs — they are derived views of
    /// the membership being written here.
    func flattenUnpinnedRows(_ rows: [UnpinnedTabRow], movedRowIndex: Int?) -> [TabItem] {
        var result: [TabItem] = []
        for (index, row) in rows.enumerated() {
            switch row {
            case .folderHeader(let folder):
                // Collapsed folders hide their member rows — re-emit those
                // tabs here or they'd be dropped from the tabs array. A row
                // dropped right below the header lands after them, keeping
                // members contiguous.
                if folder.isCollapsed {
                    result.append(contentsOf: browserState.folderTabs(folder.id))
                }
            case .single(var tab):
                if index == movedRowIndex {
                    tab.folderId = adoptedFolderId(at: index, in: rows)
                }
                result.append(tab)
            case .split(var t1, var t2):
                if index == movedRowIndex {
                    let folderId = adoptedFolderId(at: index, in: rows)
                    t1.folderId = folderId
                    t2.folderId = folderId
                }
                result.append(t1)
                result.append(t2)
            }
        }
        return result
    }

    /// Folder adopted by a row dropped at `index`:
    /// - between an expanded folder's header and its first member → that folder
    /// - between two members of the same folder → that folder
    /// - anywhere else → loose. In particular, dropping below a collapsed or
    ///   empty folder lands *below* the folder, never inside it.
    func adoptedFolderId(at index: Int, in rows: [UnpinnedTabRow]) -> UUID? {
        guard index > 0 else { return nil }
        let above = rows[index - 1]
        if case .folderHeader(let folder) = above {
            if !folder.isCollapsed {
                return folder.id
            }
            return nil
        }
        if let aboveFolderId = above.memberFolderId,
           index < rows.count,
           rows[index].memberFolderId == aboveFolderId {
            return aboveFolderId
        }
        return nil
    }

    func adoptedFolderIdForInsertion(at index: Int, in rows: [UnpinnedTabRow]) -> UUID? {
        guard index > 0, index <= rows.count else { return nil }
        let above = rows[index - 1]
        let below = index < rows.count ? rows[index] : nil

        if case .folderHeader(let folder) = above,
           !folder.isCollapsed {
            return folder.id
        }
        if let folderId = above.memberFolderId {
            if below?.memberFolderId == folderId {
                return folderId
            }
            // A row inserted immediately after an expanded folder's last
            // visible member remains part of that folder.
            if browserState.folder(for: folderId)?.isCollapsed == false {
                return folderId
            }
        }
        return nil
    }

    /// Resolves folder membership from the visible row beneath the pointer.
    /// `targetIndex` remains the reduced-row insertion slot from
    /// `calculateUnpinnedTargetIndex`; this helper only supplies the
    /// membership intent that drives the ghost and final model commit.
    func folderMembershipForHover(
        at relativeY: CGFloat,
        in rows: [UnpinnedTabRow],
        excluding draggedIds: Set<UUID>
    ) -> (folderId: UUID?, forcesLoosePlacement: Bool) {
        let rowIndex = Int(relativeY / rowHeight)
        guard rows.indices.contains(rowIndex) else {
            return (nil, false)
        }

        let row = rows[rowIndex]
        guard !row.containsAny(draggedIds) else {
            return (nil, false)
        }

        let insertionIndex = Int((relativeY + rowHeight * 0.5) / rowHeight)
        let isInLowerHalf = insertionIndex > rowIndex

        switch row {
        case .folderHeader(let folder):
            // The upper half intentionally creates a loose row immediately
            // before the folder; the lower half joins at its visible start.
            return isInLowerHalf ? (folder.id, false) : (nil, true)

        case .single(let tab):
            // An explicit lower-half member target makes the trailing gap of
            // an expanded folder's final tab reliably append to that folder.
            return isInLowerHalf ? (tab.folderId, false) : (nil, false)

        case .split(let first, _):
            return isInLowerHalf ? (first.folderId, false) : (nil, false)
        }
    }

    func firstTabId(in row: UnpinnedTabRow, excluding excludedIds: Set<UUID>) -> UUID? {
        switch row {
        case .single(let tab):
            return excludedIds.contains(tab.id) ? nil : tab.id
        case .split(let first, let second):
            return [first.id, second.id].first(where: { !excludedIds.contains($0) })
        case .folderHeader(let folder):
            return browserState.folderTabs(folder.id).map(\.id).first(where: { !excludedIds.contains($0) })
        }
    }

    func firstTabId(startingAt index: Int, in rows: [UnpinnedTabRow], excluding excludedIds: Set<UUID>) -> UUID? {
        guard index < rows.count else { return nil }
        for i in index..<rows.count {
            if let tabId = firstTabId(in: rows[i], excluding: excludedIds) {
                return tabId
            }
        }
        return nil
    }

    /// Returns the active rows without the dragged tabs and the insertion slot.
    func projectedReducedRows(for drag: TabDragState, in rows: [UnpinnedTabRow]? = nil) -> (rows: [UnpinnedTabRow], target: Int) {
        let activeRows = rows ?? unpinnedRows
        let basicRows = activeRows.filter { !$0.containsAny(drag.draggedTabIds) }
        let basicTarget = min(max(0, drag.targetIndex), basicRows.count)
        return (basicRows, basicTarget)
    }

    func calculatePinnedTargetIndex(location: CGPoint, draggedUnits: [SidebarTabUnit]) -> Int {
        let count = prospectivePinnedCount(for: draggedUnits)
        let cols = count <= 4 ? max(1, count) : 3
        let cardWidth = (browserState.sidebarWidth - 16 - CGFloat(cols - 1) * 8) / CGFloat(cols)
        let slotWidth = cardWidth + 8
        let relativeX = max(0, location.x - 8)
        let relativeY = max(0, location.y - headerHeight - 4)
        let col = min(max(0, Int(relativeX / slotWidth)), cols - 1)
        let row = max(0, Int(relativeY / pinnedRowHeight))
        let rawIndex = row * cols + col
        let draggedIds = Set(draggedUnits.flatMap(\.tabIds))
        let remainingCount = browserState.pinnedTabs.filter { !draggedIds.contains($0.id) }.count
        return min(max(0, rawIndex), remainingCount)
    }

    func calculateUnpinnedTargetIndex(location: CGPoint, draggedUnits: [SidebarTabUnit], in rows: [UnpinnedTabRow]? = nil) -> Int {
        let activeRows = rows ?? unpinnedRows
        let relativeY = unpinnedContentY(for: location)
        let rawIndex = Int((relativeY + rowHeight * 0.5) / rowHeight)
        let draggedIds = Set(draggedUnits.flatMap(\.tabIds))
        let selectedIndices = activeRows.indices.filter { activeRows[$0].containsAny(draggedIds) }
        let removedBeforePointer = selectedIndices.filter { $0 < rawIndex }.count
        let reducedCount = activeRows.count - selectedIndices.count
        return min(max(0, rawIndex - removedBeforePointer), reducedCount)
    }

    /// Converts a drag location in the window coordinate space into the
    /// vertical coordinate of the scroll view's content.
    func unpinnedContentY(for location: CGPoint) -> CGFloat {
        let unpinnedStartY = headerHeight + pinnedGridHeight + newTabButtonHeight + 4
        return max(0, location.y - unpinnedStartY + unpinnedScrollOffset)
    }

    func pinnedShiftOffset(for tabId: UUID) -> CGSize {
        guard let index = browserState.pinnedTabs.firstIndex(where: { $0.id == tabId }) else {
            return .zero
        }
        return pinnedShiftOffset(for: index)
    }

    func unpinnedShiftOffset(forRowIndex index: Int, in rows: [UnpinnedTabRow]? = nil) -> CGFloat {
        guard let drag = activeDrag else { return 0 }
        let activeRows = rows ?? unpinnedRows

        // A dragged folder previews as collapsed in the sidebar. Its member
        // rows collapse out of layout while the header reorders like one row;
        // the full model block still moves atomically when dropped.
        if let draggedFolder = drag.folder {
            if drag.location.x >= browserState.sidebarWidth { return 0 }
            guard let block = folderBlockInfo(draggedFolder.id, in: activeRows) else { return 0 }
            let origin = block.start
            let target = drag.targetIndex

            if index == origin {
                return CGFloat(target - origin) * rowHeight
            }
            if index > origin && index < origin + block.rowCount {
                return 0
            }

            let reducedIndex = index < origin ? index : index - block.rowCount
            if origin < target, reducedIndex >= origin, reducedIndex < target {
                return -rowHeight
            }
            if origin > target, reducedIndex >= target, reducedIndex < origin {
                return rowHeight
            }
            return 0
        }

        guard index < activeRows.count else { return 0 }
        let row = activeRows[index]
        if row.containsAny(drag.draggedTabIds) { return 0 }

        let projection = projectedReducedRows(for: drag, in: activeRows)
        var projectedIds = projection.rows.map(\.id)
        let reservesUnpinnedSpace = drag.location.x < browserState.sidebarWidth
            && !drag.isHoveringPinZone
            && drag.splitDropTarget == nil
        if reservesUnpinnedSpace {
            let placeholders = (0..<drag.draggedUnitCount).map { "drag_placeholder_\($0)" }
            projectedIds.insert(contentsOf: placeholders, at: min(projection.target, projectedIds.count))
        }
        guard let newIndex = projectedIds.firstIndex(of: row.id) else { return 0 }
        return CGFloat(newIndex - index) * rowHeight
    }

    func pinnedShiftOffset(for index: Int) -> CGSize {
        guard let drag = activeDrag, drag.folder == nil else { return .zero }
        let pinned = browserState.pinnedTabs
        guard index < pinned.count else { return .zero }
        let tabId = pinned[index].id
        if drag.draggedTabIds.contains(tabId) { return .zero }

        let remainingIds = pinned.map(\.id).filter { !drag.draggedTabIds.contains($0) }
        guard let reducedSlot = remainingIds.firstIndex(of: tabId) else { return .zero }
        if drag.isHoveringPinZone && drag.canPinPayload {
            let insertionIndex = min(max(0, drag.targetIndex), remainingIds.count)
            let newSlot = reducedSlot >= insertionIndex
                ? reducedSlot + drag.draggedTabIds.count
                : reducedSlot
            return pinnedGridOffset(from: index, to: newSlot)
        }

        let newSlot = reducedSlot
        return pinnedGridOffset(from: index, to: newSlot)
    }

    func pinnedGridOffset(from originalSlot: Int, to targetSlot: Int) -> CGSize {
        let cols = pinnedColumnCount
        let cardWidth = (browserState.sidebarWidth - 16 - CGFloat(cols - 1) * 8) / CGFloat(cols)
        let slotSpacingX = cardWidth + 8
        let originCol = originalSlot % cols
        let originRow = originalSlot / cols
        let targetCol = targetSlot % cols
        let targetRow = targetSlot / cols
        return CGSize(
            width: CGFloat(targetCol - originCol) * slotSpacingX,
            height: CGFloat(targetRow - originRow) * pinnedRowHeight
        )
    }
}
