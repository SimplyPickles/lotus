//
//  BrowserState.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import WebKit
import Combine

/// Serializable snapshot of the user's browser session across app launches.
struct BrowserSessionData: Codable {
    var tabs: [TabItem]
    var selectedTabId: UUID
    var recentlyClosed: [BrowserState.ClosedTabRecord]
    var isSidebarVisible: Bool
    var sidebarWidth: CGFloat
}

final class BrowserState: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    @Published var tabs: [TabItem] {
        didSet {
            saveSession()
        }
    }
    @Published var selectedTabId: UUID {
        didSet {
            updateNavigationState()
            syncFocusStateForActiveTab()
            saveSession()
        }
    }
    @Published var isSidebarVisible: Bool = true {
        didSet {
            saveSession()
        }
    }
    @Published var sidebarWidth: CGFloat = 240 {
        didSet {
            saveSession()
        }
    }
    @Published var isResizingSidebar: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0.0
    @Published var activeThemeColor: Color? = nil
    @Published var activeThemeNSColor: NSColor? = nil
    @Published var isThemeLight: Bool = false
    @Published var pendingSaveCredential: KeychainCredential? = nil

    /// Snapshot of a closed tab for reopen support.
    struct ClosedTabRecord: Codable, Equatable {
        let title: String
        let url: URL?
        let isPinned: Bool
        let insertionIndex: Int
    }

    /// LIFO stack of recently closed tabs (capped at 20).
    private(set) var recentlyClosed: [ClosedTabRecord] = []
    private let maxRecentlyClosed = 20

    let keychainManager = KeychainManager.shared
    let autoFillController = AutoFillController.shared

    private static let sessionKey = "lotus.browser.session"
    private var terminationObserver: NSObjectProtocol?
    private var keyMonitor: Any?

    @Published var isWebInputFocused: Bool = false

    var isAnyTextInputFocused: Bool {
        if let responder = NSApp.keyWindow?.firstResponder {
            if responder is NSTextView || responder is NSTextField {
                return true
            }
        }
        return isWebInputFocused
    }

    @Published var isQuitConfirmationPresented: Bool = false
    static let alwaysQuitKey = "lotus.always_quit_without_confirming"

    var newTabSearchText: [UUID: String] = [:]

    private var themeColors: [UUID: ParsedThemeColor] = [:]
    private var webViewStore: [UUID: WKWebView] = [:]
    private var observers: [UUID: [NSKeyValueObservation]] = [:]
    private let sharedProcessPool = WKProcessPool()

    func requestQuit() {
        if isQuitConfirmationPresented {
            confirmQuit(alwaysQuit: false)
            return
        }
        if UserDefaults.standard.bool(forKey: Self.alwaysQuitKey) {
            confirmQuit(alwaysQuit: false)
            return
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            isQuitConfirmationPresented = true
        }
    }

    func cancelQuit() {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
            isQuitConfirmationPresented = false
        }
    }

    func confirmQuit(alwaysQuit: Bool = false) {
        if alwaysQuit {
            UserDefaults.standard.set(true, forKey: Self.alwaysQuitKey)
        }
        saveSession()
        isQuitConfirmationPresented = false
        AppDelegate.forceTerminate()
    }

    init(tabs: [TabItem]? = nil, initialSelectedId: UUID? = nil) {
        if let explicitTabs = tabs {
            self.tabs = explicitTabs
            self.selectedTabId = initialSelectedId ?? explicitTabs.first?.id ?? UUID()
        } else if let data = UserDefaults.standard.data(forKey: Self.sessionKey),
                  let session = try? JSONDecoder().decode(BrowserSessionData.self, from: data),
                  !session.tabs.isEmpty {
            self.tabs = session.tabs
            self.selectedTabId = session.tabs.contains(where: { $0.id == session.selectedTabId }) ? session.selectedTabId : (session.tabs.first?.id ?? UUID())
            self.recentlyClosed = session.recentlyClosed
            self.isSidebarVisible = session.isSidebarVisible
            self.sidebarWidth = session.sidebarWidth
        } else {
            self.tabs = TabItem.samples
            self.selectedTabId = TabItem.samples.first?.id ?? UUID()
        }
        super.init()
        self.updateNavigationState()
        self.setupTerminationObserver()
        self.setupKeyMonitor()
    }

    deinit {
        if let obs = terminationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let km = keyMonitor {
            NSEvent.removeMonitor(km)
        }
    }

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command {
                if event.keyCode == 123 { // Left Arrow
                    if self.isAnyTextInputFocused {
                        return event
                    }
                    if self.canGoBack {
                        DispatchQueue.main.async {
                            self.goBack()
                        }
                        return nil
                    }
                } else if event.keyCode == 124 { // Right Arrow
                    if self.isAnyTextInputFocused {
                        return event
                    }
                    if self.canGoForward {
                        DispatchQueue.main.async {
                            self.goForward()
                        }
                        return nil
                    }
                }
            }
            return event
        }
    }

    private func setupTerminationObserver() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveSession()
        }
    }

    func saveSession() {
        guard !tabs.isEmpty else { return }
        let session = BrowserSessionData(
            tabs: tabs,
            selectedTabId: selectedTabId,
            recentlyClosed: recentlyClosed,
            isSidebarVisible: isSidebarVisible,
            sidebarWidth: sidebarWidth
        )
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: Self.sessionKey)
        }
    }

    var pinnedTabs: [TabItem] {
        tabs.filter { $0.isPinned }
    }

    var unpinnedTabs: [TabItem] {
        tabs.filter { !$0.isPinned }
    }

    func togglePin(id: UUID) {
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs[index].isPinned.toggle()
        }
    }

    var activeTab: TabItem? {
        tabs.first(where: { $0.id == selectedTabId }) ?? tabs.first
    }

    var activeURL: URL? {
        activeTab?.url
    }

    var activeWebView: WKWebView {
        getWebView(for: selectedTabId)
    }

    func getWebView(for tabId: UUID) -> WKWebView {
        if let existing = webViewStore[tabId] {
            return existing
        }

        let config = WKWebViewConfiguration()
        config.processPool = self.sharedProcessPool
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController.add(self, name: "lotusCredentialHandler")
        config.userContentController.add(self, name: "lotusInputFocusHandler")

        let focusScript = """
        (function() {
            function isEditable(el) {
                try {
                    if (!el) return false;
                    if (el.isContentEditable) return true;
                    var tag = el.tagName ? el.tagName.toUpperCase() : '';
                    return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT';
                } catch(e) { return false; }
            }
            window.__lotusCheckInputFocus = function() {
                try {
                    var el = document.activeElement;
                    var focused = isEditable(el);
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                        window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: focused });
                    }
                } catch(e) {}
            };
            document.addEventListener('focusin', function(e) {
                try {
                    if (isEditable(e.target)) {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                            window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: true });
                        }
                    }
                } catch(e) {}
            }, true);
            document.addEventListener('focusout', function(e) {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                        window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: false });
                    }
                } catch(e) {}
            }, true);
        })();
        """
        let focusUserScript = WKUserScript(source: focusScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(focusUserScript)

        let credentialScript = """
        (function() {
            function setupFormListeners() {
                try {
                    document.addEventListener('focusin', function(e) {
                        try {
                            var target = e.target;
                            if (target && target.tagName === 'INPUT' && (target.type === 'password' || target.autocomplete === 'current-password')) {
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusCredentialHandler) {
                                    window.webkit.messageHandlers.lotusCredentialHandler.postMessage({
                                        event: 'focus',
                                        server: window.location.hostname || ''
                                    });
                                }
                            }
                        } catch(e) {}
                    }, true);

                    document.addEventListener('submit', function(e) {
                        try {
                            var form = e.target;
                            if (!form) return;
                            var passwordInput = form.querySelector('input[type="password"]');
                            if (!passwordInput || !passwordInput.value) return;

                            var userInput = form.querySelector('input[type="text"], input[type="email"], input[name*="user"], input[name*="login"], input[name*="email"], input[autocomplete="username"]');
                            var username = userInput ? userInput.value : '';

                            if (username && passwordInput.value) {
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusCredentialHandler) {
                                    window.webkit.messageHandlers.lotusCredentialHandler.postMessage({
                                        event: 'submit',
                                        username: username,
                                        password: passwordInput.value,
                                        server: window.location.hostname || ''
                                    });
                                }
                            }
                        } catch(e) {}
                    }, true);
                } catch(e) {}
            }

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', setupFormListeners);
            } else {
                setupFormListeners();
            }
        })();
        """
        let userScript = WKUserScript(source: credentialScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = NSColor.windowBackgroundColor
        webView.wantsLayer = true
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        webViewStore[tabId] = webView

        setupObservers(for: tabId, webView: webView)

        if let tab = tabs.first(where: { $0.id == tabId }), let url = tab.url, url.scheme != "lotus" {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    private func setupObservers(for tabId: UUID, webView: WKWebView) {
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

    func updateThemeColor(for tabId: UUID, parsed: ParsedThemeColor) {
        themeColors[tabId] = parsed
        if selectedTabId == tabId {
            self.activeThemeColor = parsed.color
            self.activeThemeNSColor = parsed.nsColor
            self.isThemeLight = parsed.isLight
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

    func selectTab(_ id: UUID) {
        selectedTabId = id
    }

    func selectTab(_ tab: TabItem) {
        selectedTabId = tab.id
    }

    var orderedTabs: [TabItem] {
        pinnedTabs + unpinnedTabs
    }

    func selectNextTab() {
        let list = orderedTabs
        guard !list.isEmpty else { return }
        guard let currentIndex = list.firstIndex(where: { $0.id == selectedTabId }) else {
            selectedTabId = list[0].id
            return
        }
        let nextIndex = (currentIndex + 1) % list.count
        selectedTabId = list[nextIndex].id
    }

    func selectPreviousTab() {
        let list = orderedTabs
        guard !list.isEmpty else { return }
        guard let currentIndex = list.firstIndex(where: { $0.id == selectedTabId }) else {
            selectedTabId = list[0].id
            return
        }
        let prevIndex = (currentIndex - 1 + list.count) % list.count
        selectedTabId = list[prevIndex].id
    }

    func selectTabAtIndex(_ index: Int) {
        let list = orderedTabs
        guard !list.isEmpty else { return }
        if index == 8 && list.count <= 9 {
            selectedTabId = list.last?.id ?? selectedTabId
        } else if index >= 0 && index < list.count {
            selectedTabId = list[index].id
        }
    }

    func addTab(title: String = "New Tab", url: URL? = URL(string: "lotus://newtab")) {
        let newTab = TabItem(title: title, url: url)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            tabs.insert(newTab, at: 0)
            selectedTabId = newTab.id
        }
    }

    @discardableResult
    func addTabBelow(currentTabId: UUID? = nil, title: String = "New Tab", url: URL? = URL(string: "lotus://newtab"), select: Bool = true) -> TabItem {
        let newTab = TabItem(title: title, url: url)
        let targetId = currentTabId ?? selectedTabId

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            if let currentIndex = tabs.firstIndex(where: { $0.id == targetId }) {
                tabs.insert(newTab, at: currentIndex + 1)
            } else {
                tabs.insert(newTab, at: 0)
            }

            if select {
                selectedTabId = newTab.id
            }
        }
        return newTab
    }

    func removeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let closingTab = tabs[index]

        // Don't record blank new-tab pages — they're trivial to recreate.
        if closingTab.url?.scheme != "lotus" {
            let record = ClosedTabRecord(
                title: closingTab.title,
                url: closingTab.url,
                isPinned: closingTab.isPinned,
                insertionIndex: index
            )
            recentlyClosed.append(record)
            if recentlyClosed.count > maxRecentlyClosed {
                recentlyClosed.removeFirst(recentlyClosed.count - maxRecentlyClosed)
            }
        }

        tabs.remove(at: index)
        newTabSearchText.removeValue(forKey: id)
        if let wv = webViewStore[id] {
            if #available(macOS 12.0, *) {
                wv.pauseAllMediaPlayback()
            }
            let pauseScript = """
            (function() {
                var media = document.querySelectorAll('audio, video');
                media.forEach(function(m) {
                    try { m.pause(); m.src = ''; } catch(e){}
                });
                if (window.AudioContext || window.webkitAudioContext) {
                    try { (window.AudioContext || window.webkitAudioContext).close(); } catch(e){}
                }
            })();
            """
            wv.evaluateJavaScript(pauseScript, completionHandler: nil)
            wv.stopLoading()
            wv.navigationDelegate = nil
            wv.uiDelegate = nil
            wv.load(URLRequest(url: URL(string: "about:blank")!))
            wv.removeFromSuperview()
        }
        webViewStore.removeValue(forKey: id)
        observers.removeValue(forKey: id)
        themeColors.removeValue(forKey: id)

        if selectedTabId == id {
            if index < tabs.count {
                selectedTabId = tabs[index].id
            } else if let last = tabs.last {
                selectedTabId = last.id
            } else {
                addTab()
            }
        } else if tabs.isEmpty {
            addTab()
        }
    }

    func reopenLastClosedTab() {
        guard !recentlyClosed.isEmpty else { return }
        let record = recentlyClosed.removeLast()
        let newTab = TabItem(title: record.title, url: record.url, isPinned: record.isPinned)
        let insertAt = min(record.insertionIndex, tabs.count)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            tabs.insert(newTab, at: insertAt)
            selectedTabId = newTab.id
        }
        if let url = record.url, url.scheme != "lotus" {
            let wv = getWebView(for: newTab.id)
            wv.load(URLRequest(url: url))
        }
    }

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

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    // MARK: - WKNavigationDelegate & WKUIDelegate Link Opening, Popups & Cross-Origin Auth

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

        configuration.processPool = self.sharedProcessPool
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let newTab = addTabBelow(currentTabId: sourceTabId, title: targetURL?.host ?? "New Tab", url: targetURL, select: true)

        let newWebView = WKWebView(frame: .zero, configuration: configuration)
        newWebView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        newWebView.navigationDelegate = self
        newWebView.uiDelegate = self
        newWebView.allowsBackForwardNavigationGestures = true
        newWebView.underPageBackgroundColor = NSColor.windowBackgroundColor
        newWebView.wantsLayer = true
        if #available(macOS 13.3, *) {
            newWebView.isInspectable = true
        }
        webViewStore[newTab.id] = newWebView

        setupObservers(for: newTab.id, webView: newWebView)

        return newWebView
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    func webViewDidClose(_ webView: WKWebView) {
        if let tabId = webViewStore.first(where: { $0.value === webView })?.key {
            DispatchQueue.main.async { [weak self] in
                self?.removeTab(id: tabId)
            }
        }
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

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = defaultText ?? ""
        alert.accessoryView = input
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn ? input.stringValue : nil)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
        openPanel.canChooseDirectories = parameters.allowsDirectories
        openPanel.canChooseFiles = true
        openPanel.begin { result in
            if result == .OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }

    // MARK: - WKNavigationDelegate Theme Color Extraction

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        extractThemeColor(from: webView)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        extractThemeColor(from: webView)
    }

    private func extractThemeColor(from webView: WKWebView) {
        guard let tabId = webViewStore.first(where: { $0.value === webView })?.key else { return }

        let script = """
        (function() {
            var meta = document.querySelector('meta[name="theme-color"]');
            if (meta && meta.content) return meta.content;
            var bodyStyle = window.getComputedStyle(document.body);
            var bg = bodyStyle.backgroundColor;
            if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') return bg;
            var docStyle = window.getComputedStyle(document.documentElement);
            var docBg = docStyle.backgroundColor;
            if (docBg && docBg !== 'rgba(0, 0, 0, 0)' && docBg !== 'transparent') return docBg;
            return null;
        })()
        """
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self = self, let colorString = result as? String else { return }
            if let parsed = ColorParser.parse(colorString) {
                DispatchQueue.main.async {
                    self.updateThemeColor(for: tabId, parsed: parsed)
                }
            }
        }
    }

    func syncFocusStateForActiveTab() {
        guard let wv = webViewStore[selectedTabId] else {
            isWebInputFocused = false
            return
        }
        wv.evaluateJavaScript("window.__lotusCheckInputFocus ? window.__lotusCheckInputFocus() : void 0;") { _, _ in }
    }

    // MARK: - AutoFill & Credential Management

    func triggerAutoFill(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        let webView = getWebView(for: targetId)
        autoFillController.performAutoFillRequest(for: webView)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "lotusInputFocusHandler",
           let body = message.body as? [String: Any],
           let isFocused = body["isFocused"] as? Bool {
            if message.webView === self.webViewStore[selectedTabId] {
                DispatchQueue.main.async { [weak self] in
                    self?.isWebInputFocused = isFocused
                }
            }
            return
        }

        guard message.name == "lotusCredentialHandler",
              let body = message.body as? [String: Any],
              message.webView === self.webViewStore[selectedTabId] else {
            return
        }

        let event = body["event"] as? String ?? "submit"
        let host = message.webView?.url?.host ?? body["server"] as? String ?? ""

        if event == "focus" {
            guard !host.isEmpty, let webView = message.webView else { return }
            let creds = keychainManager.fetchCredentials(for: host)
            if let first = creds.first {
                autoFillController.fillCredentials(in: webView, username: first.username, password: first.password)
            } else {
                autoFillController.performAutoFillRequest(for: webView)
            }
        } else if event == "submit" {
            guard let username = body["username"] as? String,
                  let password = body["password"] as? String,
                  !username.isEmpty, !password.isEmpty, !host.isEmpty else {
                return
            }

            let cred = KeychainCredential(server: host, username: username, password: password)
            DispatchQueue.main.async { [weak self] in
                self?.pendingSaveCredential = cred
                self?.keychainManager.saveCredential(server: host, username: username, password: password)
            }
        }
    }
}
