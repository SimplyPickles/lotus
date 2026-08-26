//
//  AppearanceSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct AppearanceSettingsSection: View {
    var browserState: BrowserState? = nil

    @AppStorage("lotus.browser.accentColor") private var accentColor: String = "white"
    @AppStorage("lotus.browser.appearance") private var appearanceMode: String = "system"
    @AppStorage("lotus.browser.titlebarChromeTintingMode") private var titlebarChromeTintingMode: String = "adaptive"
    @AppStorage("lotus.browser.sidebarTabTintingMode") private var sidebarTabTintingMode: String = "adaptive"
    @AppStorage("lotus.browser.pinnedTabTintingMode") private var pinnedTabTintingMode: String = "adaptive"
    @AppStorage("lotus.browser.centerURLPreview") private var centerURLPreview: Bool = false
    @AppStorage("lotus.browser.centerCommandPaletteOverWebview") private var centerCommandPaletteOverWebview: Bool = false
    @AppStorage("lotus.browser.topBarVisibility") private var topBarVisibility: String = "always"
    @AppStorage("lotus.browser.showsBrowserFrame") private var showsBrowserFrame: Bool = true
    @AppStorage("lotus.browser.showsRoundedWebCorners") private var showsRoundedWebCorners: Bool = true
    @AppStorage("lotus.browser.smoothTabSwitchAnimation") private var smoothTabSwitchAnimation: Bool = true
    @AppStorage("lotus.browser.toolbarLayout") private var toolbarLayoutRaw: String = ToolbarItemType.serializeLayout(ToolbarItemType.defaultOrder)

    var body: some View {
        VStack(spacing: 20) {
            SettingsSectionCard(title: "Theme & Accent", systemImage: "paintpalette") {
                AccentColorPickerRow(selectedAccent: $accentColor, browserState: browserState)
                SettingsDivider()
                AppearanceSettingsRow(appearanceMode: $appearanceMode)
            }

            SettingsSectionCard(title: "Chrome Tinting", systemImage: "sparkles") {
                TitlebarTintingSettingsRow(titlebarChromeTintingMode: $titlebarChromeTintingMode)
                SettingsDivider()
                SidebarTabTintingSettingsRow(sidebarTabTintingMode: $sidebarTabTintingMode)
                SettingsDivider()
                PinnedTabTintingSettingsRow(pinnedTabTintingMode: $pinnedTabTintingMode)
            }

            SettingsSectionCard(title: "Window & Layout", systemImage: "macwindow") {
                TopBarSettingsRow(topBarVisibility: $topBarVisibility)
                SettingsDivider()
                CenterURLPreviewSettingsRow(centerURLPreview: $centerURLPreview)
                SettingsDivider()
                CenterCommandPaletteSettingsRow(centerCommandPaletteOverWebview: $centerCommandPaletteOverWebview)
                SettingsDivider()
                BrowserFrameSettingsRow(showsBrowserFrame: $showsBrowserFrame)
                SettingsDivider()
                RoundedWebCornersSettingsRow(showsRoundedWebCorners: $showsRoundedWebCorners)
                SettingsDivider()
                SmoothTabSwitchAnimationSettingsRow(smoothTabSwitchAnimation: $smoothTabSwitchAnimation)
            }

            ToolbarArrangementSettingsCard(toolbarLayoutRaw: $toolbarLayoutRaw)
        }
    }
}

// MARK: - Rows

