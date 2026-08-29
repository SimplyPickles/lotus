//
//  SearchSuggestionService.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation
import Combine

struct SearchSuggestion: Identifiable, Equatable, Hashable {
    let id: String
    let text: String
    let title: String?
    let subtitle: String?
    let isURL: Bool
    let isInternalPage: Bool
    let isHistory: Bool
    let systemImage: String
    let badgeText: String?
    let faviconURL: URL?
    /// Whether this suggestion represents an already-open tab.
    let isTab: Bool
    /// The tab ID to switch to when `isTab` is true.
    let tabId: UUID?

    var displayText: String {
        if let title = title, !title.isEmpty {
            return title
        }
        switch text.lowercased() {
        case "lotus://history": return "History"
        case "lotus://downloads": return "Downloads"
        case "lotus://settings": return "Settings"
        case "lotus://bookmarks": return "Bookmarks"
        case "lotus://shortcuts", "lotus://keyboardshortcuts": return "Keyboard Shortcuts"
        default: return text
        }
    }

    init(
        text: String,
        title: String? = nil,
        subtitle: String? = nil,
        isURL: Bool = false,
        isInternalPage: Bool = false,
        isHistory: Bool = false,
        systemImage: String? = nil,
        badgeText: String? = nil,
        faviconURL: URL? = nil
    ) {
        self.id = (isHistory ? "hist-" : "") + text + (title ?? "")
        self.text = text
        self.title = title
        self.subtitle = subtitle
        self.isURL = isURL
        self.isInternalPage = isInternalPage
        self.isHistory = isHistory
        self.isTab = false
        self.tabId = nil
        self.faviconURL = faviconURL
        if let systemImage {
            self.systemImage = systemImage
        } else if isHistory {
            self.systemImage = "clock"
        } else if isInternalPage {
            self.systemImage = "clock"
        } else if isURL {
            self.systemImage = "globe"
        } else {
            self.systemImage = "magnifyingglass"
        }
        if let badgeText {
            self.badgeText = badgeText
        } else if isHistory {
            self.badgeText = "History"
        } else if isInternalPage {
            self.badgeText = "Lotus Page"
        } else if isURL {
            self.badgeText = "Jump to URL"
        } else {
            self.badgeText = nil
        }
    }

    /// Designated init for open-tab suggestions.
    init(tab: TabItem) {
        self.id = "tab-" + tab.id.uuidString
        self.text = tab.url?.absoluteString ?? tab.title
        self.title = tab.title.isEmpty ? tab.url?.host : tab.title
        self.subtitle = tab.url?.host
        self.isURL = false
        self.isInternalPage = false
        self.isHistory = false
        self.isTab = true
        self.tabId = tab.id
        self.systemImage = "macwindow.on.rectangle"
        self.badgeText = "Switch to Tab"
        self.faviconURL = tab.faviconURL
    }
}

@MainActor
final class SearchSuggestionService: ObservableObject {
    @Published var suggestions: [SearchSuggestion] = []
    @Published var isLoading: Bool = false

    private struct CacheKey: Hashable {
        let query: String
        let searchEngine: URLInputResolver.SearchEngine
        let allowsRemoteSuggestions: Bool
    }

    private var currentTask: Task<Void, Never>?
    private let session: URLSession
    private var cache: [CacheKey: [SearchSuggestion]] = [:]

    private static let commonDomains: [String] = [
        "google.com", "youtube.com", "github.com", "reddit.com", "twitter.com",
        "x.com", "wikipedia.org", "amazon.com", "apple.com", "facebook.com",
        "instagram.com", "linkedin.com", "netflix.com", "twitch.tv", "stackoverflow.com",
        "news.ycombinator.com", "chatgpt.com", "openai.com", "threads.net", "spotify.com",
        "figma.com", "notion.so", "medium.com", "discord.com", "nytimes.com", "cnn.com",
        "ebay.com", "duckduckgo.com"
    ]

