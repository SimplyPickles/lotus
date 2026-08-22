//
//  TabButton.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI

struct TabButton: View {
    let tab: TabItem
    let isSelected: Bool
    var isDragging: Bool = false
    var isThemeLight: Bool = false
    var activeTabBackgroundColor: Color = Color(nsColor: .windowBackgroundColor)
    var namespace: Namespace.ID? = nil
    let sidebarWidth: CGFloat
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var isInternalPage: Bool {
        tab.url?.scheme == "lotus" || tab.url?.absoluteString.hasPrefix("lotus://") == true
    }

    /// The sidebar sits on a translucent vibrancy background.
    /// In dark mode text is white; in light mode text is dark.
    private var sidebarForeground: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var sidebarForegroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.60) : Color(nsColor: .secondaryLabelColor)
    }

    private var foregroundPrimary: Color {
        if isSelected && isThemeLight && !isInternalPage {
            return .black
        }
        if isSelected && !isInternalPage {
            return .white
        }
        return sidebarForeground
    }

    private var foregroundSecondary: Color {
        if isSelected && isThemeLight && !isInternalPage {
            return .black.opacity(0.60)
        }
        if isSelected && !isInternalPage {
            return .white.opacity(0.60)
        }
        return sidebarForegroundSecondary
    }

    var body: some View {
        HStack(spacing: 8) {
            faviconView
                .frame(width: 16, height: 16, alignment: .center)

            Text(tab.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(foregroundPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(foregroundSecondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
        }
        .padding(.horizontal, 8)
        .frame(width: max(0, sidebarWidth - 16), height: 34, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    .opacity(!isSelected && isHovered ? 1 : 0)

                if isSelected {
                    if let namespace = namespace, !isDragging {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(activeTabBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "activeTabHighlight", in: namespace)
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(activeTabBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
                            )
                    }
                }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .focusable(false)
        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
    }

    @ViewBuilder
    private var faviconView: some View {
        ZStack {
            if isInternalPage {
                Image(systemName: "camera.macro")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(foregroundPrimary.opacity(0.85))
                    .frame(width: 16, height: 16, alignment: .center)
            } else if let faviconURL = tab.faviconURL {
                CachedFaviconView(
                    url: faviconURL,
                    defaultSystemName: "camera.macro",
                    fallbackColor: foregroundSecondary,
                    size: 14
                )
                .frame(width: 16, height: 16, alignment: .center)
            } else {
                defaultGlyph
            }
        }
        .frame(width: 16, height: 16, alignment: .center)
    }

    private var defaultGlyph: some View {
        Image(systemName: "camera.macro")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(foregroundSecondary)
            .frame(width: 16, height: 16, alignment: .center)
    }
}