private struct AccentColorPickerRow: View {
    @Binding var selectedAccent: String
    var browserState: BrowserState? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var currentAccentKey: String {
        if let bs = browserState, !bs.isPrivate {
            return bs.currentProfile.color.accentColorEquivalent.rawValue
        }
        return selectedAccent
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Accent color")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            HStack(spacing: 10) {
                ForEach(LotusAccentColor.allCases) { accent in
                    AccentColorDot(
                        accent: accent,
                        isSelected: currentAccentKey == accent.rawValue,
                        action: {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                selectedAccent = accent.rawValue
                                if let bs = browserState, !bs.isPrivate {
                                    var updated = bs.currentProfile
                                    updated.color = accent.folderColorEquivalent
                                    bs.updateProfile(updated)
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }
}

private struct AccentColorDot: View {
    let accent: LotusAccentColor
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Circle()
                        .strokeBorder(
                            colorScheme == .dark ? Color.white : Color(nsColor: .labelColor),
                            lineWidth: 1.5
                        )
                        .frame(width: 26, height: 26)
                        .transition(.scale.combined(with: .opacity))
                }

                Circle()
                    .fill(accent.swatchColor)
                    .frame(width: 19, height: 19)
                    .overlay(
                        Group {
                            if accent == .white && colorScheme == .light {
                                Circle()
                                    .strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
                            }
                        }
                    )
            }
            .frame(width: 28, height: 28)
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(accent.displayName)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

private struct AppearanceSettingsRow: View {
    @Binding var appearanceMode: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Theme")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Picker("Theme", selection: $appearanceMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct TitlebarTintingSettingsRow: View {
    @Binding var titlebarChromeTintingMode: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Titlebar chrome tinting")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Tints top toolbar and container with site's dominant accent")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("Titlebar chrome tinting", selection: $titlebarChromeTintingMode) {
                Text("Adaptive").tag("adaptive")
                Text("Neutral").tag("neutral")
                Text("Accent").tag("systemAccent")
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 140, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct SidebarTabTintingSettingsRow: View {
    @Binding var sidebarTabTintingMode: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Sidebar tab tinting")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Tints active tab selection with site's dominant accent")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("Sidebar tab tinting", selection: $sidebarTabTintingMode) {
                Text("Adaptive").tag("adaptive")
                Text("Neutral").tag("neutral")
                Text("Accent").tag("systemAccent")
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 140, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct PinnedTabTintingSettingsRow: View {
    @Binding var pinnedTabTintingMode: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pin")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Pinned tab tinting")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Tints pinned tab cards with vibrant site gradients")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("Pinned tab tinting", selection: $pinnedTabTintingMode) {
                Text("Adaptive").tag("adaptive")
                Text("Neutral").tag("neutral")
                Text("Accent").tag("systemAccent")
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 140, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct CenterURLPreviewSettingsRow: View {
    @Binding var centerURLPreview: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.aligncenter")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Center address bar preview")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Centers text in inactive URL address bar")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Center address bar preview", isOn: $centerURLPreview)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct CenterCommandPaletteSettingsRow: View {
    @Binding var centerCommandPaletteOverWebview: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "command")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Center Command Palette")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Centers the palette in the window instead of top-aligning")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Center Command Palette", isOn: $centerCommandPaletteOverWebview)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct TopBarSettingsRow: View {
    @Binding var topBarVisibility: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Toolbar")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Picker("Toolbar", selection: $topBarVisibility) {
                Text("Always").tag("always")
                Text("Hover").tag("hover")
                Text("Never").tag("never")
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct BrowserFrameSettingsRow: View {
    @Binding var showsBrowserFrame: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.inset.filled")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Browser frame")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Toggle("Browser frame", isOn: $showsBrowserFrame)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct RoundedWebCornersSettingsRow: View {
    @Binding var showsRoundedWebCorners: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Rounded web corners")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Toggle("Rounded web corners", isOn: $showsRoundedWebCorners)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct SmoothTabSwitchAnimationSettingsRow: View {
    @Binding var smoothTabSwitchAnimation: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.below.rectangle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("Smooth tab switch animation")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)
                Text("Animate tab selection highlights and sliding transitions")
                    .font(.system(size: 11))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Smooth tab switch animation", isOn: $smoothTabSwitchAnimation)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }
}

// MARK: - Toolbar Arrangement Settings Card

private struct ToolbarArrangementSettingsCard: View {
    @Binding var toolbarLayoutRaw: String
    @State private var draggedItem: ToolbarItemType? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var items: [ToolbarItemType] {
        ToolbarItemType.parseLayout(from: toolbarLayoutRaw)
    }

    private var availableItems: [ToolbarItemType] {
        ToolbarItemType.availableItems(for: items)
    }

    private var isDefaultOrder: Bool {
        toolbarLayoutRaw == ToolbarItemType.serializeLayout(ToolbarItemType.defaultOrder)
    }

    private func swapItems(at index: Int, with otherIndex: Int) {
        guard index != otherIndex, index >= 0, index < items.count, otherIndex >= 0, otherIndex < items.count else { return }
        var updated = items
        updated.swapAt(index, otherIndex)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            toolbarLayoutRaw = ToolbarItemType.serializeLayout(updated)
        }
    }

    private func reorderItem(_ sourceItem: ToolbarItemType, relativeTo targetItem: ToolbarItemType, position: DropPosition) {
        guard sourceItem != targetItem else { return }
        var updated = items
        if let fromIndex = updated.firstIndex(of: sourceItem) {
            updated.remove(at: fromIndex)
        }
        guard let targetIndex = updated.firstIndex(of: targetItem) else { return }
        let insertIndex = position == .above ? targetIndex : targetIndex + 1
        let clampedIndex = max(0, min(insertIndex, updated.count))
        updated.insert(sourceItem, at: clampedIndex)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            toolbarLayoutRaw = ToolbarItemType.serializeLayout(updated)
        }
    }

