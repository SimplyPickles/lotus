//
//  BrowserState+Bookmarks.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI
import AppKit

extension BrowserState {

    func isBookmarked(url: URL?) -> Bool {
        guard let url = url else { return false }
        let norm = url.absoluteString.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return bookmarks.contains {
            $0.url.absoluteString.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/")) == norm
        }
    }

    func bookmark(for url: URL?) -> BookmarkItem? {
        guard let url = url else { return nil }
        let norm = url.absoluteString.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return bookmarks.first {
            $0.url.absoluteString.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/")) == norm
        }
    }

    func addOrUpdateBookmark(
        title: String,
        url: URL,
        faviconURL: URL? = nil,
        previewSnippet: String? = nil
    ) {
        let norm = url.absoluteString.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let idx = bookmarks.firstIndex(where: {
            $0.url.absoluteString.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/")) == norm
        }) {
            bookmarks[idx].title = title
            bookmarks[idx].faviconURL = faviconURL ?? bookmarks[idx].faviconURL
            if let snippet = previewSnippet {
                bookmarks[idx].previewSnippet = snippet
            }
        } else {
            let item = BookmarkItem(
                title: title,
                url: url,
                faviconURL: faviconURL,
                createdAt: Date(),
                previewSnippet: previewSnippet
            )
            bookmarks.insert(item, at: 0)
        }
        bookmarkStore.save(bookmarks)
    }

    func toggleBookmark(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        guard let currentTab = tab(for: targetId), let url = currentTab.url, !url.isLotusPage else { return }

        let norm = url.absoluteString.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let idx = bookmarks.firstIndex(where: {
            $0.url.absoluteString.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/")) == norm
        }) {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                bookmarks.remove(at: idx)
                bookmarkStore.save(bookmarks)
            }
        } else {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                addOrUpdateBookmark(
                    title: currentTab.title.isEmpty ? (url.host ?? "Page") : currentTab.title,
                    url: url,
                    faviconURL: currentTab.faviconURL
                )
            }
        }
    }

    func removeBookmark(id: UUID) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            bookmarks.removeAll { $0.id == id }
            bookmarkStore.save(bookmarks)
        }
    }

    func exportBookmarksHTML() -> String {
        var html = """
        <!DOCTYPE NETSCAPE-Bookmark-file-1>
        <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
        <TITLE>Lotus Bookmarks</TITLE>
        <H1>Bookmarks</H1>
        <DL><p>
        """
        for item in bookmarks {
            html += "    <DT><A HREF=\"\(item.url.absoluteString)\">\(item.title)</A>\n"
        }
        html += "</DL><p>\n"
        return html
    }
}
