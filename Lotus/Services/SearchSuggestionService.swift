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
    let isURL: Bool
    let isInternalPage: Bool
    let systemImage: String
    let badgeText: String?

    var displayText: String {
        switch text.lowercased() {
        case "lotus://history": return "History"
        case "lotus://downloads": return "Downloads"
        case "lotus://settings": return "Settings"
        default: return text
        }
    }

    init(
        text: String,
        isURL: Bool = false,
        isInternalPage: Bool = false,
        systemImage: String? = nil,
        badgeText: String? = nil
    ) {
        self.id = text
        self.text = text
        self.isURL = isURL
        self.isInternalPage = isInternalPage
        if let systemImage {
            self.systemImage = systemImage
        } else if isInternalPage {
            self.systemImage = "clock"
        } else if isURL {
            self.systemImage = "globe"
        } else {
            self.systemImage = "magnifyingglass"
        }
        if let badgeText {
            self.badgeText = badgeText
        } else if isInternalPage {
            self.badgeText = "Lotus Page"
        } else if isURL {
            self.badgeText = "Jump to URL"
        } else {
            self.badgeText = nil
        }
    }
}

@MainActor
final class SearchSuggestionService: ObservableObject {
    @Published var suggestions: [SearchSuggestion] = []
    @Published var isLoading: Bool = false

    private var currentTask: Task<Void, Never>?
    private let session: URLSession
    private var cache: [String: [SearchSuggestion]] = [:]

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

    func update(for query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        currentTask?.cancel()

        guard !trimmed.isEmpty else {
            suggestions = []
            isLoading = false
            return
        }

        let queryLower = trimmed.lowercased()

        // 1. Check in-memory cache for instant hit
        if let cached = cache[queryLower], !cached.isEmpty {
            self.suggestions = cached
            self.isLoading = false
            return
        }

        // 2. Keep the current list on screen while fetching — replacing it
        //    with the (usually shorter) local matches on every keystroke made
        //    the dropdown flicker. Local matches only seed an empty list.
        let localMatches = getLocalSuggestions(for: queryLower, rawQuery: trimmed)
        if self.suggestions.isEmpty {
            self.suggestions = localMatches
        }
        self.isLoading = true

        // 3. Fetch online completions immediately with zero debounce delay
        currentTask = Task { [weak self] in
            guard let self = self else { return }

            let results = await self.fetchSuggestions(for: trimmed, queryLower: queryLower, localMatches: localMatches)
            guard !Task.isCancelled else { return }

            self.cache[queryLower] = results
            self.suggestions = results
            self.isLoading = false
        }
    }

    func clear() {
        currentTask?.cancel()
        suggestions = []
        isLoading = false
    }

    /// Returns the ghost autocomplete text remainder if a top domain or history host matches.
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
        let internalPages = ["lotus://history", "lotus://downloads", "lotus://settings"]
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
        let internalPages = ["lotus://history", "lotus://downloads", "lotus://settings"]
        for page in internalPages {
            if page.hasPrefix(trimmed) && page != trimmed {
                return page
            }
        }

        return nil
    }

    private func getLocalSuggestions(for queryLower: String, rawQuery: String) -> [SearchSuggestion] {
        var results: [SearchSuggestion] = []
        var seen = Set<String>()

        // 1. Check internal Lotus pages (e.g. History)
        let internalPages: [(aliases: [String], text: String, title: String, icon: String)] = [
            (aliases: ["history", "lotus://history", "lotus:history"], text: "lotus://history", title: "History", icon: "clock"),
            (aliases: ["downloads", "lotus://downloads", "lotus:downloads"], text: "lotus://downloads", title: "Downloads", icon: "arrow.down.circle"),
            (aliases: ["settings", "lotus://settings", "lotus:settings"], text: "lotus://settings", title: "Settings", icon: "gearshape")
        ]

        for page in internalPages {
            if page.aliases.contains(where: { $0.hasPrefix(queryLower) || queryLower.hasPrefix($0) }) {
                results.append(SearchSuggestion(
                    text: page.text,
                    isURL: true,
                    isInternalPage: true,
                    systemImage: page.icon,
                    badgeText: "Lotus Page"
                ))
                seen.insert(page.text.lowercased())
            }
        }

        // 2. Check common domains
        for domain in Self.commonDomains {
            if domain.hasPrefix(queryLower) && domain != queryLower {
                if !seen.contains(domain) {
                    results.append(SearchSuggestion(text: domain, isURL: true))
                    seen.insert(domain)
                    if results.count >= 3 { break }
                }
            }
        }

        let hasTLD = Self.commonTLDs.contains { queryLower.hasSuffix($0) || queryLower.contains($0 + "/") }
        let isDirectURL = queryLower.hasPrefix("http://") || queryLower.hasPrefix("https://") || queryLower.hasPrefix("lotus://") || hasTLD

        if isDirectURL && !seen.contains(queryLower) {
            results.append(SearchSuggestion(text: rawQuery, isURL: true))
        }

        return results
    }

    private func fetchSuggestions(for query: String, queryLower: String, localMatches: [SearchSuggestion]) async -> [SearchSuggestion] {
        var results: [SearchSuggestion] = localMatches
        var seen = Set<String>(localMatches.map { $0.text.lowercased() })

        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&q=\(encoded)") else {
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
                guard !seen.contains(lowerItem) else { continue }
                seen.insert(lowerItem)

                let isItemURL = lowerItem.hasPrefix("http://") ||
                                lowerItem.hasPrefix("https://") ||
                                Self.commonTLDs.contains { lowerItem.hasSuffix($0) }

                results.append(SearchSuggestion(text: trimmedItem, isURL: isItemURL))
                if results.count >= 8 { break }
            }
        } catch {
            // Silently retain local matches on error
        }

        return results
    }
}
