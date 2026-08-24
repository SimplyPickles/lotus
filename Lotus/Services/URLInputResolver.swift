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

        var displayName: String {
            switch self {
            case .google: return "Google"
            case .duckDuckGo: return "DuckDuckGo"
            case .bing: return "Bing"
            case .brave: return "Brave"
            case .startpage: return "Startpage"
            }
        }

        func searchURL(for query: String) -> URL? {
            let endpoint: String
            let parameter: String

            switch self {
            case .google:
                endpoint = "https://www.google.com/search"
                parameter = "q"
            case .duckDuckGo:
                endpoint = "https://duckduckgo.com/"
                parameter = "q"
            case .bing:
                endpoint = "https://www.bing.com/search"
                parameter = "q"
            case .brave:
                endpoint = "https://search.brave.com/search"
                parameter = "q"
            case .startpage:
                endpoint = "https://www.startpage.com/sp/search"
                parameter = "query"
            }

            var components = URLComponents(string: endpoint)
            components?.queryItems = [URLQueryItem(name: parameter, value: query)]
            return components?.url
        }
    }

    static var selectedSearchEngine: SearchEngine {
        let storedValue = UserDefaults.standard.string(forKey: "lotus.browser.searchEngine")
        return storedValue.flatMap(SearchEngine.init(rawValue:)) ?? .google
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
        if lower == "lotus://settings" || lower == "settings" || lower == "lotus:settings" {
            return .lotusSettings
        }
        if lower.hasPrefix("lotus://") {
            return URL(string: trimmed)
        }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        if trimmed.contains(".") && !trimmed.contains(" ") {
            return URL(string: "https://\(trimmed)")
        }
        return selectedSearchEngine.searchURL(for: trimmed)
    }

    /// A display title for a freshly created tab pointing at `url`.
    static func initialTitle(for url: URL, input: String) -> String {
        if url.isLotusPage {
            if url.host == "history" { return "History" }
            if url.host == "downloads" { return "Downloads" }
            if url.host == "settings" { return "Settings" }
            return "New Tab"
        }
        return url.host ?? input
    }
}
