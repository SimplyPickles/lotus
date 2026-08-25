//
//  SplitTabRow.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct SplitTabRow: View {
    let tab1: TabItem
    let tab2: TabItem
    let selectedTabId: UUID
    let currentTabIds: [UUID]
    let sidebarWidth: CGFloat
    var isMultiSelected: Bool = false
    var isThemeLight: Bool = false
    var isThemeLight1: Bool = false
    var isThemeLight2: Bool = false
    var isPlayingAudio1: Bool = false
    var isMuted1: Bool = false
    var isPlayingAudio2: Bool = false
    var isMuted2: Bool = false
    var onToggleMute: (TabItem) -> Void = { _ in }
    let activeTabBackgroundColor: Color
    var namespace: Namespace.ID? = nil
    var activeDrag: TabDragState? = nil
    var isDraggingAnyTab: Bool = false
    let onSelect: (TabItem) -> Void
    let onClose: (TabItem) -> Void
    let onDragChanged: (TabItem, DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void
    let contextMenuBuilder: (TabItem) -> AnyView

    @Environment(\.colorScheme) private var colorScheme

    private var isSplitActive: Bool {
        currentTabIds.contains(tab1.id) || currentTabIds.contains(tab2.id)
    }

    private var isBeingDragged: Bool {
        activeDrag?.tabId == tab1.id || activeDrag?.tabId == tab2.id
    }

    var body: some View {
        let totalWidth = max(0, sidebarWidth - 16)
        let halfWidth = max(0, totalWidth / 2)

        HStack(spacing: 0) {
            SplitTabHalf(
                tab: tab1,
                isFocused: selectedTabId == tab1.id,
                isSplitActive: isSplitActive,
                isDraggingAnyTab: isDraggingAnyTab || activeDrag != nil,
                isThemeLight: isThemeLight,
                isPlayingAudio: isPlayingAudio1,
                isMuted: isMuted1,
                onToggleMute: { onToggleMute(tab1) },
                onSelect: { onSelect(tab1) },
                onClose: { onClose(tab1) }
            )
            .frame(width: halfWidth, height: 34)
            .contextMenu {
                contextMenuBuilder(tab1)
            }
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("lotusWindow"))
                    .onChanged { value in onDragChanged(tab1, value) }
                    .onEnded { value in onDragEnded(value) }
            )

            SplitTabHalf(
                tab: tab2,
                isFocused: selectedTabId == tab2.id,
                isSplitActive: isSplitActive,
                isDraggingAnyTab: isDraggingAnyTab || activeDrag != nil,
                isThemeLight: isThemeLight,
                isPlayingAudio: isPlayingAudio2,
                isMuted: isMuted2,
                onToggleMute: { onToggleMute(tab2) },
                onSelect: { onSelect(tab2) },
                onClose: { onClose(tab2) }
            )
            .frame(width: halfWidth, height: 34)
            .contextMenu {
                contextMenuBuilder(tab2)
            }
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("lotusWindow"))
                    .onChanged { value in onDragChanged(tab2, value) }
                    .onEnded { value in onDragEnded(value) }
            )
        }
        .frame(width: totalWidth, height: 34)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.04))
                    .opacity(isMultiSelected ? 1 : 0)

                if isSplitActive {
                    if let namespace = namespace {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(activeTabBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
                            )
                            .frame(width: totalWidth, height: 34)
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
                            .frame(width: totalWidth, height: 34)
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
    }
}

private struct SplitTabHalf: View {
    let tab: TabItem
    let isFocused: Bool
    let isSplitActive: Bool
    var isDraggingAnyTab: Bool = false
    let isThemeLight: Bool
    var isPlayingAudio: Bool = false
    var isMuted: Bool = false
    var onToggleMute: () -> Void = {}
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var effectiveHovered: Bool {
        isHovered && !isDraggingAnyTab
    }

    private var isInternalPage: Bool {
        tab.url?.scheme == "lotus" || tab.url?.absoluteString.hasPrefix("lotus://") == true
    }

    private var sidebarForeground: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var sidebarForegroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.60) : Color(nsColor: .secondaryLabelColor)
    }

    private var foregroundPrimary: Color {
        sidebarForeground
    }

    private var foregroundSecondary: Color {
        sidebarForegroundSecondary
    }

    private var selectedForegroundPrimary: Color {
        if isThemeLight {
            return isFocused ? .black : Color.black.opacity(0.70)
        } else {
            return isFocused ? .white : Color.white.opacity(0.72)
        }
    }

    private var selectedForegroundSecondary: Color {
        if isThemeLight {
            return isFocused ? Color.black.opacity(0.65) : Color.black.opacity(0.45)
        } else {
            return isFocused ? Color.white.opacity(0.65) : Color.white.opacity(0.45)
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                faviconView
                    .opacity((isMuted || tab.isMuted || (isPlayingAudio && effectiveHovered)) ? 0 : 1)

                if isMuted || tab.isMuted {
                    Button(action: onToggleMute) {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help("Unmute Tab")
                } else if isPlayingAudio && effectiveHovered {
                    Button(action: onToggleMute) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isSplitActive ? selectedForegroundPrimary : sidebarForeground)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help("Mute Tab")
                }
            }
            .frame(width: 16, height: 16, alignment: .center)

            Text(tab.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSplitActive ? selectedForegroundPrimary : sidebarForeground.opacity(0.85))
                .lineLimit(1)
                .animation(.easeInOut(duration: 0.16), value: isFocused)
                .animation(.easeInOut(duration: 0.16), value: isSplitActive)

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(isSplitActive ? selectedForegroundSecondary : sidebarForegroundSecondary)
                    .animation(.easeInOut(duration: 0.16), value: isSplitActive)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(effectiveHovered ? 1 : 0)
            .allowsHitTesting(effectiveHovered)
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                .opacity(!isSplitActive && effectiveHovered ? 1 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture {
            onSelect()
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
    }

    @ViewBuilder
    private var faviconView: some View {
        ZStack {
            if isInternalPage {
                Image(systemName: tab.url?.internalPageSystemImage ?? "globe")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(foregroundPrimary.opacity(0.85))
                    .frame(width: 16, height: 16, alignment: .center)
            } else if let faviconURL = tab.faviconURL {
                CachedFaviconView(
                    url: faviconURL,
                    defaultSystemName: "camera.macro",
                    fallbackColor: foregroundSecondary,
                    size: 13
                )
                .frame(width: 16, height: 16, alignment: .center)
            } else {
                Image(systemName: "camera.macro")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(foregroundSecondary)
                    .frame(width: 16, height: 16, alignment: .center)
            }
        }
        .frame(width: 16, height: 16, alignment: .center)
        .contentTransition(.identity)
    }
}
