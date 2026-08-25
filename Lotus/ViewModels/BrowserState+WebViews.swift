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
                if targetURL.isFileURL {
                    existing.loadFileURL(targetURL, allowingReadAccessTo: targetURL.deletingLastPathComponent())
                } else {
                    existing.load(URLRequest(url: targetURL))
                }
            }
            return existing
        }

        let config = WebViewFactory.makeConfiguration(messageHandler: self, isPrivate: isPrivate)
        let webView = WebViewFactory.makeWebView(configuration: config, delegate: self)
        webView.pageZoom = zoomLevel(for: tabId)
        webViewStore[tabId] = webView

        setupObservers(for: tabId, webView: webView)

        if let targetURL = targetURL {
            if targetURL.isFileURL {
                webView.loadFileURL(targetURL, allowingReadAccessTo: targetURL.deletingLastPathComponent())
            } else {
                webView.load(URLRequest(url: targetURL))
            }
        }

        return webView
    }

    // MARK: - KVO Observers

    func setupObservers(for tabId: UUID, webView: WKWebView) {
        tabLoadingStates[tabId] = webView.isLoading
        tabEstimatedProgress[tabId] = webView.estimatedProgress

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

        let loadingObs = webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] wv, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.tab(for: tabId) != nil else { return }
                self.tabLoadingStates[tabId] = wv.isLoading
                if self.selectedTabId == tabId {
                    self.isLoading = wv.isLoading
                }
            }
        }
        tabObservers.append(loadingObs)

        let progressObs = webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] wv, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.tab(for: tabId) != nil else { return }
                self.tabEstimatedProgress[tabId] = wv.estimatedProgress
                if self.selectedTabId == tabId {
                    self.estimatedProgress = wv.estimatedProgress
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
                if let currentURL = wv.url {
                    self.updateHistoryTitle(title: newTitle, for: currentURL)
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

    // MARK: - Tab Snoozing / Memory Suspension

    /// Snoozes a background tab by releasing its WKWebView and observers to free system memory.
    func snoozeTab(id: UUID) {
        // Do not snooze currently active tab or visible split tabs
        guard id != selectedTabId, !currentTabIds.contains(id) else { return }
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        guard !tabs[index].isSnoozed else { return }

        // Invalidate KVO observers
        observers[id]?.forEach { $0.invalidate() }
        observers.removeValue(forKey: id)

        // Remove WKWebView from memory
        if let webView = webViewStore.removeValue(forKey: id) {
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
        }

        tabLoadingStates.removeValue(forKey: id)
        tabEstimatedProgress.removeValue(forKey: id)
        tabs[index].isSnoozed = true
        saveSession()
    }

    /// Wakes up a snoozed tab, recreating its WKWebView and restoring its URL.
    func wakeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        if tabs[index].isSnoozed {
            tabs[index].isSnoozed = false
            tabs[index].lastViewedAt = Date()
            _ = getWebView(for: id)
            saveSession()
        }
    }

    /// Automatically snoozes inactive background tabs based on user settings.
    func snoozeInactiveTabsIfNeeded() {
        let rawInterval = UserDefaults.standard.string(forKey: "lotus.browser.tabSnoozeInterval") ?? "never"
        let thresholdSeconds: TimeInterval
        switch rawInterval {
        case "15m": thresholdSeconds = 15 * 60
        case "30m": thresholdSeconds = 30 * 60
        case "1h": thresholdSeconds = 60 * 60
        case "2h": thresholdSeconds = 120 * 60
        default: return // "never"
        }

        let now = Date()
        for tab in tabs {
            guard !tab.isPinned,
                  !currentTabIds.contains(tab.id),
                  !tab.isSnoozed,
                  tab.url != nil,
                  tab.url?.isLotusPage == false else {
                continue
            }

            // Do not snooze tabs playing audio
            if let mediaState = tabMediaStates[tab.id], mediaState.isPlaying {
                continue
            }

            let lastActive = tab.lastViewedAt ?? Date.distantPast
            if now.timeIntervalSince(lastActive) >= thresholdSeconds {
                snoozeTab(id: tab.id)
            }
        }
    }
}
