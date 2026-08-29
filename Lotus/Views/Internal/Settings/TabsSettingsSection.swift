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
                SettingsPickerRow(
                    systemImage: "plus.rectangle.on.rectangle",
                    title: "New tab placement",
                    subtitle: "Where new tabs appear in the sidebar strip",
                    selection: $newTabPosition,
                    options: [
                        ("below", "Below Active Tab"),
                        ("end", "At End of Strip")
                    ],
                    pickerWidth: 160
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "rectangle.stack.badge.plus",
                    title: "Automatically group tabs",
                    subtitle: "Groups child tabs opened from links into a collapsible tab group",
                    isOn: $autoGroupTabs
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "folder.badge.gearshape",
                    title: "Automatically rename folders",
                    subtitle: "Automatically rename folders when modified",
                    isOn: $autoFolderNames
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "xmark.circle",
                    title: "Automatically close blank tabs",
                    subtitle: "Automatically closes unused empty tabs when opening new links",
                    isOn: $autoCloseBlankTabs
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "hand.tap",
                    title: "Haptic feedback on tab reorder",
                    subtitle: "Provides a subtle tactile click when dragging tabs across new positions",
                    isOn: $reorderHapticFeedback
                )
            }

            SettingsSectionCard(
                title: "Tab Archiving"
            ) {
                SettingsPickerRow(
                    systemImage: "archivebox",
                    title: "Auto-archive inactive tabs",
                    subtitle: "Automatically moves unviewed tabs into the Archive folder",
                    selection: $autoArchiveInterval,
                    options: [
                        ("never", "Never"),
                        ("6h", "After 6 hours"),
                        ("12h", "After 12 hours"),
                        ("24h", "After 24 hours"),
                        ("7d", "After 7 days")
                    ],
                    pickerWidth: 170
                ) { _ in
                    browserState.archiveInactiveTabsIfNeeded()
                }
            }
        }
    }
}
