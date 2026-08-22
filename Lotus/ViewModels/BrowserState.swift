//
//  BrowserState.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import WebKit
import Combine

/// The single observable controller owning all browser state.
///
/// Behavior is organized across focused extensions:
/// - `BrowserState+Tabs` — tab CRUD, selection, pinning, reopen
/// - `BrowserState+WebViews` — per-tab WKWebView lifecycle and KVO observers
/// - `BrowserState+Navigation` — WKNavigationDelegate and navigation actions
/// - `BrowserState+UIDelegate` — WKUIDelegate, script messages, autofill
/// - `BrowserState+Theming` — favicon/page theme color extraction
/// - `BrowserState+SessionPersistence` — session save/restore
/// - `BrowserState+Quit` — quit confirmation flow
final class BrowserState: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    // MARK: - Published State

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
    @Published var isWebInputFocused: Bool = false
    @Published var isQuitConfirmationPresented: Bool = false

    // MARK: - Recently Closed

    /// LIFO stack of recently closed tabs (capped at `maxRecentlyClosed`).
    var recentlyClosed: [ClosedTabRecord] = []
    let maxRecentlyClosed = 20

    // MARK: - Services & Stores

    let keychainManager = KeychainManager.shared
    let autoFillController = AutoFillController.shared
    let sessionStore = SessionStore()

    var terminationObserver: NSObjectProtocol?
    private var keyMonitor: Any?

    static let alwaysQuitKey = "lotus.always_quit_without_confirming"

    /// In-progress search text per new-tab page, keyed by tab id.
    var newTabSearchText: [UUID: String] = [:]

    var themeColors: [UUID: ParsedThemeColor] = [:]
    var webViewStore: [UUID: WKWebView] = [:]
    var observers: [UUID: [NSKeyValueObservation]] = [:]
    let sharedProcessPool = WKProcessPool()

    // MARK: - Focus

    var isAnyTextInputFocused: Bool {
        if let responder = NSApp.keyWindow?.firstResponder {
            if responder is NSTextView || responder is NSTextField {
                return true
            }
        }
        return isWebInputFocused
    }

    // MARK: - Lifecycle

    init(tabs: [TabItem]? = nil, initialSelectedId: UUID? = nil) {
        let restoredSession = SessionStore().load()
        if let explicitTabs = tabs {
            self.tabs = explicitTabs
            self.selectedTabId = initialSelectedId ?? explicitTabs.first?.id ?? UUID()
        } else if let session = restoredSession {
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
        if tabs == nil {
            sessionStore.migrateFromUserDefaultsIfNeeded()
        }
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

    // MARK: - Key Monitor

    private func setupKeyMonitor() {
        LotusShortcuts.debugAssertNoConflicts()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return KeyboardShortcutRouter.handleKeyEvent(event, browserState: self)
        }
    }
}
