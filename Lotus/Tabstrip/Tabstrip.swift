//
//  Tabstrip.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
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

struct Tabstrip: View {
    @ObservedObject var browserState: BrowserState
    @State private var dragStartWidth: CGFloat? = nil
    @State private var activeDrag: TabDragState? = nil
    @Namespace private var tabAnimationNamespace

    private let minWidth: CGFloat = 150
    private let maxWidth: CGFloat = 600
    private let defaultWidth: CGFloat = 240
    private let snapThreshold: CGFloat = 8
    private let collapseThreshold: CGFloat = 130
    private let headerHeight: CGFloat = 50
    private let rowHeight: CGFloat = 35 // 32pt tab + 3pt spacing
    private let pinnedRowHeight: CGFloat = 46 // 38pt card + 8pt spacing
    private let newTabButtonHeight: CGFloat = 35

    @State private var isSnappedToDefault: Bool = false
    @State private var isDragCollapsed: Bool = false
    @State private var wasInitiallyVisibleOnDragStart: Bool = false

    private var isPinnedTabSelected: Bool {
        browserState.activeTab?.isPinned == true
    }

    private var activeTabBackgroundColor: Color {
        let isInternal = browserState.activeURL?.scheme == "lotus" || browserState.activeURL?.absoluteString.hasPrefix("lotus://") == true
        if isInternal {
            return Color(nsColor: .windowBackgroundColor)
        }
        return browserState.activeThemeColor ?? Color(nsColor: .windowBackgroundColor)
    }

    /// The number of pinned tabs including a phantom slot when dragging an unpinned tab into the pin zone.
    private var effectivePinnedCount: Int {
        if let drag = activeDrag, drag.source == .unpinned, drag.isHoveringPinZone {
            return browserState.pinnedTabs.count + 1
        }
        return browserState.pinnedTabs.count
    }

    /// Dynamic column count: up to 4 tabs sit in a single row; 5+ wraps to 3 columns.
    private var pinnedColumnCount: Int {
        let count = effectivePinnedCount
        guard count > 0 else { return 1 }
        return count <= 4 ? count : 3
    }

