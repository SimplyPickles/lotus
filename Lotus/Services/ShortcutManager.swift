//
//  ShortcutManager.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI
import AppKit
import Combine

struct ShortcutCategory: Identifiable {
    let id: String
    let title: String
    let items: [ShortcutMetadata]
}

struct ShortcutMetadata: Identifiable {
    let id: String
    let title: String
    let defaultDisplay: String
}

final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    private let storageKey = "lotus.browser.custom_shortcuts"

    @Published var overrides: [String: CustomShortcutData] = [:]

    private init() {
        loadOverrides()
    }

    func loadOverrides() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let dict = try? JSONDecoder().decode([String: CustomShortcutData].self, from: data) {
            self.overrides = dict
        }
    }

    func saveOverrides() {
        if let data = try? JSONEncoder().encode(overrides) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func setOverride(id: String, shortcut: CustomShortcutData) {
        overrides[id] = shortcut
        saveOverrides()
    }

    func resetOverride(id: String) {
        overrides.removeValue(forKey: id)
        saveOverrides()
    }

    func resetAll() {
        overrides.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func customShortcut(for id: String) -> CustomShortcutData? {
        overrides[id]
    }

    static let categories: [ShortcutCategory] = [
        ShortcutCategory(
            id: "tabs",
            title: "Tabs & Windows",
            items: [
                ShortcutMetadata(id: "newTab", title: "New Tab / Command Palette", defaultDisplay: "⌘T"),
                ShortcutMetadata(id: "closeTab", title: "Close Tab", defaultDisplay: "⌘W"),
                ShortcutMetadata(id: "archiveTab", title: "Archive Tab", defaultDisplay: "⇧⌘E"),
                ShortcutMetadata(id: "reopenClosedTab", title: "Reopen Closed Tab", defaultDisplay: "⇧⌘T"),
                ShortcutMetadata(id: "toggleSidebar", title: "Toggle Sidebar", defaultDisplay: "⌘S"),
                ShortcutMetadata(id: "showHistory", title: "Show History", defaultDisplay: "⌘Y"),
                ShortcutMetadata(id: "showDownloads", title: "Show Downloads", defaultDisplay: "⌥⌘L"),
                ShortcutMetadata(id: "showBookmarks", title: "Show Bookmarks", defaultDisplay: "⌥⌘B"),
                ShortcutMetadata(id: "bookmarkPage", title: "Bookmark Current Page", defaultDisplay: "⌘D"),
                ShortcutMetadata(id: "openSettings", title: "Open Settings", defaultDisplay: "⌘,"),
            ]
        ),
        ShortcutCategory(
            id: "navigation",
            title: "Navigation",
            items: [
                ShortcutMetadata(id: "focusAddressBar", title: "Focus Address Bar", defaultDisplay: "⌘L"),
                ShortcutMetadata(id: "reload", title: "Reload Page", defaultDisplay: "⌘R"),
                ShortcutMetadata(id: "reloadFromOrigin", title: "Force Reload Page", defaultDisplay: "⇧⌘R"),
                ShortcutMetadata(id: "back", title: "Back", defaultDisplay: "⌘["),
                ShortcutMetadata(id: "forward", title: "Forward", defaultDisplay: "⌘]"),
                ShortcutMetadata(id: "copyCurrentURL", title: "Copy Clean URL", defaultDisplay: "⇧⌘C"),
                ShortcutMetadata(id: "findInPage", title: "Find in Page", defaultDisplay: "⌘F"),
                ShortcutMetadata(id: "findNext", title: "Find Next Match", defaultDisplay: "⌘G"),
                ShortcutMetadata(id: "findPrevious", title: "Find Previous Match", defaultDisplay: "⇧⌘G"),
                ShortcutMetadata(id: "printPage", title: "Print Page", defaultDisplay: "⌘P"),
                ShortcutMetadata(id: "viewSource", title: "View Page Source", defaultDisplay: "⌥⌘U"),
                ShortcutMetadata(id: "inspectElement", title: "Inspect Element", defaultDisplay: "⌥⌘I"),
            ]
        ),
        ShortcutCategory(
            id: "zoom",
            title: "Zoom",
            items: [
                ShortcutMetadata(id: "zoomInEquals", title: "Zoom In", defaultDisplay: "⌘="),
                ShortcutMetadata(id: "zoomOut", title: "Zoom Out", defaultDisplay: "⌘-"),
                ShortcutMetadata(id: "zoomActualSize", title: "Reset Zoom (Actual Size)", defaultDisplay: "⌘0"),
            ]
        )
    ]
}
