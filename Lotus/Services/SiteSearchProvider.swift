//
//  SiteSearchProvider.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

/// A site the command palette can search directly ("bangs" / tab-to-search).
///
/// Typing a trigger (e.g. `youtube`, `yt`, or `!yt`) and pressing Tab or
/// Space locks the palette into the provider's search mode; the subsequent
/// query is sent straight to the site's search URL.
struct SiteSearchProvider: Identifiable, Equatable {
    let id: String
    let name: String
    let host: String
    let iconName: String
    /// Lowercase tokens that activate this provider (with or without a `!` prefix).
    let triggers: [String]
    /// Base search endpoint, without the query parameter.
    let searchEndpoint: String
    let queryParameter: String
    /// Brand accent used for the locked-mode chip and tab-to-search hint.
    let accentColor: Color
    let isAccentLight: Bool
    let customTemplate: String?

    init(
        id: String,
        name: String,
        host: String,
        iconName: String,
        triggers: [String],
        searchEndpoint: String,
        queryParameter: String,
        accentColor: Color,
        isAccentLight: Bool = false,
        customTemplate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.iconName = iconName
        self.triggers = triggers
        self.searchEndpoint = searchEndpoint
        self.queryParameter = queryParameter
        self.accentColor = accentColor
        self.isAccentLight = isAccentLight
        self.customTemplate = customTemplate
    }

    func searchURL(for query: String) -> URL? {
        if let customTemplate = customTemplate {
            return customTemplate.resolvingSearchTemplate(query: query)
        }
        var components = URLComponents(string: searchEndpoint)
        components?.queryItems = [URLQueryItem(name: queryParameter, value: query)]
        return components?.url
    }

    var homepageURL: URL? {
        URL(string: "https://\(host)")
    }

    // MARK: - Registry

    static var all: [SiteSearchProvider] {
        var base: [SiteSearchProvider] = [
            SiteSearchProvider(id: "chatgpt", name: "ChatGPT", host: "chatgpt.com",
                               iconName: "sparkles",
                               triggers: ["chatgpt", "gpt", "chat"],
                               searchEndpoint: "https://chatgpt.com/", queryParameter: "q",
                               accentColor: Color(red: 0.06, green: 0.65, blue: 0.53)),
            SiteSearchProvider(id: "claude", name: "Claude", host: "claude.ai",
                               iconName: "sparkles",
                               triggers: ["claude", "cl"],
                               searchEndpoint: "https://claude.ai/new", queryParameter: "q",
                               accentColor: Color(red: 0.85, green: 0.45, blue: 0.30)),
            SiteSearchProvider(id: "gemini", name: "Gemini", host: "gemini.google.com",
                               iconName: "sparkle",
                               triggers: ["gemini", "gem"],
                               searchEndpoint: "https://gemini.google.com/app", queryParameter: "q",
                               accentColor: Color(red: 0.31, green: 0.48, blue: 0.96)),
            SiteSearchProvider(id: "youtube", name: "YouTube", host: "www.youtube.com",
                               iconName: "play.rectangle.fill",
                               triggers: ["youtube", "yt"],
                               searchEndpoint: "https://www.youtube.com/results", queryParameter: "search_query",
                               accentColor: Color(red: 0.90, green: 0.13, blue: 0.13)),
            SiteSearchProvider(id: "wikipedia", name: "Wikipedia", host: "en.wikipedia.org",
                               iconName: "book.closed.fill",
                               triggers: ["wikipedia", "wiki", "w"],
                               searchEndpoint: "https://en.wikipedia.org/w/index.php", queryParameter: "search",
                               accentColor: Color(red: 0.35, green: 0.38, blue: 0.42)),
            SiteSearchProvider(id: "reddit", name: "Reddit", host: "www.reddit.com",
                               iconName: "bubble.left.and.bubble.right.fill",
                               triggers: ["reddit", "r"],
                               searchEndpoint: "https://www.reddit.com/search/", queryParameter: "q",
                               accentColor: Color(red: 1.00, green: 0.27, blue: 0.00)),
            SiteSearchProvider(id: "github", name: "GitHub", host: "github.com",
                               iconName: "chevron.left.forwardslash.chevron.right",
                               triggers: ["github", "gh"],
                               searchEndpoint: "https://github.com/search", queryParameter: "q",
                               accentColor: Color(red: 0.29, green: 0.33, blue: 0.39)),
            SiteSearchProvider(id: "amazon", name: "Amazon", host: "www.amazon.com",
                               iconName: "cart.fill",
                               triggers: ["amazon"],
                               searchEndpoint: "https://www.amazon.com/s", queryParameter: "k",
                               accentColor: Color(red: 0.90, green: 0.55, blue: 0.00)),
            SiteSearchProvider(id: "x", name: "X", host: "x.com",
                               iconName: "bubble.left.fill",
                               triggers: ["x", "twitter"],
                               searchEndpoint: "https://x.com/search", queryParameter: "q",
                               accentColor: Color(red: 0.16, green: 0.18, blue: 0.22)),
            SiteSearchProvider(id: "stackoverflow", name: "Stack Overflow", host: "stackoverflow.com",
                               iconName: "square.stack.3d.up.fill",
                               triggers: ["stackoverflow", "so"],
                               searchEndpoint: "https://stackoverflow.com/search", queryParameter: "q",
                               accentColor: Color(red: 0.96, green: 0.50, blue: 0.14)),
            SiteSearchProvider(id: "twitch", name: "Twitch", host: "www.twitch.tv",
                               iconName: "play.tv.fill",
                               triggers: ["twitch"],
                               searchEndpoint: "https://www.twitch.tv/search", queryParameter: "term",
                               accentColor: Color(red: 0.57, green: 0.27, blue: 1.00)),
        ]

        for custom in CustomBangsStore.shared.customBangs {
            let trigger = custom.cleanTrigger.lowercased()
            let host = URL(string: custom.searchURLTemplate)?.host ?? "search"
            if let existingIdx = base.firstIndex(where: { $0.triggers.contains(trigger) }) {
                base[existingIdx] = SiteSearchProvider(
                    id: custom.id.uuidString,
                    name: custom.name,
                    host: host,
                    iconName: custom.iconName,
                    triggers: [trigger],
                    searchEndpoint: custom.searchURLTemplate,
                    queryParameter: "q",
                    accentColor: custom.accentColor,
                    customTemplate: custom.searchURLTemplate
                )
            } else {
                base.append(SiteSearchProvider(
                    id: custom.id.uuidString,
                    name: custom.name,
                    host: host,
                    iconName: custom.iconName,
                    triggers: [trigger],
                    searchEndpoint: custom.searchURLTemplate,
                    queryParameter: "q",
                    accentColor: custom.accentColor,
                    customTemplate: custom.searchURLTemplate
                ))
            }
        }

        for customEngine in CustomSearchEnginesStore.shared.customEngines {
            if let shortcut = customEngine.shortcut, !shortcut.isEmpty {
                let trigger = shortcut.trimmingCharacters(in: CharacterSet(charactersIn: "!")).lowercased()
                if !trigger.isEmpty && !base.contains(where: { $0.triggers.contains(trigger) }) {
                    base.append(SiteSearchProvider(
                        id: customEngine.id.uuidString,
                        name: customEngine.name,
                        host: customEngine.host,
                        iconName: customEngine.iconName,
                        triggers: [trigger],
                        searchEndpoint: customEngine.searchURLTemplate,
                        queryParameter: "q",
                        accentColor: Color.accentColor,
                        customTemplate: customEngine.searchURLTemplate
                    ))
                }
            }
        }
        return base
    }

