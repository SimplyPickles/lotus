//
//  BrowserState+CommandPalette.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

extension BrowserState {

    // MARK: - Command Palette

    /// What submitting the palette does with the resolved URL.
    enum CommandPaletteMode {
        /// Open a new tab (⌘T).
        case newTab
        /// Replace the current tab's page (⌘L / address-bar click).
        case editCurrentTab
    }

    /// Opens the ⌘T command palette. No tab is created until the user
    /// submits — mirroring Arc/Zen new-tab semantics.
    ///
    /// Deliberately not animated: the palette must appear the instant ⌘T is
    /// pressed, with no perceptible latency.
    func openCommandPalette() {
        commandPaletteMode = .newTab
        guard !isCommandPaletteOpen else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isCommandPaletteOpen = true
        }
    }

    /// Opens the palette prefilled with the current tab's URL; submitting
    /// navigates that tab in place instead of opening a new one.
    func openCommandPaletteForCurrentTab() {
        guard activeTab != nil else {
            openCommandPalette()
            return
        }
        commandPaletteMode = .editCurrentTab
        guard !isCommandPaletteOpen else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isCommandPaletteOpen = true
        }
    }

    func closeCommandPalette() {
        guard isCommandPaletteOpen else { return }
        withAnimation(.easeOut(duration: 0.10)) {
            isCommandPaletteOpen = false
        }
    }

    func toggleCommandPalette() {
        if isCommandPaletteOpen {
            closeCommandPalette()
        } else {
            openCommandPalette()
        }
    }

    /// Focuses the existing Settings tab in the current profile, or opens a new Settings tab.
    func openSettingsPage() {
        if let settingsTab = activeProfileTabs.first(where: { $0.url == .lotusSettings }) {
            selectTab(settingsTab)
        } else {
            addTabBelow(title: "Settings", url: .lotusSettings)
        }
    }

    /// Resolves palette input into a URL, opens it in a new tab, and closes
    /// the palette. Invalid/empty input is ignored (palette stays open).
    func openTab(with input: String) {
        guard isCommandPaletteOpen else { return }
        guard let url = URLInputResolver.resolve(input) else { return }
        closeCommandPalette()
        addTab(title: URLInputResolver.initialTitle(for: url, input: input), url: url)
    }

    /// Opens an already-resolved URL (site-search / bang submissions) in a
    /// new tab and closes the palette.
    func openTab(at url: URL, title: String? = nil) {
        guard isCommandPaletteOpen else { return }
        closeCommandPalette()
        addTab(title: title ?? url.host ?? "New Tab", url: url)
    }
}
