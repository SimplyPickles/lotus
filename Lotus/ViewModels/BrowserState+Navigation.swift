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
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let isCmdPressed = navigationAction.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.command)
        let isLinkClick = navigationAction.navigationType == .linkActivated

        if isCmdPressed && isLinkClick && url.scheme != "about" {
            let sourceTabId = webViewStore.first(where: { $0.value === webView })?.key ?? selectedTabId
            DispatchQueue.main.async { [weak self] in
                self?.openTabFromCmdClick(sourceTabId: sourceTabId, title: url.host ?? "New Tab", url: url, select: false)
            }
            decisionHandler(.cancel)
            return
        }

        let allowedSchemes: Set<String> = [
            "http", "https", "about", "lotus", "blob", "data", "javascript",
            "webkit-extension", "chrome-extension"
        ]
        if let scheme = url.scheme?.lowercased(), !allowedSchemes.contains(scheme) {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
            return
        }
        if let httpResponse = navigationResponse.response as? HTTPURLResponse,
           let disposition = (httpResponse.allHeaderFields["Content-Disposition"] ?? httpResponse.allHeaderFields["content-disposition"]) as? String,
           disposition.lowercased().contains("attachment") {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        handleDownloadInitiated(download, from: navigationAction.request.url)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        handleDownloadInitiated(download, from: navigationResponse.response.url)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let sourceTabId = webViewStore.first(where: { $0.value === webView })?.key ?? selectedTabId
        let targetURL = navigationAction.request.url

        WebViewFactory.applySharedPreferences(to: configuration)

        let isCmdPressed = navigationAction.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.command)
        let newTab: TabItem
        if isCmdPressed {
            newTab = openTabFromCmdClick(sourceTabId: sourceTabId, title: targetURL?.host ?? "New Tab", url: targetURL, select: true)
        } else {
            newTab = addTabBelow(currentTabId: sourceTabId, title: targetURL?.host ?? "New Tab", url: targetURL, select: true)
        }

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

    // MARK: - Navigation State Accessors

    func canGoBack(for tabId: UUID) -> Bool {
        webViewStore[tabId]?.canGoBack ?? false
    }

    func canGoForward(for tabId: UUID) -> Bool {
        webViewStore[tabId]?.canGoForward ?? false
    }

    func isLoading(for tabId: UUID) -> Bool {
        webViewStore[tabId]?.isLoading ?? false
    }

    func estimatedProgress(for tabId: UUID) -> Double {
        webViewStore[tabId]?.estimatedProgress ?? 0.0
    }

    // MARK: - Navigation Actions

    func goBack(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        let wv = getWebView(for: targetId)
        if wv.canGoBack {
            wv.goBack()
        }
    }

    func goForward(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        let wv = getWebView(for: targetId)
        if wv.canGoForward {
            wv.goForward()
        }
    }

    func reload(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        let wv = getWebView(for: targetId)
        wv.reload()
    }

    func stopLoading(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        let wv = getWebView(for: targetId)
        wv.stopLoading()
        if selectedTabId == targetId {
            isLoading = false
        }
    }

    func navigateTab(id: UUID, to input: String) {
        guard let url = URLInputResolver.resolve(input) else { return }
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs[index].url = url
            tabs[index].title = URLInputResolver.initialTitle(for: url, input: input)
        }

        // lotus:// URLs load through LotusSchemeHandler so internal pages
        // join the back-forward list like any other navigation.
        let wv = getWebView(for: id)
        wv.load(URLRequest(url: url))
    }

    /// Loads an already-resolved URL in a tab's webview (used by internal
    /// pages like history to replace their own page in-place).
    func loadURL(_ url: URL, in tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        if let index = tabs.firstIndex(where: { $0.id == targetId }) {
            tabs[index].url = url
            tabs[index].title = url.host ?? url.absoluteString
        }

        getWebView(for: targetId).load(URLRequest(url: url))
    }

    func navigateActiveTab(to input: String) {
        navigateTab(id: selectedTabId, to: input)
    }

    /// Opens a tab triggered by ⌘-click, grouping it into a tab group/folder with the source tab.
    @discardableResult
    func openTabFromCmdClick(sourceTabId: UUID, title: String = "New Tab", url: URL?, select: Bool = false) -> TabItem {
        guard let sourceTab = tab(for: sourceTabId) else {
            return addTabBelow(currentTabId: sourceTabId, title: title, url: url, select: select)
        }

        // If the source tab is already in a folder, add the new tab to the existing folder
        if let folderId = sourceTab.folderId {
            expandFolder(id: folderId)
            return addTabBelow(currentTabId: sourceTabId, title: title, url: url, select: select)
        }

        // If the source tab is not in a folder, create a new tab group with it
        let groupName: String
        let trimmedTitle = sourceTab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty && trimmedTitle != "New Tab" && trimmedTitle != "Lotus" {
            groupName = trimmedTitle
        } else if let host = sourceTab.url?.host, !host.isEmpty {
            groupName = host
        } else {
            groupName = "Tab Group"
        }

        let folder = createFolder(named: groupName, with: sourceTabId)
        expandFolder(id: folder.id)
        return addTabBelow(currentTabId: sourceTabId, title: title, url: url, select: select)
    }

    func updateNavigationState() {
        // With the palette-based new-tab flow the tabs list can be empty;
        // never conjure a webview for an id that has no tab behind it.
        guard tab(for: selectedTabId) != nil else {
            self.canGoBack = false
            self.canGoForward = false
            self.isLoading = false
            self.estimatedProgress = 0.0
            self.activeThemeColor = nil
            self.activeThemeNSColor = nil
            self.isThemeLight = false
            return
        }
        let wv = getWebView(for: selectedTabId)
        self.canGoBack = wv.canGoBack
        self.canGoForward = wv.canGoForward
        self.isLoading = wv.isLoading
        self.estimatedProgress = wv.estimatedProgress
        // Internal pages always present with the system appearance, even if
        // the tab still caches the previous site's theme for Back.
        let parsed = activeURL?.isLotusPage == true ? nil : self.themeColors[selectedTabId]
        self.activeThemeColor = parsed?.color
        self.activeThemeNSColor = parsed?.nsColor
        self.isThemeLight = parsed?.isLight ?? false
    }
}
