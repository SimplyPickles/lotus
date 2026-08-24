//
//  ContentBlockerConfig.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import Foundation

/// Persistent configuration and preferences for Shields / Content Blocker.
struct ContentBlockerSettings: Codable, Equatable {
    var isAdBlockingEnabled: Bool = true
    var blockTrackersEnabled: Bool = true
    var blockCosmeticElementsEnabled: Bool = true
    var fingerprintProtectionEnabled: Bool = true
    var allowlistedDomains: Set<String> = []
    var strictPopupBlockedDomains: Set<String> = []
    var fingerprintDisabledDomains: Set<String> = []
    var httpsOnlyModeEnabled: Bool = true
    var dntEnabled: Bool = true
    var clearDataOnQuit: Bool = false
    var strictCanvasBlockEnabled: Bool = false

    static let `default` = ContentBlockerSettings()
}

enum DomainNormalizer {
    /// Normalizes a URL or host string into a clean lowercase domain for whitelist matching.
    /// E.g. "https://www.google.com:8080/search?q=1" -> "google.com"
    static func normalize(url: URL?) -> String? {
        guard let url = url, let host = url.host else { return nil }
        return normalize(host: host)
    }

    /// Normalizes a host string (strips port, trims whitespace, lowercase, strips leading 'www.').
    static func normalize(host: String) -> String {
        var clean = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let colonIndex = clean.firstIndex(of: ":") {
            clean = String(clean[..<colonIndex])
        }
        if clean.hasPrefix("www.") {
            clean = String(clean.dropFirst(4))
        }
        return clean
    }
}
