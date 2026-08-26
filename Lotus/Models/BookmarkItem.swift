//
//  BookmarkItem.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import Foundation

/// A saved bookmark item.
struct BookmarkItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var url: URL
    var faviconURL: URL?
    var createdAt: Date
    var previewSnippet: String?
    var profileId: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        faviconURL: URL? = nil,
        createdAt: Date = Date(),
        previewSnippet: String? = nil,
        profileId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.faviconURL = faviconURL
        self.createdAt = createdAt
        self.previewSnippet = previewSnippet
        self.profileId = profileId
    }

    var displayDomain: String {
        url.host ?? url.absoluteString
    }
}
