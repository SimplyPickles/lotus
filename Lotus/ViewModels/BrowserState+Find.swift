//
//  BrowserState+Find.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import WebKit

extension BrowserState {

    // MARK: - Find in Page Actions

    /// Opens the find bar on the active tab and requests search field focus.
    func openFind(for tabId: UUID? = nil) {
        withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
            isFindPresented = true
        }
        findFocusTrigger += 1
        let trimmed = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            performFind(for: tabId, query: findQuery, backwards: false, isNewQuery: true)
        }
    }

    /// Closes the find bar, clears all find highlights from the active web view,
    /// resets match counters, and returns focus to web content.
    func closeFind(for tabId: UUID? = nil) {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.86)) {
            isFindPresented = false
        }
        clearFindHighlights(for: tabId)
        findCurrentMatch = 0
        findTotalMatches = 0

        let targetId = tabId ?? selectedTabId
        if let wv = webViewStore[targetId] {
            let win = wv.window ?? NSApp.keyWindow
            win?.makeFirstResponder(wv)
        }
    }

    /// Toggles the find bar open/closed or refocuses and selects query text if already open.
    func toggleFind(for tabId: UUID? = nil) {
        if isFindPresented {
            findFocusTrigger += 1
        } else {
            openFind(for: tabId)
        }
    }

    /// Advances to the next search match on the page.
    func findNext(for tabId: UUID? = nil) {
        guard isFindPresented else {
            openFind(for: tabId)
            return
        }
        let trimmed = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if findTotalMatches > 0 {
            findCurrentMatch = (findCurrentMatch % findTotalMatches) + 1
        }
        performFind(for: tabId, query: findQuery, backwards: false, isNewQuery: false)
    }

    /// Moves to the previous search match on the page.
    func findPrevious(for tabId: UUID? = nil) {
        guard isFindPresented else {
            openFind(for: tabId)
            return
        }
        let trimmed = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if findTotalMatches > 0 {
            findCurrentMatch = findCurrentMatch <= 1 ? findTotalMatches : (findCurrentMatch - 1)
        }
        performFind(for: tabId, query: findQuery, backwards: true, isNewQuery: false)
    }

    /// Updates the current query text and triggers live search / match counting.
    func updateFindQuery(_ query: String, for tabId: UUID? = nil) {
        findQuery = query
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            clearFindHighlights(for: tabId)
            findCurrentMatch = 0
            findTotalMatches = 0
        } else {
            performFind(for: tabId, query: query, backwards: false, isNewQuery: true)
        }
    }

    // MARK: - WebKit Find Operations

    /// Executes finding on the target tab's WKWebView using WebKit's native find API
    /// and queries the DOM for the total match count when starting a new search.
    func performFind(for tabId: UUID? = nil, query: String, backwards: Bool = false, isNewQuery: Bool = false) {
        let targetId = tabId ?? selectedTabId
        guard url(for: targetId)?.isLotusPage != true else { return }
        let wv = getWebView(for: targetId)

        let config = WKFindConfiguration()
        config.backwards = backwards
        config.caseSensitive = false
        config.wraps = true

        wv.find(query, configuration: config) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if result.matchFound {
                    if isNewQuery && self.findCurrentMatch == 0 {
                        self.findCurrentMatch = 1
                    }
                } else {
                    if isNewQuery {
                        self.findCurrentMatch = 0
                        self.findTotalMatches = 0
                    }
                }
            }
        }

        if isNewQuery {
            let script = UserScripts.countMatchesScript(for: query, caseSensitive: false)
            wv.evaluateJavaScript(script) { [weak self] countResult, _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let count = countResult as? Int {
                        self.findTotalMatches = count
                        if count == 0 {
                            self.findCurrentMatch = 0
                        } else if self.findCurrentMatch == 0 {
                            self.findCurrentMatch = 1
                        }
                    }
                }
            }
        }
    }

    /// Clears native WebKit search highlights and selection ranges from the given or all tabs.
    func clearFindHighlights(for tabId: UUID? = nil) {
        if let targetId = tabId {
            if let wv = webViewStore[targetId] {
                clearWebViewFind(wv)
            }
        } else {
            for wv in webViewStore.values {
                clearWebViewFind(wv)
            }
        }
    }

    private func clearWebViewFind(_ wv: WKWebView) {
        let config = WKFindConfiguration()
        wv.find("", configuration: config) { _ in }
        wv.evaluateJavaScript(UserScripts.clearSelection, completionHandler: nil)
    }

    /// Handles tab switching while the find bar is presented.
    func syncFindOnTabSwitch(from oldTabId: UUID, to newTabId: UUID) {
        clearFindHighlights(for: oldTabId)
        let trimmed = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if isFindPresented && !trimmed.isEmpty {
            performFind(for: newTabId, query: findQuery, backwards: false, isNewQuery: true)
        }
    }
}
