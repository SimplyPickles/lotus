//
//  BrowserState+UserScripts.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import WebKit

extension BrowserState {

    /// Evaluates all enabled user scripts and styles matching `url` into `webView`.
    func applyUserScripts(to webView: WKWebView, for url: URL) {
        guard url.scheme == "http" || url.scheme == "https" else { return }
        let service = UserScriptService.shared
        guard service.isEnabled else { return }

        for script in service.matchingScripts(for: url) {
            let js: String
            switch script.type {
            case .css:
                js = UserScriptService.cssInjectionScript(css: script.code, scriptId: script.id.uuidString)
            case .javascript:
                js = script.code
            }
            webView.evaluateJavaScript(js, in: nil, in: .page) { _ in }
        }
    }

    /// Re-applies user scripts to all open (non-snoozed) tabs when script config changes.
    func reapplyUserScriptsToAllTabs() {
        for tab in tabs {
            guard let webView = webViewStore[tab.id],
                  let url = webView.url else { continue }
            applyUserScripts(to: webView, for: url)
        }
    }
}
