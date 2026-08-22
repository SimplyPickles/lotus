//
//  ContentView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var sharedBrowserState: BrowserState?
    static var isForcedTermination: Bool = false

    override init() {
        super.init()
        NSResponder.suppressUnhandledKeyBeep()
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

// MARK: - Unhandled Key Beep Suppression

extension NSResponder {
    private static var hasSwizzledNoResponder = false

    static func suppressUnhandledKeyBeep() {
        guard !hasSwizzledNoResponder else { return }
        hasSwizzledNoResponder = true

        let originalSelector = #selector(NSResponder.noResponder(for:))
        let swizzledSelector = #selector(NSResponder.lotus_noResponder(for:))

        guard let originalMethod = class_getInstanceMethod(NSResponder.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(NSResponder.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc private func lotus_noResponder(for selector: Selector) {
        if selector == #selector(NSResponder.keyDown(with:)) || selector == #selector(NSResponder.keyUp(with:)) {
            // Suppress the default error sound (NSBeep) when a key is pressed and unhandled
            return
        }
        lotus_noResponder(for: selector)
    }
}

@main
struct LotusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
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

struct ContentView: View {
    @StateObject private var browserState = BrowserState()
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHoveringFloatingSidebar: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                if browserState.isSidebarVisible || (browserState.isResizingSidebar && !isHoveringFloatingSidebar) {
                    Tabstrip(browserState: browserState)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(1)
                }

                BrowserContainer(browserState: browserState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(0)
            }

            // Hover trigger zone on the left edge when sidebar is collapsed
            if !browserState.isSidebarVisible && !isHoveringFloatingSidebar && !browserState.isResizingSidebar {
                Color.white.opacity(0.0001)
                    .frame(width: 18)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                isHoveringFloatingSidebar = true
                            }
                        }
                    }
                    .zIndex(5)
            }

            // Floating sidebar overlay when collapsed and hovered
            if !browserState.isSidebarVisible && (isHoveringFloatingSidebar || browserState.isResizingSidebar) {
                floatingSidebar
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(frostedGlassBackground)
        .background(TrafficLightPositioner(
            leading: (isHoveringFloatingSidebar && !browserState.isSidebarVisible) ? 22 : 20,
            top: (isHoveringFloatingSidebar && !browserState.isSidebarVisible) ? 22 : 20,
            isVisible: browserState.isSidebarVisible || isHoveringFloatingSidebar || browserState.isResizingSidebar
        ))
        .background {
            shortcutHandlers
        }
        .overlay {
            if browserState.isQuitConfirmationPresented {
                QuitConfirmationView(browserState: browserState)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: browserState.isSidebarVisible)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isHoveringFloatingSidebar)
        .onChange(of: browserState.isSidebarVisible) { visible in
            if visible {
                isHoveringFloatingSidebar = false
            }
        }
        .onAppear {
            AppDelegate.sharedBrowserState = browserState
        }
    }

    private var floatingSidebar: some View {
        Tabstrip(browserState: browserState)
            .background(
                ZStack {
                    VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)
                    (colorScheme == .dark ? Color.black.opacity(0.35) : Color(nsColor: .windowBackgroundColor).opacity(0.75))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14), radius: 14, x: 2, y: 1)
            .padding(3)
            .contentShape(Rectangle())
            .onHover { hovering in
                if !browserState.isResizingSidebar {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        isHoveringFloatingSidebar = hovering
                    }
                }
            }
    }

    private var shortcutHandlers: some View {
        Group {
            Button("") {
                browserState.toggleSidebar()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("") {
                browserState.addTab()
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    browserState.removeTab(id: browserState.selectedTabId)
                }
            }
            .keyboardShortcut("w", modifiers: .command)

            Button("") {
                browserState.reopenLastClosedTab()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Button("") {
                browserState.reload()
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("") {
                browserState.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("") {
                browserState.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)

            Button("") {
                browserState.requestQuit()
            }
            .keyboardShortcut("q", modifiers: .command)

            // Next Tab Shortcuts
            Button("") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    browserState.selectNextTab()
                }
            }
            .keyboardShortcut(.tab, modifiers: .control)

            Button("") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    browserState.selectNextTab()
                }
            }
            .keyboardShortcut(.tab, modifiers: .command)

            Button("") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    browserState.selectNextTab()
                }
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])

            Button("") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    browserState.selectNextTab()
                }
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])

            // Previous Tab Shortcuts
            Button("") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    browserState.selectPreviousTab()
                }
            }
            .keyboardShortcut(.tab, modifiers: [.control, .shift])

            Button("") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    browserState.selectPreviousTab()
                }
            }
            .keyboardShortcut(.tab, modifiers: [.command, .shift])

            Button("") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    browserState.selectPreviousTab()
                }
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])

            Button("") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    browserState.selectPreviousTab()
                }
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

            ForEach(1...9, id: \.self) { index in
                Button("") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        browserState.selectTabAtIndex(index - 1)
                    }
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
            }
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .focusable(false)
    }

    private var frostedGlassBackground: some View {
        VisualEffectView(
            material: .underWindowBackground,
            blendingMode: .behindWindow,
            state: .active
        )
        .overlay(colorScheme == .dark ? Color.black.opacity(0.12) : Color.white.opacity(0.05))
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
