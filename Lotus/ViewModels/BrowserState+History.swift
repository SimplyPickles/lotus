//
//  BrowserState+History.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import Foundation

extension BrowserState {

    // MARK: - History Recording

    /// Records a page visit in the browsing history.
    ///
    /// Called from the URL KVO observer whenever a committed navigation
    /// finalizes to a non-internal URL.
    func recordHistoryVisit(title: String, url: URL) {
        guard !isPrivate else { return }
        // Don't record internal pages or about: pages.
        guard url.scheme == "http" || url.scheme == "https" else { return }
        guard let host = url.host, !host.isEmpty else { return }

        historyStore.addEntry(title: title, url: url, to: &historyEntries)
    }

    /// Updates the title of the most recent browsing history visit for a URL.
    func updateHistoryTitle(title: String, for url: URL) {
        guard !isPrivate else { return }
        guard url.scheme == "http" || url.scheme == "https" else { return }
        historyStore.updateTitle(title, for: url, in: &historyEntries)
    }

    // MARK: - History Management

    /// Removes specific history entries by their ids.
    func removeHistoryEntries(ids: Set<UUID>) {
        historyStore.removeEntries(ids: ids, from: &historyEntries)
    }

    /// Clears all browsing history.
    func clearHistory() {
        historyStore.clearAll(entries: &historyEntries)
    }
}
