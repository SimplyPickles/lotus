//
//  BookmarkStore.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import Foundation

/// Persistent store for user bookmarks.
final class BookmarkStore {
    private let storageKey = "lotus.browser.bookmarks"

    func load() -> [BookmarkItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return BookmarkStore.defaultBookmarks()
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([BookmarkItem].self, from: data)
        } catch {
            return BookmarkStore.defaultBookmarks()
        }
    }

    func save(_ items: [BookmarkItem]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {}
    }

    private static func defaultBookmarks() -> [BookmarkItem] {
        [
            BookmarkItem(
                title: "Apple",
                url: URL(string: "https://www.apple.com")!
            ),
            BookmarkItem(
                title: "GitHub",
                url: URL(string: "https://github.com")!
            ),
            BookmarkItem(
                title: "Hacker News",
                url: URL(string: "https://news.ycombinator.com")!
            )
        ]
    }
}
