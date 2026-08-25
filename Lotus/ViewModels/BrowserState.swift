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
/// - `BrowserState+UIDelegate` — WKUIDelegate and script messages
/// - `BrowserState+Theming` — favicon/page theme color extraction
/// - `BrowserState+SessionPersistence` — session save/restore
/// - `BrowserState+Quit` — quit confirmation flow
final class BrowserState: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    // MARK: - Published State

    @Published var tabs: [TabItem] {
        didSet {
            saveSession()
            scheduleAutomaticFolderNames(affectedBy: oldValue)
        }
    }
    @Published var selectedTabId: UUID {
        didSet {
            wakeTab(id: selectedTabId)
            updateNavigationState()
            syncFocusStateForActiveTab()
            handlePictureInPictureOnTabSwitch(from: oldValue, to: selectedTabId)
            syncFindOnTabSwitch(from: oldValue, to: selectedTabId)
            updateLastViewedTimestamp(for: selectedTabId)
            archiveInactiveTabsIfNeeded()
            snoozeInactiveTabsIfNeeded()
            saveSession()
        }
    }
    @Published var currentTabIds: [UUID] {
        didSet {
            if !currentTabIds.contains(selectedTabId), let first = currentTabIds.first {
                selectedTabId = first
            }
            updateNavigationState()
            syncFocusStateForActiveTab()
            saveSession()
        }
    }
    @Published var splitGroups: [[UUID]] = [] {
        didSet {
            saveSession()
        }
    }
    @Published var splitRatios: [String: CGFloat] = [:] {
        didSet {
            saveSession()
        }
    }
    @Published var isResizingSplit: Bool = false
    @Published var folders: [TabFolder] = [] {
        didSet {
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
    /// Navigation state for every live webview. Split-pane chrome observes
    /// these values instead of reading non-observable WKWebView properties.
    @Published var tabLoadingStates: [UUID: Bool] = [:]
    @Published var tabEstimatedProgress: [UUID: Double] = [:]
    @Published var activeThemeColor: Color? = nil
    @Published var activeThemeNSColor: NSColor? = nil
    @Published var isThemeLight: Bool = false
    @Published var isWebInputFocused: Bool = false
    @Published var isQuitConfirmationPresented: Bool = false
    @Published var folderToCloseConfirmation: UUID? = nil
    @Published var pendingPopupRequest: PopupConfirmationRequest? = nil
    @Published var isClearAllDataConfirmationPresented: Bool = false
    @Published var isCommandPaletteOpen: Bool = false
    @Published var commandPaletteMode: CommandPaletteMode = .newTab
    @Published var isFindPresented: Bool = false
    @Published var findQuery: String = ""
    @Published var findCurrentMatch: Int = 0
    @Published var findTotalMatches: Int = 0
    @Published var findFocusTrigger: Int = 0
    @Published var focusAddressBarTabId: UUID? = nil
    @Published var urlCopyFeedback: URLCopyFeedback? = nil
    @Published var activeTabDrag: TabDragState? = nil
    @Published var selectedSidebarTabIds: Set<UUID> = []
    var sidebarSelectionAnchorId: UUID? = nil
    @Published var tabZoomLevels: [UUID: CGFloat] = [:] {
        didSet {
            saveSession()
        }
    }
    @Published var lastZoomChangeDirection: [UUID: Bool] = [:]
    @Published var pageLoadErrors: [UUID: PageLoadError] = [:]
    @Published var httpAllowedDomains: Set<String> = []
    @Published var tabMediaStates: [UUID: TabMediaState] = [:]
    @Published var detectedOpenSearch: [UUID: OpenSearchDescriptor] = [:]
    var tabServerTrusts: [UUID: SecTrust] = [:]
    let isPrivate: Bool


    static let zoomSteps: [CGFloat] = [
        0.50, 0.67, 0.75, 0.80, 0.90, 1.0, 1.10, 1.25, 1.50, 1.75, 2.0, 2.50, 3.0
    ]

    func zoomLevel(for tabId: UUID? = nil) -> CGFloat {
        let id = tabId ?? selectedTabId
        if url(for: id)?.isLotusPage == true {
            return 1.0
        }
        return tabZoomLevels[id] ?? 1.0
    }

    func setZoomLevel(_ level: CGFloat, for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        guard url(for: id)?.isLotusPage != true else { return }
        let clamped = min(3.0, max(0.5, (round(level * 100) / 100)))
        let previous = tabZoomLevels[id] ?? 1.0
        lastZoomChangeDirection[id] = clamped >= previous
        tabZoomLevels[id] = clamped
        if let webView = webViewStore[id] {
            webView.pageZoom = clamped
        }
    }

    func zoomIn(for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        let current = zoomLevel(for: id)
        if let next = Self.zoomSteps.first(where: { $0 > current + 0.01 }) {
            setZoomLevel(next, for: id)
        } else {
            setZoomLevel(min(3.0, current + 0.25), for: id)
        }
    }

    func zoomOut(for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        let current = zoomLevel(for: id)
        if let prev = Self.zoomSteps.last(where: { $0 < current - 0.01 }) {
            setZoomLevel(prev, for: id)
        } else {
            setZoomLevel(max(0.5, current - 0.25), for: id)
        }
    }

    func resetZoom(for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        setZoomLevel(1.0, for: id)
    }

    func focusAddressBar(for tabId: UUID? = nil) {
        focusAddressBarTabId = tabId ?? selectedTabId
    }

    // MARK: - Recently Closed

    /// LIFO stack of recently closed tabs (capped at `maxRecentlyClosed`).
    var recentlyClosed: [ClosedTabRecord] = []
    let maxRecentlyClosed = 20

    // MARK: - Services & Stores

    let sessionStore = SessionStore()
    let historyStore = HistoryStore()
    @Published var historyEntries: [HistoryItem] = []
    let downloadStore = DownloadStore()
    @Published var downloads: [DownloadItem] = [] {
        didSet {
            updateDockProgress()
        }
    }
    let bookmarkStore = BookmarkStore()
    @Published var bookmarks: [BookmarkItem] = []
    @Published var activeFlyingDownload: FlyingDownloadPayload? = nil
    @Published var downloadCatchPulseTrigger: Int = 0
    @Published var themeBloomTrigger: [UUID: Int] = [:]
    @Published var pageLoadShimmerTrigger: [UUID: Int] = [:]
    @Published var shieldDeflectTrigger: [UUID: Int] = [:]
    private var lastShieldDeflectTime: [UUID: Date] = [:]
    var initialShimmerPlayedTabs: Set<UUID> = []

    func triggerPageLoadShimmer(for tabId: UUID) {
        // Only trigger shimmer on the tab's initial load/creation, not on reloads or redirects
        guard !initialShimmerPlayedTabs.contains(tabId) else { return }
        initialShimmerPlayedTabs.insert(tabId)
        pageLoadShimmerTrigger[tabId, default: 0] += 1
    }

    func triggerShieldDeflect(for tabId: UUID) {
        let now = Date()
        if let last = lastShieldDeflectTime[tabId], now.timeIntervalSince(last) < 1.0 {
            return
        }
        lastShieldDeflectTime[tabId] = now
        shieldDeflectTrigger[tabId, default: 0] += 1
    }
    var customDownloadDirectory: URL?
    var urlCopyFeedbackDismissalWorkItem: DispatchWorkItem?

    var activeDownloadsCount: Int {
        downloads.filter { $0.state == .downloading }.count
    }

    var hasActiveDownloads: Bool {
        activeDownloadsCount > 0
    }

    var overallDownloadProgress: Double {
        let active = downloads.filter { $0.state == .downloading }
        guard !active.isEmpty else { return 0.0 }
        let totalFraction = active.reduce(0.0) { $0 + $1.progressFraction }
        return totalFraction / Double(active.count)
    }

    var lastContextMenuImageURL: URL?
    var lastContextMenuLinkURL: URL?
    var lastContextMenuSelectedText: String?

    func triggerFlyingDownloadAnimation(filename: String, iconName: String, startLocation: CGPoint? = nil) {
        let start = startLocation ?? FlyingDownloadView.currentMouseWindowLocation()
        let tab = activeTab
        let faviconColors = tab?.faviconURL.flatMap { FaviconColorExtractor.shared.colors(for: $0) }
        let faviconColor = tab?.faviconURL.flatMap { FaviconColorExtractor.shared.color(for: $0) } ?? activeThemeColor
        let isLight = isThemeLight
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.activeFlyingDownload = FlyingDownloadPayload(
                filename: filename,
                iconName: iconName,
                startPoint: start,
                themeColor: faviconColor,
                gradientColors: faviconColors,
                isThemeLight: isLight
            )
        }
    }

    var pendingSaveWorkItem: DispatchWorkItem?
    let saveDebounceInterval: TimeInterval = 0.5
    var automaticFolderNameTasks: [UUID: Task<Void, Never>] = [:]
    var automaticFolderNameGenerationIDs: [UUID: UUID] = [:]
    var automaticFolderNameLastGeneratedInputs: [UUID: AutomaticFolderNameInput] = [:]

    var terminationObserver: NSObjectProtocol?
    private var keyMonitor: Any?

    static let alwaysQuitKey = "lotus.always_quit_without_confirming"
    static let autoFolderNamesKey = "lotus.browser.autoFolderNames"

    var isAutoFolderNamesEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.autoFolderNamesKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: Self.autoFolderNamesKey)
    }

    /// Tabs whose playing video was auto-detached into Picture in Picture
    /// when the user switched away (see `BrowserState+PictureInPicture`).
    var autoPiPTabs: Set<UUID> = []

    var themeColors: [UUID: ParsedThemeColor] = [:]
    var webViewStore: [UUID: WKWebView] = [:]
    var observers: [UUID: [NSKeyValueObservation]] = [:]

    // MARK: - Focus

    var isAnyTextInputFocused: Bool {
        if isCommandPaletteOpen || isFindPresented || folderToCloseConfirmation != nil || isQuitConfirmationPresented || pendingPopupRequest != nil || isClearAllDataConfirmationPresented {
            return true
        }
        if let responder = NSApp.keyWindow?.firstResponder {
            if responder is NSTextView || responder is NSTextField {
                return true
            }
        }
        return isWebInputFocused
    }

    // MARK: - Lifecycle

    init(tabs: [TabItem]? = nil, initialSelectedId: UUID? = nil, isPrivate: Bool = false) {
        self.isPrivate = isPrivate
        let store = SessionStore()
        let restoredSession = (!isPrivate && tabs == nil) ? store.load() : nil
        let startupBehavior = isPrivate ? "empty" : (UserDefaults.standard.string(forKey: "lotus.browser.startupBehavior") ?? "restore")

        if isPrivate {
            self.tabs = []
            self.folders = []
            self.selectedTabId = UUID()
            self.splitGroups = []
            self.currentTabIds = []
            self.isCommandPaletteOpen = true
        } else if let explicitTabs = tabs {
            self.tabs = explicitTabs
            let sel = initialSelectedId ?? explicitTabs.first?.id ?? UUID()
            self.selectedTabId = sel
            self.splitGroups = []
            self.currentTabIds = [sel]
        } else if startupBehavior == "empty" {
            self.tabs = []
            self.folders = []
            self.selectedTabId = UUID()
            self.splitGroups = []
            self.currentTabIds = []
            self.isCommandPaletteOpen = true
        } else if let session = restoredSession {
            // Migration: the lotus://newtab page no longer exists — drop any
            // blank new-tab pages persisted by older versions.
            var restoredTabs = session.tabs.filter { !($0.url?.isLotusPage == true && $0.url?.host != "history") }
            
            if startupBehavior == "pinnedOnly" {
                restoredTabs = restoredTabs.filter { $0.isPinned }
            }

            // Restore folders; clear membership that points at a missing
            // folder, and never let pinned tabs carry folder membership.
            let restoredFolders = (startupBehavior == "pinnedOnly") ? [] : (session.folders ?? [])
            let folderIds = Set(restoredFolders.map { $0.id })
            restoredTabs = restoredTabs.map { tab in
                var tab = tab
                if let folderId = tab.folderId, !folderIds.contains(folderId) || tab.isPinned {
                    tab.folderId = nil
                }
                return tab
            }
            self.folders = restoredFolders
            self.tabs = restoredTabs
            let sel = restoredTabs.contains(where: { $0.id == session.selectedTabId }) ? session.selectedTabId : (restoredTabs.first?.id ?? UUID())
            self.selectedTabId = sel
            let validTabsSet = Set(restoredTabs.map { $0.id })
            let validGroups = (startupBehavior == "pinnedOnly") ? [] : (session.splitGroups ?? []).map { group in
                group.filter { validTabsSet.contains($0) }
            }.filter { $0.count >= 2 }
            self.splitGroups = validGroups
            self.splitRatios = (startupBehavior == "pinnedOnly") ? [:] : (session.splitRatios ?? [:])
            if restoredTabs.isEmpty {
                self.currentTabIds = []
                self.isCommandPaletteOpen = true
            } else if let saved = session.currentTabIds, saved.count >= 2, startupBehavior != "pinnedOnly" {
                let valid = saved.filter { validTabsSet.contains($0) }
                self.currentTabIds = valid.isEmpty ? [sel] : valid
            } else if let group = validGroups.first(where: { $0.contains(sel) }) {
                self.currentTabIds = group
            } else {
                self.currentTabIds = [sel]
            }
            self.recentlyClosed = session.recentlyClosed
            self.isSidebarVisible = session.isSidebarVisible
            self.sidebarWidth = session.sidebarWidth
            if let savedZooms = session.tabZoomLevels {
                var loadedZooms: [UUID: CGFloat] = [:]
                for (key, val) in savedZooms {
                    if let uuid = UUID(uuidString: key), validTabsSet.contains(uuid) {
                        loadedZooms[uuid] = val
                    }
                }
                self.tabZoomLevels = loadedZooms
            }
        } else {
            self.tabs = TabItem.samples
            let sel = TabItem.samples.first?.id ?? UUID()
            self.selectedTabId = sel
            self.splitGroups = []
            self.currentTabIds = [sel]
        }
        super.init()
        self.historyEntries = historyStore.load()
        self.downloads = downloadStore.load()
        self.bookmarks = bookmarkStore.load()
        self.restoreDownloadLocation()
        self.updateNavigationState()
        // Initialize webviews for the currently visible tab(s) so they begin loading immediately
        for tabId in currentTabIds {
            _ = getWebView(for: tabId)
        }
        self.setupTerminationObserver()
        self.setupKeyMonitor()
    }

    deinit {
        urlCopyFeedbackDismissalWorkItem?.cancel()
        customDownloadDirectory?.stopAccessingSecurityScopedResource()
        if let obs = terminationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let km = keyMonitor {
            NSEvent.removeMonitor(km)
        }
    }

    // MARK: - Granular Website Data Management

    /// Fetches all stored website data records (cookies, cache, localStorage, IndexedDB) from WebKit.
    func fetchWebsiteDataRecords(completion: @escaping ([WKWebsiteDataRecord]) -> Void) {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: types) { records in
            DispatchQueue.main.async {
                completion(records)
            }
        }
    }

    /// Removes data for specific website data records.
    func removeWebsiteData(records: [WKWebsiteDataRecord], completion: (() -> Void)? = nil) {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(ofTypes: types, for: records) {
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    /// Removes cookies and stored data for a specific domain host name.
    func removeWebsiteData(for host: String, completion: (() -> Void)? = nil) {
        let cleanHost = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let domainOnly = cleanHost.hasPrefix("www.") ? String(cleanHost.dropFirst(4)) : cleanHost
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: types) { [weak self] records in
            let matched = records.filter { record in
                let recordHost = record.displayName.lowercased()
                return recordHost == cleanHost || recordHost == domainOnly || recordHost.hasSuffix("." + domainOnly)
            }
            guard !matched.isEmpty else {
                DispatchQueue.main.async { completion?() }
                return
            }
            WKWebsiteDataStore.default().removeData(ofTypes: types, for: matched) {
                DispatchQueue.main.async {
                    if let activeWV = self?.webViewStore[self?.selectedTabId ?? UUID()],
                       let url = activeWV.url, url.host?.lowercased().contains(domainOnly) == true {
                        activeWV.reload()
                    }
                    completion?()
                }
            }
        }
    }

    // MARK: - Clear All Data

    /// Clears all browsing data: WebKit website data (cookies, cache, IndexedDB, local storage, WebAuthn credentials),
    /// browsing history, downloads records, and favicon/color caches.
    func clearAllBrowserData(completion: (() -> Void)? = nil) {
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let sinceDate = Date.distantPast
        WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: sinceDate) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion?()
                    return
                }

                self.historyStore.clearAll(entries: &self.historyEntries)
                self.downloadStore.clearAll(entries: &self.downloads)
                FaviconColorExtractor.shared.clearCache()

                for webView in self.webViewStore.values {
                    webView.reload()
                }

                completion?()
            }
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
