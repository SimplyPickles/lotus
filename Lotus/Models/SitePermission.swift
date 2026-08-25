//
//  SitePermission.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import Foundation

enum SitePermissionType: String, Codable, CaseIterable, Identifiable {
    case camera
    case microphone
    case geolocation
    case notifications

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .geolocation: return "Location"
        case .notifications: return "Notifications"
        }
    }

    var iconName: String {
        switch self {
        case .camera: return "video"
        case .microphone: return "mic"
        case .geolocation: return "location"
        case .notifications: return "bell"
        }
    }
}

enum SitePermissionState: String, Codable {
    case prompt
    case allow
    case deny
}

final class SitePermissionStore {
    static let shared = SitePermissionStore()
    private let storageKey = "lotus.browser.site_permissions"
    private var permissions: [String: [String: String]] = [:]

    private init() {
        if let data = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: [String: String]] {
            self.permissions = data
        }
    }

    private func normalize(domain: String) -> String {
        domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func state(for domain: String, type: SitePermissionType) -> SitePermissionState {
        let key = normalize(domain: domain)
        guard let stateStr = permissions[key]?[type.rawValue],
              let state = SitePermissionState(rawValue: stateStr) else {
            return .prompt
        }
        return state
    }

    func set(state: SitePermissionState, for domain: String, type: SitePermissionType) {
        let key = normalize(domain: domain)
        var domainPerms = permissions[key] ?? [:]
        domainPerms[type.rawValue] = state.rawValue
        permissions[key] = domainPerms
        UserDefaults.standard.set(permissions, forKey: storageKey)
    }

    func resetPermissions(for domain: String) {
        let key = normalize(domain: domain)
        permissions.removeValue(forKey: key)
        UserDefaults.standard.set(permissions, forKey: storageKey)
    }
}
