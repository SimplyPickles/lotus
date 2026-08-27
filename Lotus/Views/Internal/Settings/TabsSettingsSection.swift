//
//  TabsSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct TabsSettingsSection: View {
    @ObservedObject var browserState: BrowserState
    @AppStorage("lotus.browser.newTabPosition") private var newTabPosition: String = "below"
    @AppStorage("lotus.browser.autoGroupTabs") private var autoGroupTabs: Bool = true
    @AppStorage("lotus.browser.autoFolderNames") private var autoFolderNames: Bool = true
    @AppStorage("lotus.browser.reorderHapticFeedback") private var reorderHapticFeedback: Bool = true
    @AppStorage("lotus.browser.autoCloseBlankTabs") private var autoCloseBlankTabs: Bool = false
    @AppStorage("lotus.browser.autoArchiveInterval") private var autoArchiveInterval: String = "never"

    var body: some View {
        VStack(spacing: 16) {
            SettingsSectionCard(title: "Tab Management") {
                NewTabPositionSettingsRow(newTabPosition: $newTabPosition)
                SettingsDivider()
                AutoGroupTabsSettingsRow(autoGroupTabs: $autoGroupTabs)
                SettingsDivider()
                AutoFolderNamesSettingsRow(autoFolderNames: $autoFolderNames)
                SettingsDivider()
                AutoCloseBlankTabsSettingsRow(autoCloseBlankTabs: $autoCloseBlankTabs)
                SettingsDivider()
                ReorderHapticFeedbackSettingsRow(reorderHapticFeedback: $reorderHapticFeedback)
            }

            SettingsSectionCard(
                title: "Tab Archiving",
//                footer: "Inactive tabs older than the selected interval will be automatically moved into your tab archive."
            ) {
                AutoArchiveSettingsRow(autoArchiveInterval: $autoArchiveInterval, browserState: browserState)
            }
        }
    }
}

// MARK: - Rows

private struct AutoGroupTabsSettingsRow: View {
    @Binding var autoGroupTabs: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Automatically group tabs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Groups child tabs opened from links into a collapsible tab group")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Automatically group tabs", isOn: $autoGroupTabs)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct ReorderHapticFeedbackSettingsRow: View {
    @Binding var reorderHapticFeedback: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Haptic feedback on tab reorder")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Provides a subtle tactile click when dragging tabs across new positions")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Haptic feedback on tab reorder", isOn: $reorderHapticFeedback)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct NewTabPositionSettingsRow: View {
    @Binding var newTabPosition: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("New tab placement")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Where new tabs appear in the sidebar strip")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("New tab placement", selection: $newTabPosition) {
                Text("Below Active Tab").tag("below")
                Text("At End of Strip").tag("end")
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 160, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct AutoFolderNamesSettingsRow: View {
    @Binding var autoFolderNames: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Automatically rename folders")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)
                
                Text("Automatically rename folders when modified")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }
            
            Spacer()

            Toggle("Automatically rename folders", isOn: $autoFolderNames)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct AutoCloseBlankTabsSettingsRow: View {
    @Binding var autoCloseBlankTabs: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Automatically close blank tabs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Automatically closes unused empty tabs when opening new links")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Auto-close blank tabs", isOn: $autoCloseBlankTabs)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct AutoArchiveSettingsRow: View {
    @Binding var autoArchiveInterval: String
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Auto-archive inactive tabs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Automatically moves unviewed tabs into the Archive folder")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("Auto-archive inactive tabs", selection: $autoArchiveInterval) {
                Text("Never").tag("never")
                Text("After 6 hours").tag("6h")
                Text("After 12 hours").tag("12h")
                Text("After 24 hours").tag("24h")
                Text("After 7 days").tag("7d")
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 170, alignment: .trailing)
            .onChange(of: autoArchiveInterval) { _, _ in
                browserState.archiveInactiveTabsIfNeeded()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}
