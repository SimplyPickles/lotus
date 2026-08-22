//
//  SessionStore.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation

/// File-based session persistence in Application Support.
///
/// Writes are atomic and versioned; the previous good snapshot is kept as a
/// backup so a corrupted primary file can be recovered instead of silently
/// falling back to sample tabs.
final class SessionStore {

    /// Current schema version of the on-disk format.
    static let currentVersion = 1

    private let directory: URL
    private let primaryURL: URL
    private let backupURL: URL

    init(directory: URL? = nil) {
        let base = directory ?? Self.defaultDirectory()
        self.directory = base
        self.primaryURL = base.appendingPathComponent("session.json")
        self.backupURL = base.appendingPathComponent("session.backup.json")
    }

    static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Lotus", isDirectory: true)
    }

    // MARK: - Saving

    func save(_ session: BrowserSessionData) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let envelope = Envelope(version: Self.currentVersion, session: session)
            let data = try JSONEncoder().encode(envelope)

            // Promote the current primary to backup before overwriting it.
            if FileManager.default.fileExists(atPath: primaryURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
                try? FileManager.default.copyItem(at: primaryURL, to: backupURL)
            }
            try data.write(to: primaryURL, options: [.atomic])
        } catch {
            NSLog("[Lotus] Failed to save session: \(error.localizedDescription)")
        }
    }

    // MARK: - Loading

    /// Loads the most recent decodable snapshot, falling back to the backup if
    /// the primary is missing or corrupt. Returns nil only when neither file
    /// yields a usable session.
    func load() -> BrowserSessionData? {
        loadSession(from: primaryURL) ?? loadSession(from: backupURL)
    }

    private func loadSession(from url: URL) -> BrowserSessionData? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard !envelope.session.tabs.isEmpty else { return nil }
            return envelope.session
        } catch {
            NSLog("[Lotus] Session file at \(url.lastPathComponent) is unreadable (\(error.localizedDescription)); trying next source")
            return nil
        }
    }

    // MARK: - Migration

    /// One-time import of legacy `UserDefaults` session data so existing users
    /// don't lose their tabs.
    func migrateFromUserDefaultsIfNeeded(defaults: UserDefaults = .standard) {
        guard load() == nil,
              let data = defaults.data(forKey: "lotus.browser.session"),
              let session = try? JSONDecoder().decode(BrowserSessionData.self, from: data),
              !session.tabs.isEmpty else { return }
        save(session)
        defaults.removeObject(forKey: "lotus.browser.session")
    }

    // MARK: - On-disk format

    private struct Envelope: Codable {
        let version: Int
        let session: BrowserSessionData
    }
}
