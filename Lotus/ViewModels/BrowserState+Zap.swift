//
//  BrowserState+Zap.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import AppKit
import WebKit
import SwiftUI

extension BrowserState {

    // MARK: - Zap Mode Controls

    /// Toggles the interactive visual element inspector on the active tab.
    func toggleZapMode(for tabId: UUID? = nil) {
        if isZapModeActive {
            stopZapMode(for: tabId)
        } else {
            startZapMode(for: tabId)
        }
    }

    /// Activates visual Zap mode on the specified tab.
    func startZapMode(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        guard let url = url(for: targetId), !url.isLotusPage else { return }
        guard let wv = webViewStore[targetId] else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            isZapModeActive = true
        }
        HapticFeedback.perform(.generic)

        let accentHex = LotusAccentColor.currentAccentHex
        let script = UserScripts.startZapModeScript(accentHex: accentHex)
        wv.evaluateJavaScript(script, in: nil, in: .page) { _ in }
    }

    /// Exits visual Zap mode and tears down the inspector overlay.
    func stopZapMode(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            isZapModeActive = false
        }

        // Delay clearing lastZappedElement until the slide-down animation finishes
        // so internal layout doesn't snap during exit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self, !self.isZapModeActive else { return }
            self.lastZappedElement = nil
        }

        if let wv = webViewStore[targetId] {
            wv.evaluateJavaScript(UserScripts.stopZapModeScript, in: nil, in: .page) { _ in }
        }
    }

    /// Handles an incoming element zap event from the webview.
    func handleZapEvent(domain: String, selector: String, summary: String, tabId: UUID) {
        let savedElement = SiteZapStore.shared.addZap(domain: domain, selector: selector, elementSummary: summary)
        lastZappedElement = savedElement
        HapticFeedback.perform(.alignment)

        // Ensure stylesheet is refreshed on live webview
        applyZapRules(for: tabId)
    }

    /// Reverts the most recently zapped element during the current session.
    func undoLastZap(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        guard let last = lastZappedElement else { return }

        SiteZapStore.shared.removeZap(last)
        lastZappedElement = nil
        HapticFeedback.perform(.generic)

        if let wv = webViewStore[targetId] {
            wv.evaluateJavaScript(UserScripts.undoZapScript(selector: last.selector), in: nil, in: .page) { _ in }
        }

        applyZapRules(for: targetId)
    }

    /// Removes a specific zapped element and updates the tab's DOM rules.
    func removeZappedElement(_ zap: ZappedElement, tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        SiteZapStore.shared.removeZap(zap)
        if lastZappedElement?.id == zap.id {
            lastZappedElement = nil
        }
        HapticFeedback.perform(.generic)

        if let wv = webViewStore[targetId] {
            wv.evaluateJavaScript(UserScripts.undoZapScript(selector: zap.selector), in: nil, in: .page) { _ in }
        }

        applyZapRules(for: targetId)
    }

    /// Injects or updates the active CSS zap rules for a tab's current domain.
    func applyZapRules(for tabId: UUID) {
        guard let url = url(for: tabId), let host = url.host, !url.isLotusPage else { return }
        guard let wv = webViewStore[tabId] else { return }

        let elements = SiteZapStore.shared.zappedElements(for: host)
        let js = UserScripts.zapRulesScript(for: elements)
        if !js.isEmpty {
            wv.evaluateJavaScript(js, in: nil, in: .page) { _ in }
        }
    }
}
