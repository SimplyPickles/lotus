//
//  LotusApp.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI

@main
struct LotusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("lotus.browser.appearance") private var appearanceMode: String = "system"

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        // The id lets views open additional windows programmatically via
        // `openWindow(id: "main")` (toolbar ellipsis menu → New Window).
        WindowGroup(id: "main") {
            ContentView()
                .preferredColorScheme(preferredColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Lotus") {
                    if let browserState = AppDelegate.sharedBrowserState {
                        browserState.requestQuit()
                    } else {
                        NSApp.terminate(nil)
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
