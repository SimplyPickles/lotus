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
    var isMultiSelected: Bool = false
    var isSplitMember: Bool = false
    var isDragging: Bool = false
    var isDraggingAnyTab: Bool = false
    var isThemeLight: Bool = false
    var activeTabBackgroundColor: Color = Color(nsColor: .windowBackgroundColor)
    var namespace: Namespace.ID? = nil
    let sidebarWidth: CGFloat
    var customWidth: CGFloat? = nil
    var isSplit: Bool = false
    var isRenaming: Bool = false
    var onCommitRename: (String) -> Void = { _ in }
    var onCancelRename: () -> Void = {}
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered: Bool = false
    @State private var draftTitle: String = ""
    @FocusState private var isTitleFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var effectiveHovered: Bool {
        isHovered && !isDraggingAnyTab
    }

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

    private var isHighlighted: Bool {
        isSelected || isSplitMember
    }

    private var foregroundPrimary: Color {
        sidebarForeground
    }

    private var foregroundSecondary: Color {
        sidebarForegroundSecondary
    }

    private var selectedForegroundPrimary: Color {
        if isThemeLight && !isInternalPage {
            return .black
        }
        if !isInternalPage {
            return .white
        }
        return sidebarForeground
    }

    private var selectedForegroundSecondary: Color {
        if isThemeLight && !isInternalPage {
            return .black.opacity(0.60)
        }
        if !isInternalPage {
            return .white.opacity(0.60)
        }
        return sidebarForegroundSecondary
    }

    var body: some View {
        let targetWidth = customWidth ?? max(0, sidebarWidth - 16)

        HStack(spacing: isSplit ? 6 : 8) {
            faviconView
                .frame(width: 16, height: 16, alignment: .center)

            if isRenaming {
                TextField("Tab Title", text: $draftTitle)
                    .font(.system(size: isSplit ? 12 : 13, weight: .medium))
                    .foregroundColor(isSelected ? selectedForegroundPrimary : sidebarForeground)
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .onSubmit {
                        onCommitRename(draftTitle)
                    }
                    .onKeyPress(.escape) {
                        onCancelRename()
                        return .handled
                    }
            } else {
                ZStack(alignment: .leading) {
                    Text(tab.title)
                        .font(.system(size: isSplit ? 12 : 13, weight: .medium))
                        .foregroundColor(sidebarForeground)
                        .lineLimit(1)
                        .opacity(isSelected ? 0 : 1)

                    Text(tab.title)
                        .font(.system(size: isSplit ? 12 : 13, weight: .medium))
                        .foregroundColor(selectedForegroundPrimary)
                        .lineLimit(1)
                        .opacity(isSelected ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.16), value: isSelected)
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                ZStack {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(sidebarForegroundSecondary)
                        .opacity(isSelected ? 0 : 1)

                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(selectedForegroundSecondary)
                        .opacity(isSelected ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.16), value: isSelected)
                .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(effectiveHovered && !isRenaming ? 1 : 0)
            .allowsHitTesting(effectiveHovered && !isRenaming)
        }
        .padding(.horizontal, isSplit ? 6 : 8)
        .frame(width: targetWidth, height: 34, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    .opacity(!isHighlighted && effectiveHovered ? 1 : 0)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.04))
                    .opacity(isMultiSelected ? 1 : 0)

                if isSelected {
                    if let namespace = namespace {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(activeTabBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
                            )
                            .frame(width: targetWidth, height: 34)
                            .zIndex(10)
                            .matchedGeometryEffect(id: "activeTabHighlight", in: namespace)
                            .animation(.easeInOut(duration: 0.22), value: activeTabBackgroundColor)
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(activeTabBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
                            )
                            .frame(width: targetWidth, height: 34)
                            .zIndex(10)
                            .animation(.easeInOut(duration: 0.22), value: activeTabBackgroundColor)
                    }
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.09), lineWidth: 1)
                .opacity(isMultiSelected ? 1 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture {
            if !isRenaming {
                onSelect()
            }
        }
        .onHover { hovering in
            guard !isDraggingAnyTab else {
                isHovered = false
                return
            }
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .onChange(of: isRenaming) { _, renaming in
            if renaming {
                draftTitle = tab.title
                isTitleFocused = true
                DispatchQueue.main.async {
                    isTitleFocused = true
                }
            }
        }
        .focusable(false)
        .transition(
            .asymmetric(
                insertion: .opacity
                    .combined(with: .scale(scale: 0.97))
                    .animation(.easeOut(duration: 0.12)),
                removal: .opacity
                    .combined(with: .scale(scale: 0.97))
                    .animation(.easeIn(duration: 0.10))
            )
        )
    }

    @ViewBuilder
    private var faviconView: some View {
        ZStack {
            if isInternalPage {
                Image(systemName: tab.url?.host == "history" ? "clock" : (tab.url?.host == "downloads" ? "arrow.down.circle" : (tab.url?.host == "settings" ? "gearshape" : "camera.macro")))
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
        .contentTransition(.identity)
    }

    private var defaultGlyph: some View {
        Image(systemName: "camera.macro")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(foregroundSecondary)
            .frame(width: 16, height: 16, alignment: .center)
            .contentTransition(.identity)
    }
}
