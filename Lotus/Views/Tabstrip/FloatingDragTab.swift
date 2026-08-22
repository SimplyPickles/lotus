//
//  FloatingDragTab.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

struct FloatingDragTab: View {
    let tab: TabItem
    let isPinnedPreview: Bool
    let pinnedCardWidth: CGFloat
    let sidebarWidth: CGFloat
    let isThemeLight: Bool
    let activeThemeColor: Color?

    private var activeTabBackgroundColor: Color {
        let isInternal = tab.url?.scheme == "lotus" || tab.url?.absoluteString.hasPrefix("lotus://") == true
        if isInternal {
            return Color(nsColor: .windowBackgroundColor)
        }
        return activeThemeColor ?? Color(nsColor: .windowBackgroundColor)
    }

    var body: some View {
        Group {
            if isPinnedPreview {
                PinnedTabButton(
                    tab: tab,
                    isSelected: true,
                    onSelect: {}
                )
                .frame(width: pinnedCardWidth)
            } else {
                TabButton(
                    tab: tab,
                    isSelected: true,
                    isDragging: true,
                    isThemeLight: isThemeLight,
                    activeTabBackgroundColor: activeTabBackgroundColor,
                    sidebarWidth: sidebarWidth,
                    onSelect: {},
                    onClose: {}
                )
                .frame(width: max(60, sidebarWidth - 16))
            }
        }
        .scaleEffect(isPinnedPreview ? 1.05 : 1.02)
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isPinnedPreview)
    }
}
