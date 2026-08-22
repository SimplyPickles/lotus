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

    init(text: String, isURL: Bool = false) {
        self.id = text
        self.text = text
        self.isURL = isURL
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

        // 2. Immediately populate local matching suggestions with 0ms latency
        let localMatches = getLocalSuggestions(for: queryLower, rawQuery: trimmed)
        self.suggestions = localMatches
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

    private func getLocalSuggestions(for queryLower: String, rawQuery: String) -> [SearchSuggestion] {
        var results: [SearchSuggestion] = []
        var seen = Set<String>()

        for domain in Self.commonDomains {
            if domain.hasPrefix(queryLower) && domain != queryLower {
                results.append(SearchSuggestion(text: domain, isURL: true))
                seen.insert(domain)
                if results.count >= 2 { break }
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
