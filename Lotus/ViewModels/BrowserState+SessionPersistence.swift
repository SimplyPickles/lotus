//
//  BrowserState+SessionPersistence.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation
import SwiftUI

extension BrowserState {

    func saveSession() {
        guard !tabs.isEmpty else { return }
        let session = BrowserSessionData(
            tabs: tabs,
            selectedTabId: selectedTabId,
            recentlyClosed: recentlyClosed,
            isSidebarVisible: isSidebarVisible,
            sidebarWidth: sidebarWidth
        )
        sessionStore.save(session)
    }

    func setupTerminationObserver() {
        guard terminationObserver == nil else { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveSession()
        }
    }
}
