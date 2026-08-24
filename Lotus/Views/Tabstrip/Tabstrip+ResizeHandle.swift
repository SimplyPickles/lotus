//
//  Tabstrip+ResizeHandle.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

// MARK: - Resize Handle

extension Tabstrip {
    var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 12)
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
