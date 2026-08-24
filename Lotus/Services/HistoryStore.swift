//
//  HistoryStore.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import Foundation

/// File-based browsing history persistence in Application Support.
///
/// Follows the same atomic-write + versioned-envelope pattern as `SessionStore`.
/// Entries are pruned to `maxEntries` on every save to keep the file manageable.
final class HistoryStore {

    /// Current schema version of the on-disk format.
    static let currentVersion = 1

    /// Maximum number of history entries retained on disk.
    static let maxEntries = 10_000

    private let directory: URL
    private let fileURL: URL
    private let saveQueue = DispatchQueue(label: "lotus.history.save", qos: .utility)

    init(directory: URL? = nil) {
        let base = directory ?? SessionStore.defaultDirectory()
        self.directory = base
        self.fileURL = base.appendingPathComponent("history.json")
    }

    // MARK: - Loading

    func load() -> [HistoryItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            return envelope.entries
        } catch {
            NSLog("[Lotus] History file is unreadable (\(error.localizedDescription))")
            return []
        }
    }

    // MARK: - Saving

    func save(_ entries: [HistoryItem]) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let pruned = entries.count > Self.maxEntries
                ? Array(entries.suffix(Self.maxEntries))
                : entries
            let envelope = Envelope(version: Self.currentVersion, entries: pruned)
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("[Lotus] Failed to save history: \(error.localizedDescription)")
        }
    }

    /// Appends or merges a new entry and saves asynchronously.
    func addEntry(title: String, url: URL, to entries: inout [HistoryItem]) {
        if let last = entries.last,
           last.url == url || (last.host == url.host && Date().timeIntervalSince(last.visitedAt) < 3.0) {
            let preferredTitle = !title.isEmpty && title != url.host ? title : last.title
            entries[entries.count - 1] = HistoryItem(id: last.id, title: preferredTitle, url: url, visitedAt: Date())
        } else {
            let entry = HistoryItem(title: title, url: url)
            entries.append(entry)
            if entries.count > Self.maxEntries {
                entries.removeFirst(entries.count - Self.maxEntries)
            }
        }
        let snapshot = entries
        saveQueue.async { [weak self] in
            self?.save(snapshot)
        }
    }

    /// Updates the title of the most recent history entry matching the given URL.
    func updateTitle(_ title: String, for url: URL, in entries: inout [HistoryItem]) {
        guard !title.isEmpty else { return }
        for i in entries.indices.reversed() {
            if entries[i].url == url || (entries[i].url.host == url.host && entries[i].title == entries[i].displayHost) {
                entries[i] = HistoryItem(id: entries[i].id, title: title, url: entries[i].url, visitedAt: entries[i].visitedAt)
                let snapshot = entries
                saveQueue.async { [weak self] in
                    self?.save(snapshot)
                }
                return
            }
        }
    }

    /// Removes specific entries by id and saves asynchronously.
    func removeEntries(ids: Set<UUID>, from entries: inout [HistoryItem]) {
        entries.removeAll(where: { ids.contains($0.id) })
        let snapshot = entries
        saveQueue.async { [weak self] in
            self?.save(snapshot)
        }
    }

    /// Clears all history and saves asynchronously.
    func clearAll(entries: inout [HistoryItem]) {
        entries.removeAll()
        let snapshot = entries
        saveQueue.async { [weak self] in
            self?.save(snapshot)
        }
    }

    // MARK: - On-disk format

    private struct Envelope: Codable {
        let version: Int
        let entries: [HistoryItem]
    }
}
