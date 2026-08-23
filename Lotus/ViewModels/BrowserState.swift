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
        }
    }
    @Published var selectedTabId: UUID {
        didSet {
            updateNavigationState()
            syncFocusStateForActiveTab()
            handlePictureInPictureOnTabSwitch(from: oldValue, to: selectedTabId)
            syncFindOnTabSwitch(from: oldValue, to: selectedTabId)
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
    @Published var activeThemeColor: Color? = nil
    @Published var activeThemeNSColor: NSColor? = nil
    @Published var isThemeLight: Bool = false
    @Published var isWebInputFocused: Bool = false
    @Published var isQuitConfirmationPresented: Bool = false
    @Published var folderToCloseConfirmation: UUID? = nil
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
    var historyEntries: [HistoryItem] = []
    let downloadStore = DownloadStore()
    @Published var downloads: [DownloadItem] = []
    @Published var activeFlyingDownload: FlyingDownloadPayload? = nil
    @Published var downloadCatchPulseTrigger: Int = 0
    @Published var themeBloomTrigger: [UUID: Int] = [:]
    var downloadsMonitor: DownloadsFolderMonitor?
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

    func triggerFlyingDownloadAnimation(filename: String, iconName: String, startLocation: CGPoint? = nil) {
        let start = startLocation ?? FlyingDownloadView.currentMouseWindowLocation()
        let themeColor = activeThemeColor
        let isLight = isThemeLight
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.activeFlyingDownload = FlyingDownloadPayload(
                filename: filename,
                iconName: iconName,
                startPoint: start,
                themeColor: themeColor,
                isThemeLight: isLight
            )
        }
    }

    var pendingSaveWorkItem: DispatchWorkItem?
    let saveDebounceInterval: TimeInterval = 0.5

    var terminationObserver: NSObjectProtocol?
    private var keyMonitor: Any?

    static let alwaysQuitKey = "lotus.always_quit_without_confirming"

    /// Tabs whose playing video was auto-detached into Picture in Picture
    /// when the user switched away (see `BrowserState+PictureInPicture`).
    var autoPiPTabs: Set<UUID> = []

    var themeColors: [UUID: ParsedThemeColor] = [:]
    var webViewStore: [UUID: WKWebView] = [:]
    var observers: [UUID: [NSKeyValueObservation]] = [:]

    // MARK: - Focus

    var isAnyTextInputFocused: Bool {
        if isCommandPaletteOpen || isFindPresented || folderToCloseConfirmation != nil || isQuitConfirmationPresented {
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

    init(tabs: [TabItem]? = nil, initialSelectedId: UUID? = nil) {
        let store = SessionStore()
        let restoredSession = (tabs == nil) ? store.load() : nil
        if let explicitTabs = tabs {
            self.tabs = explicitTabs
            let sel = initialSelectedId ?? explicitTabs.first?.id ?? UUID()
            self.selectedTabId = sel
            self.splitGroups = []
            self.currentTabIds = [sel]
        } else if let session = restoredSession {
            // Migration: the lotus://newtab page no longer exists — drop any
            // blank new-tab pages persisted by older versions.
            var restoredTabs = session.tabs.filter { !($0.url?.isLotusPage == true && $0.url?.host != "history") }
            // Restore folders; clear membership that points at a missing
            // folder, and never let pinned tabs carry folder membership.
            let restoredFolders = session.folders ?? []
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
            let validGroups = (session.splitGroups ?? []).map { group in
                group.filter { validTabsSet.contains($0) }
            }.filter { $0.count >= 2 }
            self.splitGroups = validGroups
            self.splitRatios = session.splitRatios ?? [:]
            if restoredTabs.isEmpty {
                self.currentTabIds = []
                self.isCommandPaletteOpen = true
            } else if let saved = session.currentTabIds, saved.count >= 2 {
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
        self.restoreDownloadLocation()
        self.downloadsMonitor = DownloadsFolderMonitor(browserState: self)
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

    // MARK: - Key Monitor

    private func setupKeyMonitor() {
        LotusShortcuts.debugAssertNoConflicts()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return KeyboardShortcutRouter.handleKeyEvent(event, browserState: self)
        }
    }
}
