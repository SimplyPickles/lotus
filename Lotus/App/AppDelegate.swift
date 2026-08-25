//
//  AppDelegate.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var sharedBrowserState: BrowserState?
    static var isForcedTermination: Bool = false

    override init() {
        super.init()
        NSWindow.allowsAutomaticWindowTabbing = false
        NSResponder.suppressUnhandledKeyBeep()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    static func forceTerminate() {
        isForcedTermination = true
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.isForcedTermination || UserDefaults.standard.bool(forKey: BrowserState.alwaysQuitKey) {
            return .terminateNow
        }

        if let browserState = Self.sharedBrowserState {
            DispatchQueue.main.async {
                browserState.requestQuit()
            }
            return .terminateCancel
        }

        return .terminateNow
    }
}
