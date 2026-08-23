//
//  BrowserState+WebViews.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import WebKit

extension BrowserState {

    // MARK: - WebView Lifecycle

    /// Returns the cached webview for a tab, creating (and starting to load)
    /// one on first access.
    func getWebView(for tabId: UUID) -> WKWebView {
        let tab = tabs.first(where: { $0.id == tabId })
        let targetURL = tab?.url

        if let existing = webViewStore[tabId] {
            if let targetURL = targetURL,
               existing.url == nil && existing.backForwardList.currentItem == nil {
                existing.load(URLRequest(url: targetURL))
            }
            return existing
        }

        let config = WebViewFactory.makeConfiguration(messageHandler: self)
        let webView = WebViewFactory.makeWebView(configuration: config, delegate: self)
        webView.pageZoom = zoomLevel(for: tabId)
        webViewStore[tabId] = webView

        setupObservers(for: tabId, webView: webView)

        if let targetURL = targetURL {
            webView.load(URLRequest(url: targetURL))
        }

        return webView
    }

    // MARK: - KVO Observers

    func setupObservers(for tabId: UUID, webView: WKWebView) {
        var tabObservers: [NSKeyValueObservation] = []

        let backObs = webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                if self?.selectedTabId == tabId {
                    self?.canGoBack = wv.canGoBack
                }
            }
        }
        tabObservers.append(backObs)

        let forwardObs = webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                if self?.selectedTabId == tabId {
                    self?.canGoForward = wv.canGoForward
                }
            }
        }
        tabObservers.append(forwardObs)

        let loadingObs = webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                if self?.selectedTabId == tabId {
                    self?.isLoading = wv.isLoading
                }
            }
        }
        tabObservers.append(loadingObs)

        let progressObs = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                if self?.selectedTabId == tabId {
                    self?.estimatedProgress = wv.estimatedProgress
                }
            }
        }
        tabObservers.append(progressObs)

        let urlObs = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
            guard let self = self, let newURL = wv.url else { return }
            DispatchQueue.main.async {
                if let index = self.tabs.firstIndex(where: { $0.id == tabId }) {
                    self.tabs[index].url = newURL
                }
                // Record non-internal navigations in browsing history.
                if newURL.scheme == "http" || newURL.scheme == "https" {
                    let title = wv.title ?? newURL.host ?? newURL.absoluteString
                    self.recordHistoryVisit(title: title, url: newURL)
                }
            }
        }
        tabObservers.append(urlObs)

        let titleObs = webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
            guard let self = self, let newTitle = wv.title, !newTitle.isEmpty else { return }
            DispatchQueue.main.async {
                if let index = self.tabs.firstIndex(where: { $0.id == tabId }) {
                    self.tabs[index].title = newTitle
                }
            }
        }
        tabObservers.append(titleObs)

        if #available(macOS 12.0, *) {
            let themeObs = webView.observe(\.themeColor, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    if let nsColor = wv.themeColor?.usingColorSpace(.sRGB) {
                        let r = Double(nsColor.redComponent)
                        let g = Double(nsColor.greenComponent)
                        let b = Double(nsColor.blueComponent)
                        let lum = 0.299 * r + 0.587 * g + 0.114 * b
                        let parsed = ParsedThemeColor(color: Color(nsColor: nsColor), nsColor: nsColor, isLight: lum > 0.55)
                        self?.updateThemeColor(for: tabId, parsed: parsed)
                    }
                }
            }
            tabObservers.append(themeObs)
        }

        observers[tabId] = tabObservers
    }
}