    private func addItem(_ item: ToolbarItemType) {
        var updated = items
        if !updated.contains(item) {
            updated.append(item)
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                toolbarLayoutRaw = ToolbarItemType.serializeLayout(updated)
            }
        }
    }

    private func removeItem(_ item: ToolbarItemType) {
        var updated = items
        updated.removeAll { $0 == item }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            toolbarLayoutRaw = ToolbarItemType.serializeLayout(updated)
        }
    }

    private func resetToDefault() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            toolbarLayoutRaw = ToolbarItemType.serializeLayout(ToolbarItemType.defaultOrder)
        }
    }

    var body: some View {
        SettingsSectionCard(title: "Toolbar Layout", systemImage: "macwindow.badge.plus") {
            // Header summary and Reset action
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Toolbar items & arrangement")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text("Drag to reorder, use arrows, or remove items from the toolbar")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer()

                Button(action: resetToDefault) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Reset Default")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDefaultOrder)
                .opacity(isDefaultOrder ? 0.45 : 1.0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            SettingsDivider()

            // Active Toolbar Items List
            if items.isEmpty {
                HStack {
                    Spacer()
                    Text("No items on toolbar. Add items from below.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                        .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ToolbarItemReorderRow(
                            item: item,
                            index: index,
                            totalCount: items.count,
                            draggedItem: $draggedItem,
                            onMoveUp: {
                                swapItems(at: index, with: index - 1)
                            },
                            onMoveDown: {
                                swapItems(at: index, with: index + 1)
                            },
                            onRemove: {
                                removeItem(item)
                            },
                            onDropReorder: { sourceItem, position in
                                reorderItem(sourceItem, relativeTo: item, position: position)
                            }
                        )

                        if index < items.count - 1 {
                            SettingsDivider()
                        }
                    }
                }
            }

            // Available Items Section (Always Visible)
            SettingsDivider()

            AvailableItemsSectionView(
                availableItems: availableItems,
                draggedItem: $draggedItem,
                onAdd: addItem,
                onRemove: removeItem
            )
        }
    }
}

// MARK: - Available Items Section View

private struct AvailableItemsSectionView: View {
    let availableItems: [ToolbarItemType]
    @Binding var draggedItem: ToolbarItemType?
    let onAdd: (ToolbarItemType) -> Void
    let onRemove: (ToolbarItemType) -> Void

    @State private var isTargeted: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Available Items")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isTargeted ? Color.accentColor : (colorScheme == .dark ? .white.opacity(0.5) : .secondary))
                    .textCase(.uppercase)

                Spacer()

