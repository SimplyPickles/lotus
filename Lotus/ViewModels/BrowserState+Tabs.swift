//
//  BrowserState+Tabs.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import WebKit

extension BrowserState {

    private static let tabMutationAnimation = Animation.spring(
        response: 0.18,
        dampingFraction: 0.88,
        blendDuration: 0.02
    )

    // MARK: - Tab Accessors

    var pinnedTabs: [TabItem] {
        tabs.filter { $0.isPinned }
    }

    var unpinnedTabs: [TabItem] {
        tabs.filter { !$0.isPinned }
    }

    /// Tabs in visual order: pinned grid first, then unpinned rows left-to-right, top-to-bottom.
    var orderedTabs: [TabItem] {
        var result: [TabItem] = pinnedTabs
        var handledIds = Set<UUID>()
        let unpinned = unpinnedTabs

        for tab in unpinned {
            if handledIds.contains(tab.id) {
                continue
            }

            if let group = splitGroup(containing: tab.id),
               group.count == 2,
               let partnerId = group.first(where: { $0 != tab.id }),
               let partnerTab = unpinned.first(where: { $0.id == partnerId }) {
                let firstTab = group[0] == tab.id ? tab : partnerTab
                let secondTab = group[0] == tab.id ? partnerTab : tab
                result.append(firstTab)
                result.append(secondTab)
                handledIds.insert(firstTab.id)
                handledIds.insert(secondTab.id)
            } else {
                result.append(tab)
                handledIds.insert(tab.id)
            }
        }

        return result
    }

    var activeTab: TabItem? {
        tab(for: selectedTabId) ?? tabs.first
    }

    var activeURL: URL? {
        activeTab?.url
    }

    var activeWebView: WKWebView {
        getWebView(for: selectedTabId)
    }

    var currentTabs: [TabItem] {
        currentTabIds.compactMap { tab(for: $0) }
    }

    func tab(for id: UUID) -> TabItem? {
        tabs.first(where: { $0.id == id })
    }

    func url(for id: UUID) -> URL? {
        tab(for: id)?.url
    }

