//
//  BrowserState+Theming.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import WebKit

extension BrowserState {

    func updateThemeColor(for tabId: UUID, parsed: ParsedThemeColor) {
        themeColors[tabId] = parsed
        if selectedTabId == tabId {
            self.activeThemeColor = parsed.color
            self.activeThemeNSColor = parsed.nsColor
            self.isThemeLight = parsed.isLight
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
