//
//  ProfileStore.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import Foundation
import WebKit

/// File-based persistence for user profiles in Application Support.
final class ProfileStore {

    /// Current schema version of the on-disk format.
    static let currentVersion = 1

    private let directory: URL
    private let fileURL: URL
    private let saveQueue = DispatchQueue(label: "lotus.profiles.save", qos: .utility)

    init(directory: URL? = nil) {
        let base = directory ?? SessionStore.defaultDirectory()
        self.directory = base
        self.fileURL = base.appendingPathComponent("profiles.json")
    }

    // MARK: - Loading

    /// Loads saved profiles or returns default seed profile if none exist.
    func load() -> [Profile] {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            let defaults = defaultProfiles()
            save(defaults)
            return defaults
        }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            var loaded = envelope.profiles
            if loaded.isEmpty {
                loaded = defaultProfiles()
                save(loaded)
            }
            // Ensure at least one profile is marked as default
            if !loaded.contains(where: { $0.isDefault }) {
                loaded[0].isDefault = true
            }
            return loaded
        } catch {
            NSLog("[Lotus] Profiles file is unreadable (\(error.localizedDescription)); using default")
            let defaults = defaultProfiles()
            save(defaults)
            return defaults
        }
    }

    // MARK: - Saving

    /// Synchronous save of profiles to disk.
    func save(_ profiles: [Profile]) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let envelope = Envelope(version: Self.currentVersion, profiles: profiles)
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("[Lotus] Failed to save profiles: \(error.localizedDescription)")
        }
    }

    /// Asynchronous save of profiles to disk.
    func saveAsync(_ profiles: [Profile]) {
        let snapshot = profiles
        saveQueue.async { [weak self] in
            self?.save(snapshot)
        }
    }

    // MARK: - WebKit Website Data Store Deletion

    /// Permanently removes the WebKit persistent data store associated with a custom profile ID.
    func deleteDataStore(for profileId: UUID, completion: (() -> Void)? = nil) {
        guard profileId != Profile.defaultProfileId else {
            completion?()
            return
        }
        if #available(macOS 14.0, *) {
            WKWebsiteDataStore.remove(forIdentifier: profileId) { error in
                if let error = error {
                    NSLog("[Lotus] Failed to delete website data store for profile \(profileId): \(error.localizedDescription)")
                } else {
                    NSLog("[Lotus] Successfully removed website data store for profile \(profileId)")
                }
                DispatchQueue.main.async {
                    completion?()
                }
            }
        } else {
            completion?()
        }
    }

    // MARK: - Defaults

    private func defaultProfiles() -> [Profile] {
        [Profile.defaultProfile]
    }

    // MARK: - On-disk Format

    private struct Envelope: Codable {
        let version: Int
        let profiles: [Profile]
    }
}
