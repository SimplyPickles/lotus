//
//  BrowserState+ContentBlocker.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import SwiftUI
import WebKit

extension BrowserState {

    // MARK: - Shields / Content Blocker

    /// Returns whether content blocking (shields) is currently active for the given tab.
    func isShieldActive(for tabId: UUID? = nil) -> Bool {
        let id = tabId ?? selectedTabId
        guard let url = url(for: id), !url.isLotusPage else { return false }
        return ContentBlockerService.shared.isShieldActive(for: url)
    }

    /// Normalized domain for the given tab's current URL.
    func domain(for tabId: UUID? = nil) -> String? {
        let id = tabId ?? selectedTabId
        guard let currentURL = url(for: id), !currentURL.isLotusPage else { return nil }
        return DomainNormalizer.normalize(url: currentURL)
    }

    /// Toggles content blocking on/off for the given tab's current domain and reloads the page.
    func toggleShield(for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        guard let currentURL = url(for: id), !currentURL.isLotusPage else { return }
        ContentBlockerService.shared.toggleShield(for: currentURL)
        reload(for: id)
    }

    /// Returns whether strict popup and link blocking is active for the given tab.
    func isStrictPopupBlockingActive(for tabId: UUID? = nil) -> Bool {
        let id = tabId ?? selectedTabId
        guard let url = url(for: id), !url.isLotusPage else { return false }
        return ContentBlockerService.shared.isStrictPopupBlockingActive(for: url)
    }

    /// Toggles strict popup and link blocking for the given tab's current domain.
    func toggleStrictPopupBlocking(for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        guard let currentURL = url(for: id), !currentURL.isLotusPage else { return }
        ContentBlockerService.shared.toggleStrictPopupBlocking(for: currentURL)
    }

    /// Returns whether fingerprint protection is active for the given tab.
    func isFingerprintProtectionActive(for tabId: UUID? = nil) -> Bool {
        let id = tabId ?? selectedTabId
        guard let url = url(for: id), !url.isLotusPage else { return false }
        return ContentBlockerService.shared.isFingerprintProtectionActive(for: url)
    }

    /// Toggles fingerprint protection for the given tab's current domain and reloads the page.
    func toggleFingerprintProtection(for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        guard let currentURL = url(for: id), !currentURL.isLotusPage else { return }
        ContentBlockerService.shared.toggleFingerprintProtection(for: currentURL)
        reload(for: id)
    }
}
