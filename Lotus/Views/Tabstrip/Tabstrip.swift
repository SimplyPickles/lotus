//
//  Tabstrip.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import AppKit

struct Tabstrip: View {
    @ObservedObject var browserState: BrowserState
    @State var dragStartWidth: CGFloat? = nil
    @State var activeDrag: TabDragState? = nil
    @Namespace private var tabAnimationNamespace

    let minWidth: CGFloat = 150
    let maxWidth: CGFloat = 600
    let defaultWidth: CGFloat = 240
    let snapThreshold: CGFloat = 8
    let collapseThreshold: CGFloat = 130
    let headerHeight: CGFloat = 50
    let rowHeight: CGFloat = 37 // 34pt tab + 3pt spacing
    let pinnedRowHeight: CGFloat = 46 // 38pt card + 8pt spacing
    let newTabButtonHeight: CGFloat = 36

    @State var isSnappedToDefault: Bool = false
    @State var isDragCollapsed: Bool = false
    @State var wasInitiallyVisibleOnDragStart: Bool = false
    @State private var renamingFolderId: UUID? = nil
    @State private var renamingTabId: UUID? = nil
    @State var unpinnedScrollOffset: CGFloat = 0

    private let tabSelectionAnimation = Animation.spring(
        response: 0.20,
        dampingFraction: 0.86,
        blendDuration: 0.02
    )

    private var highlightedTabId: UUID {
        browserState.selectedTabId
    }

    private var highlightedCurrentTabIds: [UUID] {
        browserState.splitGroup(containing: browserState.selectedTabId) ?? [browserState.selectedTabId]
    }

    private var isPinnedTabSelected: Bool {
        browserState.activeTab?.isPinned == true
    }

    private var hasMultipleSelectedTabs: Bool {
        let selectedIds = browserState.selectedSidebarTabIds
        return browserState.visibleSidebarUnits.filter { unit in
            unit.tabIds.contains(where: selectedIds.contains)
        }.count > 1
    }

    private var activeTabBackgroundColor: Color {
        let isInternal = browserState.activeURL?.scheme == "lotus" || browserState.activeURL?.absoluteString.hasPrefix("lotus://") == true
        if isInternal {
            return Color(nsColor: .windowBackgroundColor)
        }
        return browserState.activeThemeColor ?? Color(nsColor: .windowBackgroundColor)
    }

    /// Pinned-grid footprint after removing the drag payload from its source
    /// and, when applicable, reserving all of its destination slots.
    private var effectivePinnedCount: Int {
        guard let drag = activeDrag, drag.folder == nil else {
            return browserState.pinnedTabs.count
        }
        let draggedPinnedCount = browserState.pinnedTabs.filter { drag.draggedTabIds.contains($0.id) }.count
        let remainingCount = browserState.pinnedTabs.count - draggedPinnedCount
        if drag.isHoveringPinZone && drag.canPinPayload {
            return remainingCount + drag.draggedTabIds.count
        }
        return remainingCount
    }

