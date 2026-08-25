//
//  URL+Lotus.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation

extension URL {
    /// True for internal `lotus://` pages (e.g. lotus://history), which render
    /// as SwiftUI overlays instead of web content.
    var isLotusPage: Bool {
        scheme == "lotus"
    }

    /// The internal browsing history page.
    static let lotusHistory = URL(string: "lotus://history")!

    /// The internal downloads manager page.
    static let lotusDownloads = URL(string: "lotus://downloads")!

    /// The integrated browser settings page.
    static let lotusSettings = URL(string: "lotus://settings")!

    /// The internal website data & cookies manager page.
    static let lotusWebsiteData = URL(string: "lotus://data")!

    /// The internal bookmarks manager page.
    static let lotusBookmarks = URL(string: "lotus://bookmarks")!

    /// The internal keyboard shortcuts customizer page.
    static let lotusShortcuts = URL(string: "lotus://shortcuts")!

    /// A prettified display title for internal `lotus://` pages (e.g. "Settings", "History", "Downloads", "Website Data", "Bookmarks", "Keyboard Shortcuts").
    var lotusPageTitle: String? {
        guard isLotusPage else { return nil }
        switch host?.lowercased() {
        case "settings":
            return "Settings"
        case "history":
            return "History"
        case "downloads":
            return "Downloads"
        case "bookmarks":
            return "Bookmarks"
        case "shortcuts", "keyboardshortcuts":
            return "Keyboard Shortcuts"
        case "data", "sitedata", "cookies":
            return "Website Data"
        default:
            if let host = host, !host.isEmpty {
                return host.capitalized
            }
            return "Lotus"
        }
    }

    /// The SF Symbol name representing this internal page in tabs and UI.
    var internalPageSystemImage: String? {
        guard isLotusPage else { return nil }
        switch host?.lowercased() {
        case "history":
            return "clock"
        case "downloads":
            return "arrow.down.circle"
        case "settings":
            return "gearshape"
        case "bookmarks":
            return "bookmark.fill"
        case "shortcuts", "keyboardshortcuts":
            return "keyboard"
        case "data", "sitedata", "cookies":
            return "internaldrive"
        default:
            return "globe"
        }
    }
}
