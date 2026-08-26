//
//  BrowserState+SessionPersistence.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation
import SwiftUI

extension BrowserState {

    func makeSessionSnapshot() -> BrowserSessionData {
        // An empty tabs list is a legitimate state now that closing the last
        // tab surfaces the command palette instead of a blank new-tab page.
        var zoomDict: [String: CGFloat] = [:]
        for (id, zoom) in tabZoomLevels {
            if zoom != 1.0 {
                zoomDict[id.uuidString] = zoom
            }
        }

        var selectedDict: [String: UUID] = [:]
        for (profId, tabId) in lastSelectedTabPerProfile {
            selectedDict[profId.uuidString] = tabId
        }

        var currentsDict: [String: [UUID]] = [:]
        for (profId, tabIds) in lastCurrentTabsPerProfile {
            currentsDict[profId.uuidString] = tabIds
        }

        return BrowserSessionData(
            tabs: tabs,
            selectedTabId: selectedTabId,
            currentTabIds: currentTabIds,
            splitGroups: splitGroups,
            splitRatios: splitRatios,
            folders: folders,
            recentlyClosed: recentlyClosed,
            isSidebarVisible: isSidebarVisible,
            sidebarWidth: sidebarWidth,
            tabZoomLevels: zoomDict.isEmpty ? nil : zoomDict,
            currentProfileId: currentProfileId,
            lastSelectedTabPerProfile: selectedDict.isEmpty ? nil : selectedDict,
            lastCurrentTabsPerProfile: currentsDict.isEmpty ? nil : currentsDict
        )
    }

    func saveSession(immediate: Bool = false) {
        guard !isPrivate else { return }
        if immediate {
            pendingSaveWorkItem?.cancel()
            pendingSaveWorkItem = nil
            let session = makeSessionSnapshot()
            sessionStore.save(session)
        } else {
            pendingSaveWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                let session = self.makeSessionSnapshot()
                self.sessionStore.saveAsync(session)
            }
            pendingSaveWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
        }
    }

    func setupTerminationObserver() {
        guard terminationObserver == nil else { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveSession(immediate: true)
        }
    }
}
