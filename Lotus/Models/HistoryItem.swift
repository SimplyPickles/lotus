//
//  HistoryItem.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import Foundation

/// A single recorded page visit for the browsing history.
struct HistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let url: URL
    let visitedAt: Date
    /// Cached host for fast grouping / display.
    let host: String?

    init(id: UUID = UUID(), title: String, url: URL, visitedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.visitedAt = visitedAt
        self.host = url.host
    }

    /// Prettified host string for display (strips "www." prefix).
    var displayHost: String? {
        guard let host = host, !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Favicon fetched directly from the site (same pattern as `TabItem`).
    var faviconURL: URL? {
        guard let host = host, !host.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/favicon.ico"
        return components.url
    }
}
