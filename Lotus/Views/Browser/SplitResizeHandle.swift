//
//  SplitResizeHandle.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import AppKit

/// An invisible vertical resize handle situated between side-by-side split view panes.
/// Supports continuous dragging to adjust split proportions, cursor change on hover,
/// 50% snap with haptic feedback, and double-click to reset.
struct SplitResizeHandle: View {
    @ObservedObject var browserState: BrowserState
    let group: [UUID]
    let availableWidth: CGFloat
    let minWidth: CGFloat
    let spacing: CGFloat

    @State private var isHovered: Bool = false
    @State private var dragStartRatio: CGFloat? = nil
    @State private var isSnappedToCenter: Bool = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: max(12, spacing))
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    if !isHovered {
                        isHovered = true
                        NSCursor.resizeLeftRight.push()
                    }
                } else {
                    if isHovered {
                        isHovered = false
                        NSCursor.pop()
                    }
                }
            }
            .onDisappear {
                if isHovered {
                    isHovered = false
                    NSCursor.pop()
                }
            }
            .onTapGesture(count: 2) {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                    browserState.setSplitRatio(0.5, for: group, save: true)
                }
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        guard availableWidth > 0 else { return }

                        if dragStartRatio == nil {
                            dragStartRatio = browserState.splitRatio(for: group)
                            browserState.isResizingSplit = true
                            isSnappedToCenter = abs(browserState.splitRatio(for: group) - 0.5) < 0.005
                        }

                        let startRatio = dragStartRatio ?? 0.5
                        let startLeftWidth = availableWidth * startRatio
                        let rawLeftWidth = startLeftWidth + value.translation.width
                        let rawRatio = rawLeftWidth / availableWidth

                        let minRatio = minWidth / availableWidth
                        let maxRatio = 1.0 - minRatio
                        let clampedRatio = min(max(rawRatio, minRatio), maxRatio)

                        // Magnetic anchor points: 50% (strong primary snap), 33.3% (1/3), 66.7% (2/3), 25% (1/4), 75% (3/4)
                        let primarySnapRadius: CGFloat = 28.0 / availableWidth
                        let secondarySnapRadius: CGFloat = 20.0 / availableWidth

                        var snappedRatio: CGFloat = clampedRatio
                        var currentlySnappedToCenter = false

                        if abs(clampedRatio - 0.5) <= primarySnapRadius {
                            let diff = clampedRatio - 0.5
                            let pullFactor = abs(diff) / primarySnapRadius
                            // Quadratic magnetic pull easing toward exact center
                            if pullFactor < 0.65 {
                                snappedRatio = 0.5
                            } else {
                                snappedRatio = 0.5 + diff * (pullFactor * pullFactor)
                            }
                            currentlySnappedToCenter = true
                        } else if abs(clampedRatio - 0.3333) <= secondarySnapRadius {
                            snappedRatio = 0.3333
                        } else if abs(clampedRatio - 0.6667) <= secondarySnapRadius {
                            snappedRatio = 0.6667
                        }

                        let isNearCenter = currentlySnappedToCenter
                        if isNearCenter != isSnappedToCenter {
                            if isNearCenter {
                                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                            }
                            isSnappedToCenter = isNearCenter
                        }

                        browserState.setSplitRatio(snappedRatio, for: group, save: false)
                    }
                    .onEnded { _ in
                        dragStartRatio = nil
                        isSnappedToCenter = false
                        browserState.isResizingSplit = false
                        browserState.saveSession()
                    }
            )
    }
}
