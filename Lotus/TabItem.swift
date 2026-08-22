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

    init(id: UUID = UUID(), title: String, url: URL? = nil, isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.url = url
        self.isPinned = isPinned
    }

    var faviconURL: URL? {
        if url?.absoluteString.starts(with: "lotus://") == true { return nil }
        guard let host = url?.host, !host.isEmpty else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
    }
}

extension TabItem {
    static let samples: [TabItem] = [
        TabItem(title: "Apple", url: URL(string: "https://www.apple.com"), isPinned: true),
        TabItem(title: "Lotus", url: URL(string: "https://apple.com"), isPinned: true),
        TabItem(title: "New Tab", url: URL(string: "lotus://newtab"), isPinned: false),
    ]
}