    /// Dynamic column count: up to 4 tabs sit in a single row; 5+ wraps to 3 columns.
    var pinnedColumnCount: Int {
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

    var pinnedGridHeight: CGFloat {
        let count = effectivePinnedCount
        if count == 0 { return 0 }
        let cols = count <= 4 ? count : 3
        let rows = (count + cols - 1) / cols
        return CGFloat(rows) * 38 + CGFloat(max(0, rows - 1)) * 8 + 10
    }

    enum UnpinnedTabRow: Identifiable {
        case single(TabItem)
        case split(TabItem, TabItem)
        case folderHeader(TabFolder)

        var id: String {
            switch self {
            case .single(let tab):
                return tab.id.uuidString
            case .split(let t1, let t2):
                return "\(t1.id.uuidString)_\(t2.id.uuidString)"
            case .folderHeader(let folder):
                return "folder_\(folder.id.uuidString)"
            }
        }

        func contains(_ tabId: UUID) -> Bool {
            switch self {
            case .single(let tab):
                return tab.id == tabId
            case .split(let t1, let t2):
                return t1.id == tabId || t2.id == tabId
            case .folderHeader:
                return false
            }
        }

        func containsAny(_ tabIds: Set<UUID>) -> Bool {
            switch self {
            case .single(let tab):
                return tabIds.contains(tab.id)
            case .split(let first, let second):
                return tabIds.contains(first.id) || tabIds.contains(second.id)
            case .folderHeader:
                return false
            }
        }

        /// Folder membership of the row's tabs (nil for headers/loose rows).
        var memberFolderId: UUID? {
            switch self {
            case .single(let tab): return tab.folderId
            case .split(let t1, _): return t1.folderId
            case .folderHeader: return nil
            }
        }
    }

    var unpinnedRows: [UnpinnedTabRow] {
        let unpinned = browserState.unpinnedTabs
        var rows: [UnpinnedTabRow] = []
        var archiveRows: [UnpinnedTabRow] = []
        var handledIds = Set<UUID>()
        var emittedFolders = Set<UUID>()

        let archiveFolder = browserState.folders.first(where: { $0.isArchive })
        let archiveFolderId = archiveFolder?.id

        for tab in unpinned {
            if handledIds.contains(tab.id) {
                continue
            }

            // If tab belongs to archive folder, route to archiveRows
            if let folderId = tab.folderId, folderId == archiveFolderId, let folder = archiveFolder {
                var isCollapsed = folder.isCollapsed
                if emittedFolders.insert(folderId).inserted {
                    archiveRows.append(.folderHeader(folder))
                }
                handledIds.insert(tab.id)
                if !isCollapsed {
                    archiveRows.append(.single(tab))
                }
                continue
            }

            // Folder header renders at its first member's position; members
            // of a collapsed folder are hidden. Drag previews collapse member
            // rows only at the view layer, so the complete block stays here.
            var isCollapsed = false
            if let folderId = tab.folderId, let folder = browserState.folder(for: folderId) {
                if emittedFolders.insert(folderId).inserted {
                    rows.append(.folderHeader(folder))
                }
                isCollapsed = folder.isCollapsed
            }

            if let group = browserState.splitGroup(containing: tab.id),
               group.count == 2,
               let partnerId = group.first(where: { $0 != tab.id }),
               let partnerTab = unpinned.first(where: { $0.id == partnerId }) {
                handledIds.insert(tab.id)
                handledIds.insert(partnerId)
                if !isCollapsed {
                    let firstTab = group[0] == tab.id ? tab : partnerTab
                    let secondTab = group[0] == tab.id ? partnerTab : tab
                    rows.append(.split(firstTab, secondTab))
                }
            } else {
                handledIds.insert(tab.id)
                if !isCollapsed {
                    rows.append(.single(tab))
                }
            }
        }

        // Folders with no member tabs still render so they can receive drops and be managed.
        for folder in browserState.folders where !emittedFolders.contains(folder.id) {
            if folder.isArchive {
                archiveRows.append(.folderHeader(folder))
            } else {
                rows.append(.folderHeader(folder))
            }
        }

        return rows + archiveRows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed top section for traffic light clearance
            WindowDragArea()
                .frame(width: browserState.sidebarWidth, height: headerHeight, alignment: .leading)

            // Pinned Tabs Grid / Drop Zone
            VStack(spacing: 0) {
                if pinnedGridHeight > 0 {
                    LazyVGrid(columns: pinnedGridColumns, spacing: 8) {
                        ForEach(browserState.pinnedTabs, id: \.id) { tab in
                            let isBeingDragged = activeDrag?.draggedTabIds.contains(tab.id) == true

                            ZStack {
                                PinnedTabButton(
                                    tab: tab,
                                    isSelected: highlightedTabId == tab.id,
                                    isMultiSelected: hasMultipleSelectedTabs && browserState.selectedSidebarTabIds.contains(tab.id),
                                    isInSplit: browserState.currentTabIds.contains(tab.id),
                                    isDraggingAnyTab: activeDrag != nil,
                                    namespace: tabAnimationNamespace,
                                    isRenaming: renamingTabId == tab.id,
                                    isPlayingAudio: browserState.tabMediaStates[tab.id]?.isPlayingAudio ?? false,
                                    isMuted: browserState.tabMediaStates[tab.id]?.isMuted ?? false,
                                    onToggleMute: {
                                        browserState.toggleMuteTab(id: tab.id)
                                    },
                                    onCommitRename: { title in
                                        browserState.renameTab(id: tab.id, to: title)
                                        renamingTabId = nil
                                    },
                                    onCancelRename: {
                                        renamingTabId = nil
                                    },
                                    onSelect: {
                                        withAnimation(tabSelectionAnimation) {
                                            browserState.selectSidebarTab(
                                                tab.id,
                                                extendingRange: NSEvent.modifierFlags.contains(.shift)
                                            )
                                        }
                                    }
                                )
                                .opacity(isBeingDragged ? 0.0 : 1.0)
                                .offset(pinnedShiftOffset(for: tab.id))
                                .zIndex(highlightedTabId == tab.id ? 10 : 0)
                                .animation(activeDrag == nil ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: pinnedShiftOffset(for: tab.id))
                            }
                            .contextMenu {
                                tabContextMenu(for: tab)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 3, coordinateSpace: .named("lotusWindow"))
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
            .frame(width: browserState.sidebarWidth, height: pinnedGridHeight, alignment: .topLeading)
            .clipped()
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: pinnedGridHeight)

            // New Tab button
            NewTabButton {
                browserState.openCommandPalette()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 1)
            .frame(width: browserState.sidebarWidth, alignment: .leading)

            // Scrollable unpinned tab list
            ScrollView(.vertical, showsIndicators: false) {
                let rows = unpinnedRows
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, row in
                        switch row {
                        case .folderHeader(let folder):
                            FolderRow(
                                folder: folder,
                                isRenaming: renamingFolderId == folder.id,
                                onToggleCollapse: {
                                    browserState.clearSidebarSelection()
                                    browserState.toggleFolderCollapsed(id: folder.id)
                                },
                                onCommitRename: { name in
                                    browserState.renameFolder(id: folder.id, to: name)
                                    renamingFolderId = nil
                                },
                                onCancelRename: {
                                    renamingFolderId = nil
                                },
                                onClose: {
                                    browserState.requestCloseFolder(id: folder.id)
                                }
                            )
                            .opacity(activeDrag?.folder?.id == folder.id ? 0.0 : 1.0)
                            .padding(.bottom, 3)
                            .offset(y: unpinnedShiftOffset(forRowIndex: rowIndex, in: rows))
                            .animation(activeDrag == nil ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: unpinnedShiftOffset(forRowIndex: rowIndex, in: rows))
                            .overlay(
                                FolderContextMenuHost(
                                    folder: folder,
                                    browserState: browserState,
                                    onRename: { renamingFolderId = folder.id },
                                    onClose: { browserState.requestCloseFolder(id: folder.id) },
                                    onDelete: { browserState.deleteFolder(id: folder.id) }
                                )
                            )
                            .gesture(
                                DragGesture(minimumDistance: 3, coordinateSpace: .named("lotusWindow"))
                                    .onChanged { value in
                                        handleFolderDragChanged(folder: folder, rowIndex: rowIndex, value: value)
                                    }
                                    .onEnded { value in
                                        handleDragEnded(value: value)
                                    }
                            )

                        case .single(let tab):
                            let isBeingDragged = activeDrag?.draggedTabIds.contains(tab.id) == true
                            let isDraggedFolderMember = activeDrag?.folder != nil && activeDrag?.folder?.id == tab.folderId

                            TabButton(
                                tab: tab,
                                isSelected: highlightedTabId == tab.id,
                                isMultiSelected: hasMultipleSelectedTabs && browserState.selectedSidebarTabIds.contains(tab.id),
                                isDragging: isBeingDragged,
                                isDraggingAnyTab: activeDrag != nil,
                                isThemeLight: browserState.isThemeLight(for: tab.id),
                                activeTabBackgroundColor: activeTabBackgroundColor,
                                namespace: tabAnimationNamespace,
                                // Foldered tabs render narrower so their right
                                // edge stays aligned while indented.
                                sidebarWidth: browserState.sidebarWidth - (tab.folderId != nil ? 14 : 0),
                                isRenaming: renamingTabId == tab.id,
                                isPlayingAudio: browserState.tabMediaStates[tab.id]?.isPlayingAudio ?? false,
                                isMuted: browserState.tabMediaStates[tab.id]?.isMuted ?? false,
                                onToggleMute: {
                                    browserState.toggleMuteTab(id: tab.id)
                                },
                                onCommitRename: { title in
                                    browserState.renameTab(id: tab.id, to: title)
                                    renamingTabId = nil
                                },
                                onCancelRename: {
                                    renamingTabId = nil
                                },
                                onSelect: {
                                    withAnimation(tabSelectionAnimation) {
                                        browserState.selectSidebarTab(
                                            tab.id,
                                            extendingRange: NSEvent.modifierFlags.contains(.shift)
                                        )
                                    }
                                },
                                onClose: {
                                    browserState.removeTab(id: tab.id)
                                }
                            )
                            .padding(.leading, tab.folderId != nil ? 14 : 0)
                            .opacity(isBeingDragged || isDraggedFolderMember ? 0.0 : 1.0)
                            .frame(height: isDraggedFolderMember ? 0 : nil)
                            .padding(.bottom, isDraggedFolderMember ? 0 : 3)
                            .offset(y: unpinnedShiftOffset(forRowIndex: rowIndex, in: rows))
                            .zIndex(highlightedTabId == tab.id ? 10 : 0)
                            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isDraggedFolderMember)
                            .animation(activeDrag == nil ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: unpinnedShiftOffset(forRowIndex: rowIndex, in: rows))
                            .contextMenu {
                                tabContextMenu(for: tab)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 3, coordinateSpace: .named("lotusWindow"))
                                    .onChanged { value in
                                        handleDragChanged(tab: tab, source: .unpinned, rowIndex: rowIndex, value: value)
                                    }
                                    .onEnded { value in
                                        handleDragEnded(value: value)
                                    }
                            )

                        case .split(let tab1, let tab2):
                            let isBeingDragged = activeDrag?.draggedTabIds.contains(tab1.id) == true || activeDrag?.draggedTabIds.contains(tab2.id) == true
                            let isDraggedFolderMember = activeDrag?.folder != nil && (activeDrag?.folder?.id == tab1.folderId || activeDrag?.folder?.id == tab2.folderId)

                            SplitTabRow(
                                tab1: tab1,
                                tab2: tab2,
                                selectedTabId: highlightedTabId,
                                currentTabIds: highlightedCurrentTabIds,
                                sidebarWidth: browserState.sidebarWidth - (tab1.folderId != nil ? 14 : 0),
                                isMultiSelected: hasMultipleSelectedTabs && (browserState.selectedSidebarTabIds.contains(tab1.id) || browserState.selectedSidebarTabIds.contains(tab2.id)),
                                isThemeLight: browserState.isThemeLight(for: highlightedTabId),
                                isPlayingAudio1: browserState.tabMediaStates[tab1.id]?.isPlayingAudio ?? false,
                                isMuted1: browserState.tabMediaStates[tab1.id]?.isMuted ?? false,
                                isPlayingAudio2: browserState.tabMediaStates[tab2.id]?.isPlayingAudio ?? false,
                                isMuted2: browserState.tabMediaStates[tab2.id]?.isMuted ?? false,
                                onToggleMute: { tab in
                                    browserState.toggleMuteTab(id: tab.id)
                                },
                                activeTabBackgroundColor: activeTabBackgroundColor,
                                namespace: tabAnimationNamespace,
                                activeDrag: activeDrag,
                                isDraggingAnyTab: activeDrag != nil,
                                onSelect: { tab in
                                    withAnimation(tabSelectionAnimation) {
                                        browserState.selectSidebarTab(
                                            tab.id,
                                            extendingRange: NSEvent.modifierFlags.contains(.shift)
                                        )
                                    }
                                },
                                onClose: { tab in
                                    browserState.removeTab(id: tab.id)
                                },
                                onDragChanged: { tab, value in
                                    handleDragChanged(tab: tab, source: .unpinned, rowIndex: rowIndex, value: value)
                                },
                                onDragEnded: { value in
                                    handleDragEnded(value: value)
                                },
                                contextMenuBuilder: { tab in
                                    AnyView(tabContextMenu(for: tab))
                                }
                            )
                            .padding(.leading, tab1.folderId != nil ? 14 : 0)
                            .opacity(isBeingDragged || isDraggedFolderMember ? 0.0 : 1.0)
                            .frame(height: isDraggedFolderMember ? 0 : nil)
                            .padding(.bottom, isDraggedFolderMember ? 0 : 3)
                            .offset(y: unpinnedShiftOffset(forRowIndex: rowIndex, in: rows))
                            .zIndex(highlightedCurrentTabIds.contains(tab1.id) || highlightedCurrentTabIds.contains(tab2.id) ? 10 : 0)
                            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isDraggedFolderMember)
                            .animation(activeDrag == nil ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: unpinnedShiftOffset(forRowIndex: rowIndex, in: rows))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .frame(width: browserState.sidebarWidth, alignment: .topLeading)
            }
            .frame(width: browserState.sidebarWidth, alignment: .leading)
            .scrollBounceBehavior(.basedOnSize)
            .scrollContentBackground(.hidden)
            .onScrollGeometryChange(
                for: CGFloat.self,
                of: { geometry in geometry.contentOffset.y },
                action: { _, offset in
                    unpinnedScrollOffset = max(0, offset)
                }
            )
        }
        .frame(width: isDragCollapsed ? 0 : browserState.sidebarWidth, alignment: .leading)
        .opacity(isDragCollapsed ? 0 : 1)
        .clipped()
        .overlay(alignment: .trailing) {
            resizeHandle
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(WindowDragArea())
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isDragCollapsed)
    }

    @ViewBuilder
    private func tabContextMenu(for tab: TabItem) -> some View {
        let isMulti = browserState.selectedSidebarTabIds.contains(tab.id) && browserState.selectedSidebarTabIds.count > 1
        let closeTargetIds: [UUID] = isMulti
            ? browserState.tabs.filter { browserState.selectedSidebarTabIds.contains($0.id) }.map(\.id)
            : [tab.id]
        let folderTargetIds = closeTargetIds.filter { id in
            browserState.tab(for: id)?.isPinned == false
        }

        if !isMulti {
            Button("Duplicate Tab") {
                browserState.duplicateTab(id: tab.id)
            }

            Button("Reload Tab") {
                browserState.reload(for: tab.id)
            }

            Button(tab.isMuted ? "Unmute Tab" : "Mute Tab") {
                browserState.toggleMuteTab(id: tab.id)
            }

            if tab.url != nil {
                Button("Copy Tab URL") {
                    browserState.copyTabURL(id: tab.id)
                }
            }

            Button("Move Tab to New Window") {
                browserState.moveTabToNewWindow(id: tab.id)
            }

            if !tab.isPinned && tab.id != browserState.selectedTabId && !browserState.currentTabIds.contains(tab.id) && tab.url?.isLotusPage == false {
                if tab.isSnoozed {
                    Button("Wake Tab") {
                        browserState.wakeTab(id: tab.id)
                    }
                } else {
                    Button("Snooze Tab (Free Memory)") {
                        browserState.snoozeTab(id: tab.id)
                    }
                }
            }

            Divider()
        }

        if browserState.isSplit(id: tab.id) {
            Button("Separate Views") {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                    browserState.closeSplit(id: tab.id)
                }
            }
        } else {
            if !isMulti && browserState.canOpenInSplit(id: tab.id) {
                Button("Split View with Current Tab") {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        browserState.openInSplit(id: tab.id)
                    }
                }
            }

            if !isMulti {
                Button("Rename…") {
                    renamingTabId = tab.id
                }

                Button(tab.isPinned ? "Unpin" : "Pin") {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        browserState.togglePin(id: tab.id)
                    }
                }
            }
        }

        if !tab.isPinned {
            Divider()

            let count = folderTargetIds.count
            let moveTitle = count > 1 ? "Move \(count) Tabs to Folder" : "Move to Folder"
            let newFolderTitle = count > 1 ? "New Folder with \(count) Tabs" : "New Folder with Tab"
            let removeTitle = count > 1 ? "Remove \(count) Tabs from Folder" : "Remove from Folder"

            Menu(moveTitle) {
                Button(newFolderTitle) {
                    browserState.createFolder(with: folderTargetIds)
                }

                if !browserState.folders.isEmpty {
                    Divider()
                }
                
                ForEach(browserState.folders) { folder in
                    Button(folder.name) {
                        browserState.moveTabs(folderTargetIds, toFolder: folder.id)
                    }
                    .disabled(folderTargetIds.allSatisfy { browserState.tab(for: $0)?.folderId == folder.id })
                }
            }

            if folderTargetIds.contains(where: { browserState.tab(for: $0)?.folderId != nil }) {
                Button(removeTitle) {
                    browserState.moveTabs(folderTargetIds, toFolder: nil)
                }
            }

            if !isMulti {
                Divider()

                Button("Close Other Tabs") {
                    browserState.closeOtherTabs(id: tab.id)
                }

                Button("Close Tabs Below") {
                    browserState.closeTabsBelow(id: tab.id)
                }
            }
        }

        let closeTitle = isMulti && closeTargetIds.count > 1 ? "Close \(closeTargetIds.count) Tabs" : "Close"
        Button(closeTitle, role: .destructive) {
            for id in closeTargetIds {
                browserState.removeTab(id: id)
            }
        }
    }
}

