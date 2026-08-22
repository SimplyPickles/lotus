//
//  KeychainManager.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation
import Security

struct KeychainCredential: Identifiable {
    var id: String { "\(server):\(username)" }
    let server: String
    let username: String
    let password: String
}

final class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    /// Saves or updates an internet password credential in the macOS Keychain / iCloud Keychain.
    @discardableResult
    func saveCredential(server: String, username: String, password: String) -> Bool {
        guard !server.isEmpty, !username.isEmpty, !password.isEmpty else { return false }
        guard let passwordData = password.data(using: .utf8) else { return false }

        let cleanServer = sanitizeServer(server)

        // Query to check if credential already exists
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: cleanServer,
            kSecAttrAccount as String: username,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: passwordData
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        if updateStatus == errSecSuccess {
            return true
        }

        // Try adding with iCloud Keychain sync first
        var newAttributes: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: cleanServer,
            kSecAttrAccount as String: username,
            kSecValueData as String: passwordData,
            kSecAttrLabel as String: "Lotus Browser (\(cleanServer))",
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]

        var addStatus = SecItemAdd(newAttributes as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }

        // Fallback to local Keychain without sync flag
        newAttributes.removeValue(forKey: kSecAttrSynchronizable as String)
        addStatus = SecItemAdd(newAttributes as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    /// Fetches all credentials saved for a given server domain.
    func fetchCredentials(for server: String) -> [KeychainCredential] {
        guard !server.isEmpty else { return [] }
        let cleanServer = sanitizeServer(server)

        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: cleanServer,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let username = item[kSecAttrAccount as String] as? String,
                  let passwordData = item[kSecValueData as String] as? Data,
                  let password = String(data: passwordData, encoding: .utf8) else {
                return nil
            }
            return KeychainCredential(server: cleanServer, username: username, password: password)
        }
    }

    /// Deletes a saved credential for a server and username.
    @discardableResult
    func deleteCredential(server: String, username: String) -> Bool {
        let cleanServer = sanitizeServer(server)
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: cleanServer,
            kSecAttrAccount as String: username,
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Sanitizes host / URL into host string suitable for kSecAttrServer.
    private func sanitizeServer(_ server: String) -> String {
        if let url = URL(string: server), let host = url.host {
            return host.lowercased()
        }
        return server.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
