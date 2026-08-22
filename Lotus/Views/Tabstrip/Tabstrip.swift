//
//  Tabstrip.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI

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
    let rowHeight: CGFloat = 35 // 32pt tab + 3pt spacing
    let pinnedRowHeight: CGFloat = 46 // 38pt card + 8pt spacing
    let newTabButtonHeight: CGFloat = 35

    @State var isSnappedToDefault: Bool = false
    @State var isDragCollapsed: Bool = false
    @State var wasInitiallyVisibleOnDragStart: Bool = false

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
}

// MARK: - Preview

#Preview {
    Tabstrip(browserState: BrowserState())
        .frame(height: 500)
}
