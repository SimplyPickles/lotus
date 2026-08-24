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

    /// A prettified display title for internal `lotus://` pages (e.g. "Settings", "History", "Downloads").
    var lotusPageTitle: String? {
        guard isLotusPage else { return nil }
        switch host?.lowercased() {
        case "settings":
            return "Settings"
        case "history":
            return "History"
        case "downloads":
            return "Downloads"
        default:
            if let host = host, !host.isEmpty {
                return host.capitalized
            }
            return "Lotus"
        }
    }
}

