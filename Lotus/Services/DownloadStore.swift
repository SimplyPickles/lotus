//
//  DownloadStore.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import Foundation

/// File-based downloads history persistence in Application Support.
///
/// Follows the same atomic-write + versioned-envelope pattern as `HistoryStore`.
final class DownloadStore {

    /// Current schema version of the on-disk format.
    static let currentVersion = 1

    /// Maximum number of download entries retained on disk.
    static let maxEntries = 1_000

    private let directory: URL
    private let fileURL: URL
    private let saveQueue = DispatchQueue(label: "lotus.downloads.save", qos: .utility)

    init(directory: URL? = nil) {
        let base = directory ?? SessionStore.defaultDirectory()
        self.directory = base
        self.fileURL = base.appendingPathComponent("downloads.json")
    }

    // MARK: - Loading

    func load() -> [DownloadItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            return envelope.entries
        } catch {
            NSLog("[Lotus] Downloads file is unreadable (\(error.localizedDescription))")
            return []
        }
    }

    // MARK: - Saving

    func save(_ entries: [DownloadItem]) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let pruned = entries.count > Self.maxEntries
                ? Array(entries.suffix(Self.maxEntries))
                : entries
            let envelope = Envelope(version: Self.currentVersion, entries: pruned)
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("[Lotus] Failed to save downloads: \(error.localizedDescription)")
        }
    }

    /// Appends or updates an entry and saves asynchronously.
    func upsert(_ item: DownloadItem, in entries: inout [DownloadItem]) {
        if let index = entries.firstIndex(where: { $0.id == item.id }) {
            entries[index] = item
        } else {
            entries.insert(item, at: 0)
        }
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        let snapshot = entries
        saveQueue.async { [weak self] in
            self?.save(snapshot)
        }
    }

    /// Removes specific entries by id and saves asynchronously.
    func removeEntries(ids: Set<UUID>, from entries: inout [DownloadItem]) {
        entries.removeAll(where: { ids.contains($0.id) })
        let snapshot = entries
        saveQueue.async { [weak self] in
            self?.save(snapshot)
        }
    }

    /// Clears completed/failed downloads and saves asynchronously.
    func clearCompleted(from entries: inout [DownloadItem]) {
        entries.removeAll(where: { $0.state != .downloading })
        let snapshot = entries
        saveQueue.async { [weak self] in
            self?.save(snapshot)
        }
    }

    /// Clears all downloads and saves asynchronously.
    func clearAll(entries: inout [DownloadItem]) {
        entries.removeAll()
        let snapshot = entries
        saveQueue.async { [weak self] in
            self?.save(snapshot)
        }
    }

    // MARK: - On-disk format

    private struct Envelope: Codable {
        let version: Int
        let entries: [DownloadItem]
    }
}