                Text(availableItems.isEmpty ? "Drag items here to remove" : "Click + or drag to toolbar")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.35) : .secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 2)

            if availableItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 5) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(isTargeted ? Color.accentColor : (colorScheme == .dark ? .white.opacity(0.4) : .secondary))

                        Text("All items are in your toolbar")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.75) : .primary)

                        Text("Drag items here from above to remove them")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.35) : .secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
                .background(
                    ZStack {
                        if isTargeted {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.08))
                        }

                        AnimatedDashedBorder(
                            cornerRadius: 8,
                            isTargeted: isTargeted,
                            activeStrokeColor: .accentColor,
                            inactiveStrokeColor: colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                            lineWidth: 1.5,
                            dash: [8, 6]
                        )
                    }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(availableItems.enumerated()), id: \.element.id) { index, item in
                        ToolbarAvailableItemRow(
                            item: item,
                            draggedItem: $draggedItem,
                            onAdd: {
                                onAdd(item)
                            }
                        )

                        if index < availableItems.count - 1 {
                            SettingsDivider()
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                )
                .overlay(
                    Group {
                        if isTargeted {
                            AnimatedDashedBorder(
                                cornerRadius: 8,
                                isTargeted: true,
                                activeStrokeColor: .accentColor,
                                inactiveStrokeColor: .clear,
                                lineWidth: 1.5,
                                dash: [8, 6]
                            )
                        }
                    }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isTargeted)
        .onDrop(of: [UTType.text], delegate: AvailableSectionDropDelegate(
            draggedItem: $draggedItem,
            isTargeted: $isTargeted,
            onRemove: onRemove
        ))
    }
}

// MARK: - Animated Dashed Border

private struct AnimatedDashedBorder: View {
    let cornerRadius: CGFloat
    let isTargeted: Bool
    let activeStrokeColor: Color
    let inactiveStrokeColor: Color
    let lineWidth: CGFloat
    let dash: [CGFloat]
    let period: CGFloat

    init(
        cornerRadius: CGFloat = 8,
        isTargeted: Bool,
        activeStrokeColor: Color = .accentColor,
        inactiveStrokeColor: Color,
        lineWidth: CGFloat = 1.5,
        dash: [CGFloat] = [8, 6],
        period: CGFloat = 28.0
    ) {
        self.cornerRadius = cornerRadius
        self.isTargeted = isTargeted
        self.activeStrokeColor = activeStrokeColor
        self.inactiveStrokeColor = inactiveStrokeColor
        self.lineWidth = lineWidth
        self.dash = dash
        self.period = period
    }

    var body: some View {
        TimelineView(.animation(paused: !isTargeted)) { timeline in
            let phase: CGFloat = isTargeted
                ? CGFloat(timeline.date.timeIntervalSinceReferenceDate * 32.0).truncatingRemainder(dividingBy: period)
                : 0

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    isTargeted ? activeStrokeColor : inactiveStrokeColor,
                    style: StrokeStyle(
                        lineWidth: isTargeted ? (lineWidth + 0.5) : lineWidth,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: dash,
                        dashPhase: -phase
                    )
                )
        }
    }
}

// MARK: - Drop Position Enum

private enum DropPosition {
    case above
    case below
}

// MARK: - Toolbar Item Reorder Row

private struct ToolbarItemReorderRow: View {
    let item: ToolbarItemType
    let index: Int
    let totalCount: Int
    @Binding var draggedItem: ToolbarItemType?
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void
    let onDropReorder: (ToolbarItemType, DropPosition) -> Void

    @State private var isHovered: Bool = false
    @State private var isTargeted: Bool = false
    @State private var dropPosition: DropPosition = .above
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Drag grip indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(isHovered ? 0.5 : 0.2) : .secondary.opacity(isHovered ? 0.6 : 0.25))
                .frame(width: 14)

            // Icon square badge
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))

                Image(systemName: item.iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : Color(nsColor: .labelColor))
            }
            .frame(width: 28, height: 28)

            // Title and description
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text(item.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            // Reordering buttons (Move Up / Move Down)
            HStack(spacing: 4) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .opacity(index == 0 ? 0.25 : (isHovered ? 1.0 : 0.7))
                .help("Move Up")

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == totalCount - 1)
                .opacity(index == totalCount - 1 ? 0.25 : (isHovered ? 1.0 : 0.7))
                .help("Move Down")
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            )

            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Remove from Toolbar")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            (isTargeted && draggedItem != item)
                ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                : (isHovered
                    ? (colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
                    : Color.clear)
        )
        .overlay(
            Group {
                if isTargeted && draggedItem != item {
                    VStack {
                        if dropPosition == .below {
                            Spacer()
                        }
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.85) : Color.primary.opacity(0.75))
                            .frame(height: 2)
                            .padding(.horizontal, 10)
                        if dropPosition == .above {
                            Spacer()
                        }
                    }
                    .animation(.easeInOut(duration: 0.1), value: dropPosition)
                }
            }
        )
        .opacity(draggedItem == item ? 0.35 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isTargeted)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onDrag {
            draggedItem = item
            return NSItemProvider(object: NSString(string: item.rawValue))
        }
        .onDrop(of: [UTType.text], delegate: ToolbarDropDelegate(
            targetItem: item,
            draggedItem: $draggedItem,
            isTargeted: $isTargeted,
            dropPosition: $dropPosition,
            onDropAction: onDropReorder
        ))
    }
}

