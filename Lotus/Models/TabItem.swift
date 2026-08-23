//
//  TabItem.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import Foundation

struct TabItem: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    var title: String
    var url: URL?
    var isPinned: Bool
    /// Sidebar folder this tab belongs to, if any. Pinned tabs never carry a
    /// folder (folders cannot be pinned). Optional so old sessions decode.
    var folderId: UUID?

    init(id: UUID = UUID(), title: String, url: URL? = nil, isPinned: Bool = false, folderId: UUID? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.isPinned = isPinned
        self.folderId = folderId
    }

    var faviconURL: URL? {
        if url?.absoluteString.starts(with: "lotus://") == true { return nil }
        guard let host = url?.host, !host.isEmpty else { return nil }
        // Fetch the favicon directly from the site to avoid leaking visited hosts
        // to a third-party proxy; the extractor falls back to the proxy only if
        // the direct request fails.
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/favicon.ico"
        return components.url
    }
}

extension TabItem {
    static let samples: [TabItem] = [
        TabItem(title: "Apple", url: URL(string: "https://www.apple.com"), isPinned: true),
    ]
}
