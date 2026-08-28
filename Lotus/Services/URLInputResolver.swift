//
//  URLInputResolver.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import Foundation

/// Turns free-form address-bar / command-palette input into a navigable URL.
///
/// Shared by `BrowserState.navigateTab` and the command palette so both
/// interpret input identically.
enum URLInputResolver {

    enum SearchEngine: String, CaseIterable {
        case google
        case duckDuckGo
        case bing
        case brave
        case startpage
        case kagi
        case ecosia

        var displayName: String {
            switch self {
            case .google: return "Google"
            case .duckDuckGo: return "DuckDuckGo"
            case .bing: return "Bing"
            case .brave: return "Brave"
            case .startpage: return "Startpage"
            case .kagi: return "Kagi"
            case .ecosia: return "Ecosia"
            }
        }

        func searchURL(for query: String) -> URL? {
            CustomSearchEnginesStore.shared.searchURL(for: rawValue, query: query)
        }
    }

    static var selectedSearchEngine: SearchEngine {
        let storedValue = UserDefaults.standard.string(forKey: "lotus.browser.searchEngine") ?? "google"
        return SearchEngine(rawValue: storedValue)
            ?? SearchEngine.allCases.first(where: { $0.rawValue.lowercased() == storedValue.lowercased() })
            ?? .google
    }

    static func searchURL(for query: String) -> URL? {
        let storedValue = UserDefaults.standard.string(forKey: "lotus.browser.searchEngine") ?? "google"
        return CustomSearchEnginesStore.shared.searchURL(for: storedValue, query: query)
    }

    /// Resolution order: internal page aliases → explicit schemes →
    /// bare domains (contains a dot, no spaces) → search-engine query.
    static func resolve(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()

        if lower == "lotus://history" || lower == "history" || lower == "lotus:history" {
            return .lotusHistory
        }
        if lower == "lotus://downloads" || lower == "downloads" || lower == "lotus:downloads" {
            return .lotusDownloads
        }
        if lower == "lotus://settings" || lower == "settings" || lower == "lotus:settings" || lower == "preferences" {
            return .lotusSettings
        }
        if lower == "lotus://bookmarks" || lower == "bookmarks" || lower == "lotus:bookmarks" {
            return .lotusBookmarks
        }
        if lower == "lotus://shortcuts" || lower == "shortcuts" || lower == "lotus:shortcuts" || lower == "keyboard shortcuts" || lower == "keyboardshortcuts" || lower == "hotkeys" || lower == "keybindings" {
            return .lotusShortcuts
        }
        if lower == "lotus://data" || lower == "data" || lower == "lotus:data" || lower == "lotus://sitedata" || lower == "sitedata" || lower == "site data" || lower == "lotus://cookies" || lower == "cookies" || lower == "lotus:cookies" {
            return .lotusWebsiteData
        }
        if lower.hasPrefix("lotus://") {
            return URL(string: trimmed)
        }
        if lower == "about:blank" || lower.hasPrefix("about:") {
            return URL(string: trimmed)
        }
        if lower.hasPrefix("file://") {
            return URL(string: trimmed)
        }
        if trimmed.hasPrefix("/") && FileManager.default.fileExists(atPath: trimmed) {
            return URL(fileURLWithPath: trimmed)
        }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: trimmed)
        }

        // Local development servers: localhost, 127.0.0.1, 0.0.0.0 (with or without port)
        if !trimmed.contains(" ") {
            if lower == "localhost" || lower.hasPrefix("localhost:") {
                return URL(string: "http://\(trimmed)")
            }
            if lower.hasPrefix("127.0.0.1") || lower.hasPrefix("0.0.0.0") || lower.hasPrefix("[::1]") {
                return URL(string: "http://\(trimmed)")
            }
            if lower.hasSuffix(".local") || lower.contains(".local:") {
                return URL(string: "http://\(trimmed)")
            }
            if trimmed.contains(":") && !trimmed.contains("/") {
                // Host with port, e.g. "dev-server:8080"
                let parts = trimmed.split(separator: ":")
                if parts.count == 2, Int(parts[1]) != nil {
                    return URL(string: "http://\(trimmed)")
                }
            }
        }

        if trimmed.contains(".") && !trimmed.contains(" ") {
            return URL(string: "https://\(trimmed)")
        }
        return searchURL(for: trimmed)
    }

    /// A display title for a freshly created tab pointing at `url`.
    static func initialTitle(for url: URL, input: String) -> String {
        if url.isLotusPage {
            if url.host == "history" { return "History" }
            if url.host == "downloads" { return "Downloads" }
            if url.host == "settings" { return "Settings" }
            if url.host == "bookmarks" { return "Bookmarks" }
            if url.host == "shortcuts" || url.host == "keyboardshortcuts" { return "Keyboard Shortcuts" }
            if url.host == "data" || url.host == "sitedata" || url.host == "cookies" { return "Website Data" }
            return url.lotusPageTitle ?? "New Tab"
        }
        return url.host ?? input
    }
}