    private static let commonTLDs: [String] = [
        ".com", ".org", ".net", ".io", ".dev", ".app", ".ai", ".co", ".edu", ".gov", ".me", ".tv", ".info", ".so"
    ]

    init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 2.0
        config.httpMaximumConnectionsPerHost = 4
        self.session = URLSession(configuration: config)
    }

    func clear() {
        currentTask?.cancel()
        suggestions = []
        isLoading = false
    }

    func update(
        for query: String,
        history: [HistoryItem] = [],
        bookmarks: [BookmarkItem] = [],
        allowsRemoteSuggestions: Bool = true,
        openTabs: [TabItem] = []
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        currentTask?.cancel()

        guard !trimmed.isEmpty else {
            suggestions = []
            isLoading = false
            return
        }

        let queryLower = trimmed.lowercased()

        // --- @tabs prefix mode: only show matching open tabs, no remote fetch ---
        let tabPrefixes = ["@tabs ", "@tab ", "@t "]
        let isTabPrefix = tabPrefixes.contains(where: { queryLower.hasPrefix($0) })
            || ["@tabs", "@tab", "@t"].contains(queryLower)

        if isTabPrefix {
            let subQuery: String
            if let prefix = tabPrefixes.first(where: { queryLower.hasPrefix($0) }) {
                subQuery = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            } else {
                subQuery = ""
            }

            let tabResults: [SearchSuggestion]
            if subQuery.isEmpty {
                tabResults = Array(openTabs.prefix(8).map { SearchSuggestion(tab: $0) })
            } else {
                tabResults = openTabs
                    .filter { tab in
                        let titleMatch = tab.title.lowercased().contains(subQuery)
                        let hostMatch = (tab.url?.host?.lowercased() ?? "").contains(subQuery)
                        let urlMatch = (tab.url?.absoluteString.lowercased() ?? "").contains(subQuery)
                        return titleMatch || hostMatch || urlMatch
                    }
                    .prefix(8)
                    .map { SearchSuggestion(tab: $0) }
            }

            self.suggestions = tabResults
            self.isLoading = false
            return
        }

        let searchEngine = URLInputResolver.selectedSearchEngine
        let cacheKey = CacheKey(
            query: queryLower,
            searchEngine: searchEngine,
            allowsRemoteSuggestions: allowsRemoteSuggestions
        )

        // 1. Check in-memory cache for instant hit (only when no open tabs to inject)
        if openTabs.isEmpty, let cached = cache[cacheKey], !cached.isEmpty {
            self.suggestions = cached
            self.isLoading = false
            return
        }

        // 2. Synchronously apply local matches immediately with 0ms latency
        var localMatches = getLocalSuggestions(for: queryLower, rawQuery: trimmed, history: history, bookmarks: bookmarks)

        // Prepend up to 2 matching open tabs (by title or URL host) before other results
        if !openTabs.isEmpty {
            let matchingTabs = openTabs
                .filter { tab in
                    let titleMatch = tab.title.lowercased().contains(queryLower)
                    let hostMatch = (tab.url?.host?.lowercased() ?? "").contains(queryLower)
                    return titleMatch || hostMatch
                }
                .prefix(2)
                .map { SearchSuggestion(tab: $0) }
            localMatches.insert(contentsOf: matchingTabs, at: 0)
        }

        // Append bang discoverability suggestions when query starts with "!"
        if queryLower.hasPrefix("!") {
            let bangQuery = queryLower.count > 1 ? String(queryLower.dropFirst()) : ""
            let bangMatches = SiteSearchProvider.all
                .filter { provider in
                    if bangQuery.isEmpty { return true }
                    return provider.triggers.contains { $0.hasPrefix(bangQuery) }
                }
                .prefix(5)
                .map { provider -> SearchSuggestion in
                    let trigger = provider.triggers.first ?? provider.id
                    return SearchSuggestion(
                        text: "!" + trigger,
                        title: provider.name,
                        subtitle: provider.host,
                        systemImage: provider.iconName,
                        badgeText: "!" + trigger
                    )
                }
            localMatches.append(contentsOf: bangMatches)
        }

        self.suggestions = localMatches
        self.isLoading = true

        guard allowsRemoteSuggestions, searchEngine == .google else {
            self.isLoading = false
            return
        }

        // 3. Fast debounce (80ms) for remote network completions
        currentTask = Task { [weak self] in
            guard let self = self else { return }

            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            guard URLInputResolver.selectedSearchEngine == searchEngine else {
                self.isLoading = false
                return
            }

            let results = await self.fetchSuggestions(
                for: trimmed,
                queryLower: queryLower,
                localMatches: localMatches,
                searchEngine: searchEngine
            )
            guard !Task.isCancelled else { return }

            if openTabs.isEmpty {
                self.cache[cacheKey] = results
            }
            self.suggestions = results
            self.isLoading = false
        }
    }

    /// Returns the ghost autocomplete text remainder if a top domain, internal page, or history host matches.
    func ghostRemainder(for query: String, history: [HistoryItem] = []) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        // 1. Check history display hosts
        for item in history {
            if let host = item.displayHost?.lowercased(), host.hasPrefix(trimmed) && host != trimmed {
                return String(host.dropFirst(trimmed.count))
            }
        }

        // 2. Check common domains
        for domain in Self.commonDomains {
            if domain.hasPrefix(trimmed) && domain != trimmed {
                return String(domain.dropFirst(trimmed.count))
            }
        }

        // 3. Check internal pages
        let internalPages = ["lotus://history", "lotus://downloads", "lotus://settings", "lotus://bookmarks", "lotus://shortcuts"]
        for page in internalPages {
            if page.hasPrefix(trimmed) && page != trimmed {
                return String(page.dropFirst(trimmed.count))
            }
        }

        return nil
    }

    /// Returns the full string of the ghost autocomplete match.
    func fullGhostMatch(for query: String, history: [HistoryItem] = []) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        // 1. Check history display hosts
        for item in history {
            if let host = item.displayHost?.lowercased(), host.hasPrefix(trimmed) && host != trimmed {
                return host
            }
        }

        // 2. Check common domains
        for domain in Self.commonDomains {
            if domain.hasPrefix(trimmed) && domain != trimmed {
                return domain
            }
        }

        // 3. Check internal pages
        let internalPages = ["lotus://history", "lotus://downloads", "lotus://settings", "lotus://bookmarks", "lotus://shortcuts"]
        for page in internalPages {
            if page.hasPrefix(trimmed) && page != trimmed {
                return page
            }
        }

        return nil
    }

    private func normalizeKey(_ urlString: String) -> String {
        var str = urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if str.hasPrefix("https://") {
            str = String(str.dropFirst(8))
        } else if str.hasPrefix("http://") {
            str = String(str.dropFirst(7))
        }
        if str.hasPrefix("www.") {
            str = String(str.dropFirst(4))
        }
        while str.hasSuffix("/") {
            str = String(str.dropLast())
        }
        return str
    }

    private func getLocalSuggestions(
        for queryLower: String,
        rawQuery: String,
        history: [HistoryItem],
        bookmarks: [BookmarkItem] = []
    ) -> [SearchSuggestion] {
        var results: [SearchSuggestion] = []
        var seen = Set<String>()
        var seenNormalized = Set<String>()
        var seenDisplayKeys = Set<String>()
        var seenHostsWithGenericTitle = Set<String>()

        // 1. Check internal Lotus pages (e.g. Settings, Bookmarks, Shortcuts)
        let internalPages: [(aliases: [String], text: String, title: String, icon: String)] = [
            (aliases: ["settings", "lotus://settings", "lotus:settings", "preferences"], text: "lotus://settings", title: "Settings", icon: "gearshape"),
            (aliases: ["bookmarks", "lotus://bookmarks", "lotus:bookmarks"], text: "lotus://bookmarks", title: "Bookmarks", icon: "bookmark.fill"),
            (aliases: ["shortcuts", "lotus://shortcuts", "lotus:shortcuts", "keyboard shortcuts", "keyboardshortcuts", "keybindings", "hotkeys"], text: "lotus://shortcuts", title: "Keyboard Shortcuts", icon: "keyboard"),
            (aliases: ["history", "lotus://history", "lotus:history"], text: "lotus://history", title: "History", icon: "clock"),
            (aliases: ["downloads", "lotus://downloads", "lotus:downloads"], text: "lotus://downloads", title: "Downloads", icon: "arrow.down.circle")
        ]

        for page in internalPages {
            if page.aliases.contains(where: { $0.hasPrefix(queryLower) || queryLower.hasPrefix($0) || $0.contains(queryLower) }) {
                results.append(SearchSuggestion(
                    text: page.text,
                    title: page.title,
                    isURL: true,
                    isInternalPage: true,
                    systemImage: page.icon,
                    badgeText: "Lotus Page"
                ))
                seen.insert(page.text.lowercased())
                seenNormalized.insert(normalizeKey(page.text))
                seenDisplayKeys.insert(page.title.lowercased())
            }
        }

        // 2. Check saved bookmarks
        for item in bookmarks {
            let itemUrlString = item.url.absoluteString
            let itemUrlLower = itemUrlString.lowercased()
            let normalizedURL = normalizeKey(itemUrlString)
            guard !normalizedURL.isEmpty else { continue }

            let titleLower = item.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let hostLower = (item.url.host ?? "").lowercased()

            let matchesTitle = !titleLower.isEmpty && titleLower.contains(queryLower)
            let matchesHost = !hostLower.isEmpty && hostLower.contains(queryLower)
            let matchesURL = itemUrlLower.contains(queryLower) || normalizedURL.contains(queryLower)

            if matchesTitle || matchesHost || matchesURL {
                if !seen.contains(itemUrlLower) && !seenNormalized.contains(normalizedURL) {
                    seen.insert(itemUrlLower)
                    seenNormalized.insert(normalizedURL)
                    results.append(SearchSuggestion(
                        text: itemUrlString,
                        title: item.title.isEmpty ? hostLower : item.title,
                        subtitle: item.displayDomain,
                        isURL: true,
                        systemImage: "bookmark.fill",
                        badgeText: "Bookmark",
                        faviconURL: item.faviconURL
                    ))
                }
            }
        }

        // 2. Check browsing history matches (reverse chronological for recency)
        var historyMatches: [SearchSuggestion] = []

        for item in history.reversed() {
            let itemUrlString = item.url.absoluteString
            let itemUrlLower = itemUrlString.lowercased()
            let normalizedURL = normalizeKey(itemUrlString)
            guard !normalizedURL.isEmpty else { continue }

            let titleLower = item.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let hostLower = (item.displayHost ?? item.url.host ?? "").lowercased()
            let isGenericTitle = titleLower.isEmpty || titleLower == hostLower || titleLower == normalizedURL

            // If this item has no specific page title (just the hostname), only allow ONE entry per host
            if isGenericTitle {
                if seenHostsWithGenericTitle.contains(hostLower) {
                    continue
                }
            }

            let displayTitle = isGenericTitle ? (item.displayHost ?? hostLower) : item.title
            let subtitle = item.displayHost ?? hostLower

            let displayKey = "\(displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(subtitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
            let titleOnlyKey = displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            guard !seenDisplayKeys.contains(displayKey),
                  !seenDisplayKeys.contains(titleOnlyKey),
                  !seenNormalized.contains(normalizedURL),
                  !seen.contains(itemUrlLower) else {
                continue
            }

            let matchesTitle = !titleLower.isEmpty && titleLower.contains(queryLower)
            let matchesHost = !hostLower.isEmpty && hostLower.contains(queryLower)
            let matchesURL = itemUrlLower.contains(queryLower) || normalizedURL.contains(queryLower)

            if matchesTitle || matchesHost || matchesURL {
                seenDisplayKeys.insert(displayKey)
                seenDisplayKeys.insert(titleOnlyKey)
                if isGenericTitle {
                    seenHostsWithGenericTitle.insert(hostLower)
                }
                seenNormalized.insert(normalizedURL)
                seen.insert(itemUrlLower)
                seen.insert(normalizedURL)
                if !hostLower.isEmpty {
                    seen.insert(hostLower)
                    seenNormalized.insert(normalizeKey(hostLower))
                }

                historyMatches.append(SearchSuggestion(
                    text: itemUrlString,
                    title: displayTitle,
                    subtitle: subtitle,
                    isURL: true,
                    isHistory: true,
                    systemImage: "clock",
                    badgeText: "History",
                    faviconURL: item.faviconURL
                ))

                if historyMatches.count >= 4 { break }
            }
        }
        results.append(contentsOf: historyMatches)

        // 3. Check common domains
        for domain in Self.commonDomains {
            let normDomain = normalizeKey(domain)
            let domainLower = domain.lowercased()
            if domain.hasPrefix(queryLower) && domain != queryLower {
                if !seen.contains(domainLower) && !seenNormalized.contains(normDomain) && !seenDisplayKeys.contains(domainLower) {
                    results.append(SearchSuggestion(text: domain, isURL: true))
                    seen.insert(domainLower)
                    seenNormalized.insert(normDomain)
                    seenDisplayKeys.insert(domainLower)
                    if results.count >= 6 { break }
                }
            }
        }

        let hasTLD = Self.commonTLDs.contains { queryLower.hasSuffix($0) || queryLower.contains($0 + "/") }
        let isDirectURL = queryLower.hasPrefix("http://") || queryLower.hasPrefix("https://") || queryLower.hasPrefix("lotus://") || hasTLD

        let normRaw = normalizeKey(rawQuery)
        let rawLower = rawQuery.lowercased()
        if isDirectURL && !seen.contains(rawLower) && !seenNormalized.contains(normRaw) && !seenDisplayKeys.contains(rawLower) {
            results.append(SearchSuggestion(text: rawQuery, isURL: true))
            seen.insert(rawLower)
            seenNormalized.insert(normRaw)
            seenDisplayKeys.insert(rawLower)
        }

        return results
    }

    private func fetchSuggestions(
        for query: String,
        queryLower: String,
        localMatches: [SearchSuggestion],
        searchEngine: URLInputResolver.SearchEngine
    ) async -> [SearchSuggestion] {
        var results: [SearchSuggestion] = localMatches
        var seen = Set<String>(localMatches.map { $0.text.lowercased() })
        for match in localMatches {
            seen.insert(normalizeKey(match.text))
            if let title = match.title {
                seen.insert(title.lowercased())
            }
        }

        guard searchEngine == .google else { return results }

        var components = URLComponents(string: "https://suggestqueries.google.com/complete/search")
        components?.queryItems = [
            URLQueryItem(name: "client", value: "firefox"),
            URLQueryItem(name: "q", value: query)
        ]
        guard let url = components?.url else {
            return results
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return results
            }

            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any],
                  json.count > 1,
                  let items = json[1] as? [String] else {
                return results
            }

            for item in items {
                let trimmedItem = item.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedItem.isEmpty else { continue }
                let lowerItem = trimmedItem.lowercased()
                let normItem = normalizeKey(trimmedItem)
                guard !seen.contains(lowerItem), !seen.contains(normItem) else { continue }
                seen.insert(lowerItem)
                seen.insert(normItem)

                let isItemURL = lowerItem.hasPrefix("http://") ||
                                lowerItem.hasPrefix("https://") ||
                                Self.commonTLDs.contains { lowerItem.hasSuffix($0) }

                results.append(SearchSuggestion(text: trimmedItem, isURL: isItemURL))
                if results.count >= 6 { break }
            }
        } catch {
            // Silently retain local matches on error
        }

        return results
    }
}