// MARK: - Toolbar Available Item Row

private struct ToolbarAvailableItemRow: View {
    let item: ToolbarItemType
    @Binding var draggedItem: ToolbarItemType?
    let onAdd: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Drag grip indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(isHovered ? 0.4 : 0.15) : .secondary.opacity(isHovered ? 0.5 : 0.2))
                .frame(width: 14)

            // Icon square badge
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))

                Image(systemName: item.iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.65) : Color(nsColor: .secondaryLabelColor))
            }
            .frame(width: 28, height: 28)

            // Title and description
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.75) : .primary.opacity(0.85))

                Text(item.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.35) : .secondary.opacity(0.8))
            }

            Spacer()

            // Add Button
            Button(action: onAdd) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Add")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Add \(item.displayName) to Toolbar")
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(
            isHovered
                ? (colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
                : Color.clear
        )
        .opacity(draggedItem == item ? 0.35 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onDrag {
            draggedItem = item
            return NSItemProvider(object: NSString(string: item.rawValue))
        }
    }
}

// MARK: - Drop Delegates

private struct ToolbarDropDelegate: DropDelegate {
    let targetItem: ToolbarItemType
    @Binding var draggedItem: ToolbarItemType?
    @Binding var isTargeted: Bool
    @Binding var dropPosition: DropPosition
    let onDropAction: (ToolbarItemType, DropPosition) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        updatePosition(info: info)
        withAnimation(.easeInOut(duration: 0.15)) {
            isTargeted = true
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updatePosition(info: info)
        return DropProposal(operation: .move)
    }

    private func updatePosition(info: DropInfo) {
        let isAbove = info.location.y < 24
        let newPos: DropPosition = isAbove ? .above : .below
        if dropPosition != newPos {
            dropPosition = newPos
        }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isTargeted = false
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.easeInOut(duration: 0.15)) {
            isTargeted = false
        }
        let isAbove = info.location.y < 24
        let pos: DropPosition = isAbove ? .above : .below

        if let current = draggedItem {
            onDropAction(current, pos)
            draggedItem = nil
            return true
        }

        if let itemProvider = info.itemProviders(for: [UTType.text]).first {
            itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                if let stringData = data as? Data, let raw = String(data: stringData, encoding: .utf8),
                   let dropped = ToolbarItemType(rawValue: raw) {
                    DispatchQueue.main.async {
                        onDropAction(dropped, pos)
                    }
                } else if let raw = data as? String, let dropped = ToolbarItemType(rawValue: raw) {
                    DispatchQueue.main.async {
                        onDropAction(dropped, pos)
                    }
                }
            }
            return true
        }

        return false
    }
}



private struct AvailableSectionDropDelegate: DropDelegate {
    @Binding var draggedItem: ToolbarItemType?
    @Binding var isTargeted: Bool
    let onRemove: (ToolbarItemType) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        if let current = draggedItem {
            onRemove(current)
            draggedItem = nil
            return true
        }

        if let itemProvider = info.itemProviders(for: [UTType.text]).first {
            itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                if let stringData = data as? Data, let raw = String(data: stringData, encoding: .utf8),
                   let dropped = ToolbarItemType(rawValue: raw) {
                    DispatchQueue.main.async {
                        onRemove(dropped)
                    }
                } else if let raw = data as? String, let dropped = ToolbarItemType(rawValue: raw) {
                    DispatchQueue.main.async {
                        onRemove(dropped)
                    }
                }
            }
            return true
        }

        return false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
