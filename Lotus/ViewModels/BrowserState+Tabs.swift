//
//  BrowserState+Tabs.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import WebKit

extension BrowserState {

    // MARK: - Tab Accessors

    var pinnedTabs: [TabItem] {
        tabs.filter { $0.isPinned }
    }

    var unpinnedTabs: [TabItem] {
        tabs.filter { !$0.isPinned }
    }

    /// Tabs in visual order: pinned grid first, then the unpinned list.
    var orderedTabs: [TabItem] {
        pinnedTabs + unpinnedTabs
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

    // MARK: - Selection

    func selectTab(_ id: UUID) {
        selectedTabId = id
    }

    func selectTab(_ tab: TabItem) {
        selectedTabId = tab.id
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

    // MARK: - Add / Remove / Pin

    func togglePin(id: UUID) {
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs[index].isPinned.toggle()
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
            wv.evaluateJavaScript(UserScripts.pauseAllMedia, completionHandler: nil)
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

    // MARK: - Sidebar

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }
}
