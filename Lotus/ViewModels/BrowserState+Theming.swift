//
//  BrowserState+Theming.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import WebKit

extension BrowserState {

    func themeColor(for tabId: UUID) -> Color? {
        themeColors[tabId]?.color
    }

    func isThemeLight(for tabId: UUID) -> Bool {
        themeColors[tabId]?.isLight ?? false
    }

    func updateThemeColor(for tabId: UUID, parsed: ParsedThemeColor) {
        // Late-arriving extractions (e.g. from a page being navigated away
        // from) must not tint a tab that is now on an internal page.
        guard tab(for: tabId)?.url?.isLotusPage != true else { return }
        themeColors[tabId] = parsed
        themeBloomTrigger[tabId, default: 0] += 1
        if selectedTabId == tabId {
            withAnimation(.easeInOut(duration: 0.22)) {
                self.activeThemeColor = parsed.color
                self.activeThemeNSColor = parsed.nsColor
                self.isThemeLight = parsed.isLight
            }
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        extractThemeColor(from: webView)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        extractThemeColor(from: webView)
    }

    func extractThemeColor(from webView: WKWebView) {
        guard let tabId = webViewStore.first(where: { $0.value === webView })?.key else { return }
        // Internal pages are blank scheme-handler documents; never let them
        // tint the chrome.
        guard webView.url?.isLotusPage != true else { return }

        webView.evaluateJavaScript(UserScripts.themeColorProbe) { [weak self] result, _ in
            guard let self = self, let colorString = result as? String else { return }
            if let parsed = ColorParser.parse(colorString) {
                DispatchQueue.main.async {
                    self.updateThemeColor(for: tabId, parsed: parsed)
                }
            }
        }
    }
}
