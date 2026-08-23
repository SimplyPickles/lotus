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
    private let saveQueue = DispatchQueue(label: "lotus.session.save", qos: .utility)

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

    /// Synchronous save, ensuring data is written to disk before returning.
    func save(_ session: BrowserSessionData) {
        saveQueue.sync {
            performSave(session)
        }
    }

    /// Asynchronous save on the dedicated persistence queue.
    func saveAsync(_ session: BrowserSessionData) {
        saveQueue.async { [weak self] in
            self?.performSave(session)
        }
    }

    private func performSave(_ session: BrowserSessionData) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let envelope = Envelope(version: Self.currentVersion, session: session)
            let data = try JSONEncoder().encode(envelope)

            // Promote the current primary to backup before overwriting it if valid.
            if FileManager.default.fileExists(atPath: primaryURL.path),
               let existingData = try? Data(contentsOf: primaryURL),
               !existingData.isEmpty {
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
        saveQueue.sync {
            migrateFromUserDefaultsIfNeededSync()
            return loadSession(from: primaryURL) ?? loadSession(from: backupURL)
        }
    }

    private func loadSession(from url: URL) -> BrowserSessionData? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            return envelope.session
        } catch {
            // Fallback: try decoding unversioned BrowserSessionData for backward compatibility
            if let legacySession = try? JSONDecoder().decode(BrowserSessionData.self, from: data) {
                return legacySession
            }
            NSLog("[Lotus] Session file at \(url.lastPathComponent) is unreadable (\(error.localizedDescription)); trying next source")
            return nil
        }
    }

    // MARK: - Migration

    /// One-time import of legacy `UserDefaults` session data so existing users
    /// don't lose their tabs.
    func migrateFromUserDefaultsIfNeeded(defaults: UserDefaults = .standard) {
        saveQueue.sync {
            migrateFromUserDefaultsIfNeededSync(defaults: defaults)
        }
    }

    private func migrateFromUserDefaultsIfNeededSync(defaults: UserDefaults = .standard) {
        guard !FileManager.default.fileExists(atPath: primaryURL.path) && !FileManager.default.fileExists(atPath: backupURL.path),
              let data = defaults.data(forKey: "lotus.browser.session"),
              let session = try? JSONDecoder().decode(BrowserSessionData.self, from: data) else { return }
        performSave(session)
        defaults.removeObject(forKey: "lotus.browser.session")
        NSLog("[Lotus] Successfully migrated legacy UserDefaults session to Application Support file store")
    }

    // MARK: - On-disk format

    private struct Envelope: Codable {
        let version: Int
        let session: BrowserSessionData
    }
}