    static var activeProviders: [SiteSearchProvider] {
        let isBangsEnabled = UserDefaults.standard.object(forKey: "lotus.browser.bangsEnabled") as? Bool ?? true
        guard isBangsEnabled else { return [] }
        let disabledList = UserDefaults.standard.stringArray(forKey: "lotus.browser.disabledBangIDs") ?? []
        let disabledSet = Set(disabledList)
        return all.filter { !disabledSet.contains($0.id) }
    }

    // MARK: - Matching

    private static func normalize(_ input: String) -> String? {
        var token = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !token.isEmpty, !token.contains(" ") else { return nil }
        if token.hasPrefix("!") {
            token.removeFirst()
        }
        guard !token.isEmpty else { return nil }
        return token
    }

    /// Provider whose trigger exactly equals the token (ignoring a `!` prefix).
    static func exactMatch(for input: String) -> SiteSearchProvider? {
        guard let token = normalize(input) else { return nil }
        return activeProviders.first(where: { $0.triggers.contains(token) })
    }

    /// Provider suggested while typing: an exact trigger, or (for 2+ typed
    /// characters, so single letters don't spam hints) a trigger prefix.
    static func match(for input: String) -> SiteSearchProvider? {
        guard let token = normalize(input) else { return nil }
        if let exact = activeProviders.first(where: { $0.triggers.contains(token) }) {
            return exact
        }
        guard token.count >= 2 else { return nil }
        return activeProviders.first(where: { provider in
            provider.triggers.contains { $0.hasPrefix(token) }
        })
    }

    /// Splits a full "bang" submission like `!yt lofi beats` into its
    /// provider and remaining query.
    static func parseBang(_ input: String) -> (provider: SiteSearchProvider, query: String)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("!") else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let first = parts.first, let provider = exactMatch(for: String(first)) else { return nil }
        let query = parts.count > 1 ? String(parts[1]) : ""
        return (provider, query)
    }
}
