//
//  BrowserState+Quit.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

extension BrowserState {

    // MARK: - Quit Flow

    /// Entry point for Cmd-Q and the app-termination delegate. Shows the
    /// confirmation sheet unless the user opted out.
    func requestQuit() {
        if isQuitConfirmationPresented {
            confirmQuit(alwaysQuit: false)
            return
        }
        if UserDefaults.standard.bool(forKey: Self.alwaysQuitKey) {
            confirmQuit(alwaysQuit: false)
            return
        }
        withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
            isQuitConfirmationPresented = true
        }
    }

    func cancelQuit() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.86)) {
            isQuitConfirmationPresented = false
        }
    }

    func confirmQuit(alwaysQuit: Bool = false) {
        if alwaysQuit {
            UserDefaults.standard.set(true, forKey: Self.alwaysQuitKey)
        }
        
        if ContentBlockerService.shared.clearDataOnQuit {
            clearAllBrowserData {
                AppDelegate.forceTerminate()
            }
            return
        }
        
        saveSession(immediate: true)
        isQuitConfirmationPresented = false
        AppDelegate.forceTerminate()
    }
}