    private var pinnedGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: pinnedColumnCount)
    }

    private var pinnedCardWidth: CGFloat {
        let cols = pinnedColumnCount
        return max(20, (browserState.sidebarWidth - 16 - CGFloat(cols - 1) * 8) / CGFloat(cols))
    }

    private var pinnedGridHeight: CGFloat {
        let count = effectivePinnedCount
        if count == 0 { return 0 }
        let cols = count <= 4 ? count : 3
        let rows = (count + cols - 1) / cols
        return CGFloat(rows) * 38 + CGFloat(max(0, rows - 1)) * 8 + 10
    }

    private var pinZoneThresholdY: CGFloat {
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

    var body: some View {
        VStack(spacing: 0) {
            // Fixed top section for traffic light clearance
            WindowDragArea()
                .frame(height: headerHeight)

            // Pinned Tabs Grid / Drop Zone
            VStack(spacing: 0) {
                if pinnedGridHeight > 0 {
                    LazyVGrid(columns: pinnedGridColumns, spacing: 8) {
                        ForEach(browserState.pinnedTabs, id: \.id) { tab in
                            let isBeingDragged = activeDrag?.tabId == tab.id

                            ZStack {
                                PinnedTabButton(
                                    tab: tab,
                                    isSelected: browserState.selectedTabId == tab.id,
                                    onSelect: {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                            browserState.selectTab(tab)
                                        }
                                    }
                                )
                                .opacity(isBeingDragged ? 0.0 : 1.0)
                                .offset(pinnedShiftOffset(for: tab.id))
                            }
                            .contextMenu {
                                Button("Unpin") {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        browserState.togglePin(id: tab.id)
                                    }
                                }
                                Button("Close", role: .destructive) {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        browserState.removeTab(id: tab.id)
                                    }
                                }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 3, coordinateSpace: .named("tabstrip"))
                                    .onChanged { value in
                                        handleDragChanged(tab: tab, source: .pinned, value: value)
                                    }
                                    .onEnded { value in
                                        handleDragEnded(value: value)
                                    }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }
            }
            .frame(height: pinnedGridHeight, alignment: .top)
            .clipped()
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: pinnedGridHeight)

            // New Tab Button
            NewTabButton {
                browserState.addTab()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 3)

            // Scrollable unpinned tab list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(browserState.unpinnedTabs, id: \.id) { tab in
                        let isBeingDragged = activeDrag?.tabId == tab.id

                        TabButton(
                            tab: tab,
                            isSelected: browserState.selectedTabId == tab.id,
                            isDragging: isBeingDragged,
                            isThemeLight: browserState.isThemeLight,
                            activeTabBackgroundColor: activeTabBackgroundColor,
                            namespace: tabAnimationNamespace,
                            sidebarWidth: browserState.sidebarWidth,
                            onSelect: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    browserState.selectTab(tab)
                                }
                            },
                            onClose: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    browserState.removeTab(id: tab.id)
                                }
                            }
                        )
                        .opacity(isBeingDragged ? 0.0 : 1.0)
                        .offset(y: unpinnedShiftOffset(for: tab.id))
                        .contextMenu {
                            Button("Pin") {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    browserState.togglePin(id: tab.id)
                                }
                            }
                            Button("Close", role: .destructive) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    browserState.removeTab(id: tab.id)
                                }
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 3, coordinateSpace: .named("tabstrip"))
                                .onChanged { value in
                                    handleDragChanged(tab: tab, source: .unpinned, value: value)
                                }
                                .onEnded { value in
                                    handleDragEnded(value: value)
                                }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 2)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
        }
        .coordinateSpace(name: "tabstrip")
        .frame(width: isDragCollapsed ? 0 : browserState.sidebarWidth, alignment: .leading)
        .opacity(isDragCollapsed ? 0 : 1)
        .clipped()
        .overlay(alignment: .trailing) {
            resizeHandle
        }
        .overlay(alignment: .topLeading) {
            if let drag = activeDrag {
                FloatingDragTab(
                    tab: drag.tab,
                    isPinnedPreview: drag.isHoveringPinZone,
                    pinnedCardWidth: pinnedCardWidth,
                    sidebarWidth: browserState.sidebarWidth,
                    isThemeLight: browserState.isThemeLight,
                    activeThemeColor: browserState.activeThemeColor
                )
                .position(x: drag.location.x, y: drag.location.y)
                .allowsHitTesting(false)
                .zIndex(999)
            }
        }
        .frame(width: isDragCollapsed ? 0 : browserState.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(WindowDragArea())
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isDragCollapsed)
    }

    // MARK: - Drag Handling

    private func handleDragChanged(tab: TabItem, source: TabDragState.Source, value: DragGesture.Value) {
        let index: Int
        if source == .pinned {
            index = browserState.pinnedTabs.firstIndex(where: { $0.id == tab.id }) ?? 0
        } else {
            index = browserState.unpinnedTabs.firstIndex(where: { $0.id == tab.id }) ?? 0
        }
        handleDragChanged(tab: tab, source: source, index: index, value: value)
    }

    private func handleDragChanged(tab: TabItem, source: TabDragState.Source, index: Int, value: DragGesture.Value) {
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

    private func handleDragEnded(value: DragGesture.Value) {
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

    private func calculatePinnedTargetIndex(location: CGPoint, source: TabDragState.Source) -> Int {
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

    private func calculateUnpinnedTargetIndex(location: CGPoint, source: TabDragState.Source, originalIndex: Int) -> Int {
        let unpinnedStartY = headerHeight + pinnedGridHeight + newTabButtonHeight + 3
        let relativeY = location.y - unpinnedStartY
        let rawIndex = Int((relativeY / rowHeight).rounded())
        let maxIndex = max(0, browserState.unpinnedTabs.count - (source == .unpinned ? 1 : 0))
        return max(0, min(maxIndex, rawIndex))
    }

    private func pinnedShiftOffset(for tabId: UUID) -> CGSize {
        guard let drag = activeDrag, drag.isHoveringPinZone,
              let index = browserState.pinnedTabs.firstIndex(where: { $0.id == tabId }) else {
            return .zero
        }
        return pinnedShiftOffset(for: index)
    }

    private func unpinnedShiftOffset(for tabId: UUID) -> CGFloat {
        guard let drag = activeDrag,
              let index = browserState.unpinnedTabs.firstIndex(where: { $0.id == tabId }) else {
            return 0
        }
        return unpinnedShiftOffset(for: index)
    }

    private func pinnedShiftOffset(for index: Int) -> CGSize {
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

    private func unpinnedShiftOffset(for index: Int) -> CGFloat {
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

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 10)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if dragStartWidth == nil {
                            dragStartWidth = browserState.sidebarWidth
                            browserState.isResizingSidebar = true
                            wasInitiallyVisibleOnDragStart = browserState.isSidebarVisible
                            isSnappedToDefault = abs(browserState.sidebarWidth - defaultWidth) < 1
                            isDragCollapsed = false
                        }
                        let base = dragStartWidth ?? browserState.sidebarWidth
                        let rawWidth = base + value.translation.width

                        // Only auto show/hide collapse when the sidebar was already shown
                        if wasInitiallyVisibleOnDragStart {
                            if rawWidth < collapseThreshold {
                                if !isDragCollapsed {
                                    isDragCollapsed = true
                                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                                    var transaction = Transaction()
                                    transaction.animation = nil
                                    withTransaction(transaction) {
                                        browserState.sidebarWidth = defaultWidth
                                    }
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                        browserState.isSidebarVisible = false
                                    }
                                }
                                return
                            } else {
                                if isDragCollapsed {
                                    isDragCollapsed = false
                                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                        browserState.isSidebarVisible = true
                                    }
                                }
                            }
                        }

                        let clampedWidth = min(max(rawWidth.rounded(), minWidth), maxWidth)
                        let isNearDefault = abs(clampedWidth - defaultWidth) <= snapThreshold
                        let targetWidth = isNearDefault ? defaultWidth : clampedWidth

                        if isNearDefault != isSnappedToDefault {
                            if isNearDefault {
                                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                            }
                            isSnappedToDefault = isNearDefault
                        }

                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            browserState.sidebarWidth = targetWidth
                        }
                    }
                    .onEnded { value in
                        if wasInitiallyVisibleOnDragStart {
                            if isDragCollapsed {
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    browserState.sidebarWidth = defaultWidth
                                }
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                    browserState.isSidebarVisible = false
                                }
                            } else {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                    browserState.isSidebarVisible = true
                                }
                            }
                        }
                        dragStartWidth = nil
                        isDragCollapsed = false
                        wasInitiallyVisibleOnDragStart = false
                        isSnappedToDefault = false
                        browserState.isResizingSidebar = false
                    }
            )
    }
}

// MARK: - Preview

#Preview {
    Tabstrip(browserState: BrowserState())
        .frame(height: 500)
}
