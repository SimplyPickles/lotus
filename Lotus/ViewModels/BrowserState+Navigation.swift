//
//  BrowserState+Navigation.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import WebKit

extension BrowserState {

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let isCmdPressed = navigationAction.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.command)
        let isLinkClick = navigationAction.navigationType == .linkActivated

        if isCmdPressed && isLinkClick && url.scheme != "about" {
            let sourceTabId = webViewStore.first(where: { $0.value === webView })?.key ?? selectedTabId
            DispatchQueue.main.async { [weak self] in
                self?.addTabBelow(currentTabId: sourceTabId, title: url.host ?? "New Tab", url: url, select: false)
            }
            decisionHandler(.cancel)
            return
        }

        if let scheme = url.scheme?.lowercased(),
           scheme != "http" && scheme != "https" && scheme != "about" && scheme != "lotus" && scheme != "blob" && scheme != "data" && scheme != "javascript" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let sourceTabId = webViewStore.first(where: { $0.value === webView })?.key ?? selectedTabId
        let targetURL = navigationAction.request.url

        WebViewFactory.applySharedPreferences(to: configuration, processPool: sharedProcessPool)

        let newTab = addTabBelow(currentTabId: sourceTabId, title: targetURL?.host ?? "New Tab", url: targetURL, select: true)

        let newWebView = WebViewFactory.makeWebView(configuration: configuration, delegate: self)
        webViewStore[newTab.id] = newWebView

        setupObservers(for: newTab.id, webView: newWebView)

        return newWebView
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
                  challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest {
            let host = challenge.protectionSpace.host
            let creds = keychainManager.fetchCredentials(for: host)
            if let first = creds.first {
                completionHandler(.useCredential, URLCredential(user: first.username, password: first.password, persistence: .forSession))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        DispatchQueue.main.async { [weak self] in
            if let tabId = self?.webViewStore.first(where: { $0.value === webView })?.key,
               self?.selectedTabId == tabId {
                self?.isLoading = false
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async { [weak self] in
            if let tabId = self?.webViewStore.first(where: { $0.value === webView })?.key,
               self?.selectedTabId == tabId {
                self?.isLoading = false
            }
        }
    }

    // MARK: - Navigation Actions

    func goBack() {
        let wv = getWebView(for: selectedTabId)
        if wv.canGoBack {
            wv.goBack()
        }
    }

    func goForward() {
        let wv = getWebView(for: selectedTabId)
        if wv.canGoForward {
            wv.goForward()
        }
    }

    func reload() {
        let wv = getWebView(for: selectedTabId)
        wv.reload()
    }

    func navigateActiveTab(to input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let targetURL: URL?
        if trimmed.lowercased() == "lotus://newtab" || trimmed.lowercased() == "newtab" {
            targetURL = URL(string: "lotus://newtab")
        } else if trimmed.lowercased().hasPrefix("lotus://") {
            targetURL = URL(string: trimmed)
        } else if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            targetURL = URL(string: trimmed)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            targetURL = URL(string: "https://\(trimmed)")
        } else if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            targetURL = URL(string: "https://www.google.com/search?q=\(encoded)")
        } else {
            targetURL = nil
        }

        guard let url = targetURL else { return }
        if let index = tabs.firstIndex(where: { $0.id == selectedTabId }) {
            tabs[index].url = url
            if url.scheme == "lotus" {
                tabs[index].title = "New Tab"
            } else {
                tabs[index].title = url.host ?? trimmed
            }
        }

        if url.scheme != "lotus" {
            newTabSearchText.removeValue(forKey: selectedTabId)
            let wv = getWebView(for: selectedTabId)
            wv.load(URLRequest(url: url))
        }
    }

    func updateNavigationState() {
        let wv = getWebView(for: selectedTabId)
        self.canGoBack = wv.canGoBack
        self.canGoForward = wv.canGoForward
        self.isLoading = wv.isLoading
        self.estimatedProgress = wv.estimatedProgress
        let parsed = self.themeColors[selectedTabId]
        self.activeThemeColor = parsed?.color
        self.activeThemeNSColor = parsed?.nsColor
        self.isThemeLight = parsed?.isLight ?? false
    }
}