    func renameTab(id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].title = trimmed
    }

    func splitGroup(containing id: UUID) -> [UUID]? {
        splitGroups.first(where: { $0.contains(id) })
    }

    func isSplit(id: UUID) -> Bool {
        splitGroup(containing: id) != nil
    }

    func splitPartner(for id: UUID) -> TabItem? {
        guard let group = splitGroup(containing: id), group.count == 2,
              let partnerId = group.first(where: { $0 != id }) else {
            return nil
        }
        return tab(for: partnerId)
    }

    func splitPair(for id: UUID) -> (TabItem, TabItem)? {
        guard let group = splitGroup(containing: id), group.count == 2,
              let t1 = tab(for: group[0]),
              let t2 = tab(for: group[1]) else {
            return nil
        }
        return (t1, t2)
    }

    // MARK: - Split Ratios

    func splitKey(for group: [UUID]) -> String {
        group.map { $0.uuidString }.joined(separator: "_")
    }

    func splitRatio(for group: [UUID]) -> CGFloat {
        guard group.count >= 2 else { return 0.5 }
        let key = splitKey(for: group)
        if let saved = splitRatios[key] {
            return max(0.15, min(0.85, saved))
        }
        return 0.5
    }

    func splitRatio(for tabId: UUID) -> CGFloat {
        if let group = splitGroup(containing: tabId) {
            return splitRatio(for: group)
        }
        return 0.5
    }

    func setSplitRatio(_ ratio: CGFloat, for group: [UUID], save: Bool = true) {
        guard group.count >= 2 else { return }
        let key = splitKey(for: group)
        let clamped = max(0.15, min(0.85, ratio))
        if save {
            splitRatios[key] = clamped
        } else {
            var updated = splitRatios
            updated[key] = clamped
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                splitRatios = updated
            }
        }
    }

    // MARK: - Selection

    func updateLastViewedTimestamp(for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].lastViewedAt = Date()
    }

    func selectTab(_ id: UUID) {
        expandFolderIfNeeded(containing: id)
        selectOnlySidebarUnit(containing: id)
        activateTabContent(id)
    }

    func activateTabContent(_ id: UUID) {
        if let group = splitGroup(containing: id) {
            if currentTabIds == group {
                selectedTabId = id
            } else {
                currentTabIds = group
                selectedTabId = id
            }
        } else {
            currentTabIds = [id]
            selectedTabId = id
        }
    }

    func selectTab(_ tab: TabItem) {
        selectTab(tab.id)
    }

    func selectNextTab() {
        let list = orderedTabs
        guard !list.isEmpty else { return }
        guard let currentIndex = list.firstIndex(where: { $0.id == selectedTabId }) else {
            selectTab(list[0].id)
            return
        }
        let nextIndex = (currentIndex + 1) % list.count
        selectTab(list[nextIndex].id)
    }

    func selectPreviousTab() {
        let list = orderedTabs
        guard !list.isEmpty else { return }
        guard let currentIndex = list.firstIndex(where: { $0.id == selectedTabId }) else {
            selectTab(list[0].id)
            return
        }
        let prevIndex = (currentIndex - 1 + list.count) % list.count
        selectTab(list[prevIndex].id)
    }

    func selectTabAtIndex(_ index: Int) {
        let list = orderedTabs
        guard !list.isEmpty else { return }
        if index == 8 {
            if let last = list.last {
                selectTab(last.id)
            }
        } else if index >= 0 && index < list.count {
            selectTab(list[index].id)
        }
    }

    // MARK: - Split Management

    enum SplitSide {
        case left
        case right
    }

    func canOpenInSplit(id: UUID) -> Bool {
        guard tabs.count >= 2 else { return false }
        guard currentTabIds.count < 2 else { return false }
        guard !currentTabIds.contains(id) else { return false }
        guard !isSplit(id: id) else { return false }
        if let currentActive = currentTabIds.first, isSplit(id: currentActive) {
            return false
        }
        return true
    }

    func splitTargetFrames(windowWidth: CGFloat, windowHeight: CGFloat) -> (left: CGRect, right: CGRect) {
        let sidebarW: CGFloat = sidebarWidth
        let browserLeft: CGFloat = sidebarW + 6
        let browserW: CGFloat = max(0, windowWidth - browserLeft - 6)
        let browserH: CGFloat = max(0, windowHeight - 12)
        let cardW: CGFloat = min(230, max(140, (browserW - 80) * 0.34))
        let cardH: CGFloat = min(340, max(160, browserH * 0.54))
        let cardCenterY: CGFloat = 6 + browserH / 2
        let edgeMargin: CGFloat = 48
        let leftCardCenterX: CGFloat = browserLeft + edgeMargin + cardW / 2
        let rightCardCenterX: CGFloat = browserLeft + browserW - edgeMargin - cardW / 2

        let leftFrame = CGRect(x: leftCardCenterX - cardW / 2, y: cardCenterY - cardH / 2, width: cardW, height: cardH)
        let rightFrame = CGRect(x: rightCardCenterX - cardW / 2, y: cardCenterY - cardH / 2, width: cardW, height: cardH)
        return (leftFrame, rightFrame)
    }

    func openInSplit(id: UUID, side: SplitSide = .right) {
        guard tabs.contains(where: { $0.id == id }) else { return }

        let leftId: UUID
        let rightId: UUID

        let currentActive = selectedTabId
        if side == .left {
            leftId = id
            rightId = (currentActive != id) ? currentActive : (tabs.first(where: { $0.id != id })?.id ?? id)
        } else {
            leftId = (currentActive != id) ? currentActive : (tabs.first(where: { $0.id != id })?.id ?? id)
            rightId = id
        }

        // When opening a split view with any pinned tab, unpin both tabs so they move to the regular tabstrip
        for tabId in [leftId, rightId] {
            if let index = tabs.firstIndex(where: { $0.id == tabId }), tabs[index].isPinned {
                tabs[index].isPinned = false
            }
        }

        // Clean up any existing split groups that include these tabs
        splitGroups.removeAll(where: { $0.contains(leftId) || $0.contains(rightId) })
        let newGroup = [leftId, rightId]
        splitGroups.append(newGroup)

        // A split pair must live in a single folder: unify on the anchor
        // (previously active) tab's folder. Skip when both are already loose
        // to preserve their positions.
        let anchorFolderId = tab(for: currentActive)?.folderId
        let pairFolderIds = Set([tab(for: leftId)?.folderId, tab(for: rightId)?.folderId])
        if pairFolderIds != [nil] {
            moveTab(id, toFolder: anchorFolderId)
        }

        currentTabIds = newGroup
        selectedTabId = id
    }

    func closeSplit(id: UUID) {
        splitGroups.removeAll(where: { $0.contains(id) })
        if currentTabIds.contains(id) && currentTabIds.count >= 2 {
            currentTabIds = [id]
            selectedTabId = id
        } else if !currentTabIds.contains(selectedTabId), let first = currentTabIds.first {
            selectedTabId = first
        }
    }

    /// Opens a new blank tab and immediately splits it to the right of the anchor tab.
    func openNewSplitTab(for anchorTabId: UUID? = nil) {
        let anchorId = anchorTabId ?? selectedTabId
        let newTab = addTabBelow(currentTabId: anchorId, title: "New Tab", url: nil, select: true)
        openInSplit(id: newTab.id, side: .right)
        DispatchQueue.main.async { [weak self] in
            self?.openCommandPaletteForCurrentTab()
        }
    }

    /// Swaps the left and right pane tabs in a split view group.
    func swapSplitTabs(for group: [UUID]) {
        guard group.count == 2 else { return }
        let first = group[0]
        let second = group[1]
        let oldRatio = splitRatio(for: group)

        // 1. Update split groups
        if let groupIndex = splitGroups.firstIndex(where: { $0 == group }) {
            splitGroups[groupIndex] = [second, first]
        }

        // 2. Update split ratios with inverted ratio
        let oldKey = splitKey(for: group)
        let newKey = splitKey(for: [second, first])
        splitRatios.removeValue(forKey: oldKey)
        splitRatios[newKey] = 1.0 - oldRatio

        // 3. Update currentTabIds if currently showing this split
        if currentTabIds == group {
            currentTabIds = [second, first]
        }

        // 4. Update tab order in tabs array so sidebar stays synchronized
        if let firstIdx = tabs.firstIndex(where: { $0.id == first }),
           let secondIdx = tabs.firstIndex(where: { $0.id == second }) {
            tabs.swapAt(firstIdx, secondIdx)
        }

        saveSession()
    }

    // MARK: - Add / Remove / Pin

    func togglePin(id: UUID) {
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            // Split tabs are not allowed to become pinned
            if !tabs[index].isPinned && isSplit(id: id) {
                return
            }
            tabs[index].isPinned.toggle()
            if tabs[index].isPinned {
                // Folders cannot be pinned — pinning removes folder membership.
                tabs[index].folderId = nil
                splitGroups.removeAll(where: { $0.contains(id) })
                if currentTabIds.contains(id) && currentTabIds.count >= 2 {
                    currentTabIds = [id]
                    selectedTabId = id
                }
            }
        }
    }

    func addTab(title: String = "New Tab", url: URL? = nil) {
        var newTab = TabItem(title: title, url: url)
        withAnimation(Self.tabMutationAnimation) {
            // A tab opened while a foldered tab is active joins that folder,
            // at the top (right under the header).
            if let folderId = activeTab?.folderId,
               let firstMember = tabs.firstIndex(where: { $0.folderId == folderId }) {
                newTab.folderId = folderId
                tabs.insert(newTab, at: firstMember)
            } else {
                let insertionIndex = tabs.lastIndex(where: \.isPinned).map { $0 + 1 } ?? 0
                tabs.insert(newTab, at: insertionIndex)
            }
            selectTab(newTab.id)
        }
    }

    @discardableResult
    func createTab(title: String = "New Tab", url: URL) -> TabItem {
        let tabPosition = UserDefaults.standard.string(forKey: "lotus.browser.newTabPosition") ?? "below"
        let newTab: TabItem
        if tabPosition == "end" {
            newTab = addTabAtEnd(title: title, url: url, select: true)
        } else {
            newTab = addTabBelow(title: title, url: url, select: true)
        }
        
        let shouldAutoCloseBlank = UserDefaults.standard.bool(forKey: "lotus.browser.autoCloseBlankTabs")
        if shouldAutoCloseBlank {
            autoCloseBlankTabsIfNeeded(except: newTab.id)
        }
        
        return newTab
    }

    @discardableResult
    func addTabAtEnd(title: String = "New Tab", url: URL? = nil, select: Bool = true) -> TabItem {
        let newTab = TabItem(title: title, url: url)
        withAnimation(Self.tabMutationAnimation) {
            tabs.append(newTab)
            if select {
                selectTab(newTab.id)
            }
        }
        return newTab
    }

    private func autoCloseBlankTabsIfNeeded(except keepId: UUID) {
        let blankTabs = tabs.filter { tab in
            tab.id != keepId && !tab.isPinned && (tab.url == nil || tab.url?.absoluteString == "about:blank")
        }
        for blank in blankTabs {
            removeTab(id: blank.id)
        }
    }

    @discardableResult
    func addTabBelow(currentTabId: UUID? = nil, title: String = "New Tab", url: URL? = nil, select: Bool = true) -> TabItem {
        var newTab = TabItem(title: title, url: url)
        let targetId = currentTabId ?? selectedTabId

        withAnimation(Self.tabMutationAnimation) {
            // Tabs opened from a foldered tab (⌘-click, popups, history)
            if let folderId = tab(for: targetId)?.folderId,
                let firstMember = tabs.firstIndex(where: { $0.folderId == folderId && $0.id == targetId }) {
                newTab.folderId = folderId
                tabs.insert(newTab, at: firstMember + 1)
            } else if tab(for: targetId)?.isPinned == true {
                let insertionIndex = tabs.lastIndex(where: \.isPinned).map { $0 + 1 } ?? 0
                tabs.insert(newTab, at: insertionIndex)
            } else if let currentIndex = tabs.firstIndex(where: { $0.id == targetId }) {
                tabs.insert(newTab, at: currentIndex + 1)
            } else {
                let insertionIndex = tabs.lastIndex(where: \.isPinned).map { $0 + 1 } ?? 0
                tabs.insert(newTab, at: insertionIndex)
            }

            if select {
                selectTab(newTab.id)
            }
        }
        return newTab
    }

    func removeTab(id: UUID) {
        withAnimation(Self.tabMutationAnimation) {
            performRemoveTab(id: id)
        }
    }

    private func performRemoveTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let closingTab = tabs[index]
        let partnerId = splitPartner(for: id)?.id
        let currentFolder = closingTab.folderId.flatMap { folder(for: $0) }
        let folderName = currentFolder?.name
        let folderColor = currentFolder?.color
        let folderNameOrigin = currentFolder?.nameOrigin

        let record = ClosedTabRecord(
            id: closingTab.id,
            title: closingTab.title,
            url: closingTab.url,
            isPinned: closingTab.isPinned,
            insertionIndex: index,
            folderId: closingTab.folderId,
            folderName: folderName,
            folderColor: folderColor,
            folderNameOrigin: folderNameOrigin,
            splitPartnerId: partnerId
        )
        recentlyClosed.append(record)
        if recentlyClosed.count > maxRecentlyClosed {
            recentlyClosed.removeFirst(recentlyClosed.count - maxRecentlyClosed)
        }

        tabs.remove(at: index)

        // Automatically delete folder if it has no remaining member tabs (except Archive)
        if let folderId = closingTab.folderId, let currentFolder = folder(for: folderId), !currentFolder.isArchive {
            if !tabs.contains(where: { $0.folderId == folderId }) {
                clearAutomaticFolderNameState(for: folderId)
                folders.removeAll(where: { $0.id == folderId })
            }
        }

        selectedSidebarTabIds.remove(id)
        if sidebarSelectionAnchorId == id {
            sidebarSelectionAnchorId = selectedSidebarTabIds.first
        }
        let closingWebView = webViewStore.removeValue(forKey: id)
        observers.removeValue(forKey: id)
        tabLoadingStates.removeValue(forKey: id)
        tabEstimatedProgress.removeValue(forKey: id)
        themeColors.removeValue(forKey: id)
        pageLoadShimmerTrigger.removeValue(forKey: id)
        initialShimmerPlayedTabs.remove(id)
        autoPiPTabs.remove(id)

        if let groupIndex = splitGroups.firstIndex(where: { $0.contains(id) }) {
            let remaining = splitGroups[groupIndex].filter { $0 != id }
            splitGroups.remove(at: groupIndex)
            if remaining.count >= 2 {
                splitGroups.append(remaining)
            }
        }

        if let currentIdx = currentTabIds.firstIndex(of: id) {
            currentTabIds.remove(at: currentIdx)
        }

        if selectedTabId == id {
            // Activate the tab just above the closed one in the strip.
            let list = orderedTabs
            if let closedIdx = list.firstIndex(where: { $0.id == id }), closedIdx > 0 {
                selectTab(list[closedIdx - 1].id)
            } else if let nextCurrent = currentTabIds.first {
                selectedTabId = nextCurrent
            } else if index < tabs.count {
                let nextId = tabs[index].id
                selectedTabId = nextId
                currentTabIds = [nextId]
            } else if let last = tabs.last {
                selectedTabId = last.id
                currentTabIds = [last.id]
            } else {
                // Last tab closed — no blank page to fall back to anymore;
                // surface the command palette instead.
                openCommandPalette()
            }
        } else if currentTabIds.isEmpty {
            if let first = tabs.first?.id {
                currentTabIds = [first]
                selectedTabId = first
            } else {
                openCommandPalette()
            }
        } else if tabs.isEmpty {
            openCommandPalette()
        }

        // Let SwiftUI render the tab-list mutation before doing WebKit cleanup.
        // A synchronous teardown here can block the first animation frame.
        if let closingWebView {
            DispatchQueue.main.async {
                if #available(macOS 12.0, *) {
                    closingWebView.pauseAllMediaPlayback()
                }
                closingWebView.evaluateJavaScript(UserScripts.pauseAllMedia, completionHandler: nil)
                closingWebView.stopLoading()
                closingWebView.navigationDelegate = nil
                closingWebView.uiDelegate = nil
                closingWebView.configuration.userContentController.removeAllScriptMessageHandlers()
                closingWebView.load(URLRequest(url: URL(string: "about:blank")!))
                closingWebView.removeFromSuperview()
            }
        }
    }

    func reopenLastClosedTab() {
        guard !recentlyClosed.isEmpty else { return }
        let record = recentlyClosed.removeLast()

        let newTab = TabItem(
            id: record.id,
            title: record.title,
            url: record.url,
            isPinned: record.isPinned,
            folderId: record.folderId
        )

        // Reopen folder if it was deleted or ensure existing folder is expanded
        if let folderId = record.folderId {
            if folder(for: folderId) == nil {
                let restoredFolder = TabFolder(
                    id: folderId,
                    name: record.folderName ?? "New Folder",
                    color: record.folderColor ?? .blue,
                    nameOrigin: record.folderNameOrigin ?? .manual
                )
                folders.append(restoredFolder)
            }
            expandFolder(id: folderId)
        }

        // Calculate insertion point:
        // If foldered and other members exist, insert adjacent to them; otherwise use saved index
        let insertAt: Int
        if let folderId = newTab.folderId,
           let lastMember = tabs.lastIndex(where: { $0.folderId == folderId }) {
            insertAt = lastMember + 1
        } else {
            let minUnpinned = tabs.lastIndex(where: \.isPinned).map { $0 + 1 } ?? 0
            var target = newTab.isPinned
                ? min(record.insertionIndex, minUnpinned)
                : min(max(record.insertionIndex, minUnpinned), tabs.count)
            if !newTab.isPinned, target > 0 {
                let prevFolderId = tabs[target - 1].folderId
                if let prevFolderId,
                   let lastMember = tabs.lastIndex(where: { $0.folderId == prevFolderId }),
                   lastMember >= target {
                    target = lastMember + 1
                }
            }
            insertAt = target
        }

        withAnimation(Self.tabMutationAnimation) {
            tabs.insert(newTab, at: insertAt)

            // Recreate split if original partner exists and is not currently in a new split
            if let partnerId = record.splitPartnerId,
               let partnerTab = tab(for: partnerId),
               !isSplit(id: partnerId) {
                // Unify folder membership with partner tab if needed
                if let partnerFolderId = partnerTab.folderId, newTab.folderId != partnerFolderId {
                    if let newTabIndex = tabs.firstIndex(where: { $0.id == newTab.id }) {
                        tabs[newTabIndex].folderId = partnerFolderId
                    }
                }

                let newGroup = [partnerId, newTab.id]
                splitGroups.append(newGroup)
                selectTab(newTab.id)
            } else {
                selectTab(newTab.id)
            }
        }

        if let url = record.url {
            let wv = getWebView(for: newTab.id)
            wv.load(URLRequest(url: url))
        }
    }

    // MARK: - Advanced Tab Operations

    func duplicateTab(id: UUID) {
        guard let originalTab = tab(for: id) else { return }
        let newTab = TabItem(
            title: originalTab.title,
            url: originalTab.url,
            isPinned: originalTab.isPinned,
            folderId: originalTab.folderId,
            customFaviconURL: originalTab.customFaviconURL
        )

        withAnimation(Self.tabMutationAnimation) {
            if let originalIndex = tabs.firstIndex(where: { $0.id == id }) {
                tabs.insert(newTab, at: originalIndex + 1)
            } else {
                tabs.append(newTab)
            }
            selectTab(newTab.id)
        }

        if let url = originalTab.url {
            let wv = getWebView(for: newTab.id)
            wv.load(URLRequest(url: url))
        }
    }

    func toggleMuteTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].isMuted.toggle()
        let isMuted = tabs[index].isMuted
        tabMediaStates[id]?.isMuted = isMuted

        if let wv = webViewStore[id] {
            // Apply media suspension and HTMLMediaElement muting
            let js = "if (window.__lotusSetMediaMuted) { window.__lotusSetMediaMuted(\(isMuted ? "true" : "false")); } else { document.querySelectorAll('video, audio').forEach(el => { el.muted = \(isMuted ? "true" : "false"); }); }"
            wv.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    func closeTabsBelow(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let targetFolderId = tabs[index].folderId

        let tabsToClose: [UUID]
        if let folderId = targetFolderId {
            // Close tabs below inside the same folder
            tabsToClose = tabs.suffix(from: index + 1)
                .filter { $0.folderId == folderId && !$0.isPinned }
                .map(\.id)
        } else {
            // Close all subsequent unpinned tabs
            tabsToClose = tabs.suffix(from: index + 1)
                .filter { !$0.isPinned }
                .map(\.id)
        }

        for tabId in tabsToClose {
            removeTab(id: tabId)
        }
    }

    func closeOtherTabs(id: UUID) {
        let tabsToClose = tabs.filter { $0.id != id && !$0.isPinned }.map(\.id)
        for tabId in tabsToClose {
            removeTab(id: tabId)
        }
    }

    func copyTabURL(id: UUID) {
        copyPageURL(for: id)
    }

    func moveTabToNewWindow(id: UUID) {
        guard let tab = tab(for: id), let url = tab.url else { return }
        // Open a new window and navigate to the tab URL, then close this tab
        NSApp.sendAction(NSSelectorFromString("newWindow:"), to: nil, from: nil)
        removeTab(id: id)
    }

    // MARK: - Sidebar

    func toggleSidebar() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            isSidebarVisible.toggle()
        }
    }
}
