//
//  KeyboardShortcuts.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

/// A single declarative entry in the app-wide keyboard shortcut table.
///
/// Every keyboard shortcut in Lotus must be registered here so that conflicts
/// are visible in one place. Entries are consumed by two routes:
/// - `GlobalShortcutHandlers` renders each entry as an invisible SwiftUI
///   `Button` (the standard pattern for in-window shortcuts).
/// - `BrowserState`'s `NSEvent` monitor routes matching key-down events
///   through the same table for entries with `usesEventMonitor == true`
///   (shortcuts SwiftUI can't reliably intercept while web content is
///   first responder).
struct LotusShortcut: Identifiable {
    let id: String
    let key: KeyEquivalent
    let modifiers: EventModifiers
    /// Skipped when a text field / web input is first responder.
    let guardsTextInput: Bool
    /// Routed through BrowserState's NSEvent key-down monitor instead of
    /// (or in addition to) an invisible SwiftUI button.
    let usesEventMonitor: Bool
    let action: (BrowserState) -> Void

    init(
        _ id: String,
        key: KeyEquivalent,
        modifiers: EventModifiers,
        guardsTextInput: Bool = false,
        usesEventMonitor: Bool = false,
        action: @escaping (BrowserState) -> Void
    ) {
        self.id = id
        self.key = key
        self.modifiers = modifiers
        self.guardsTextInput = guardsTextInput
        self.usesEventMonitor = usesEventMonitor
        self.action = action
    }

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("^") }
        switch key {
        case .leftArrow: parts.append("←")
        case .rightArrow: parts.append("→")
        case .tab: parts.append("⇥")
        default: parts.append(String(key.character))
        }
        return parts.joined()
    }
}

// MARK: - Shortcut Table

/// The single source of truth for all Lotus keyboard shortcuts.
enum LotusShortcuts {

    private static func animated(_ perform: @escaping (BrowserState) -> Void) -> (BrowserState) -> Void {
        { state in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                perform(state)
            }
        }
    }

    static let table: [LotusShortcut] = [
        // MARK: Window & Tabs
        LotusShortcut("toggleSidebar", key: "s", modifiers: .command) {
            $0.toggleSidebar()
        },
        LotusShortcut("newTab", key: "t", modifiers: .command) {
            $0.addTab()
        },
        LotusShortcut("closeTab", key: "w", modifiers: .command, action: animated {
            $0.removeTab(id: $0.selectedTabId)
        }),
        LotusShortcut("reopenClosedTab", key: "t", modifiers: [.command, .shift]) {
            $0.reopenLastClosedTab()
        },

        // MARK: Navigation
        LotusShortcut("reload", key: "r", modifiers: .command) {
            $0.reload()
        },
        LotusShortcut("back", key: "[", modifiers: .command) {
            $0.goBack()
        },
        LotusShortcut("forward", key: "]", modifiers: .command) {
            $0.goForward()
        },
        // Arrow-key navigation must go through the NSEvent monitor: SwiftUI
        // keyboard shortcuts are unreliable while WKWebView is first responder.
        LotusShortcut("backArrow", key: .leftArrow, modifiers: .command,
                      guardsTextInput: true, usesEventMonitor: true) {
            $0.goBack()
        },
        LotusShortcut("forwardArrow", key: .rightArrow, modifiers: .command,
                      guardsTextInput: true, usesEventMonitor: true) {
            $0.goForward()
        },

        // MARK: Tab Selection
        LotusShortcut("nextTabControlTab", key: .tab, modifiers: .control, action: animated {
            $0.selectNextTab()
        }),
        LotusShortcut("nextTabCommandTab", key: .tab, modifiers: .command, action: animated {
            $0.selectNextTab()
        }),
        LotusShortcut("nextTabBracket", key: "]", modifiers: [.command, .shift], action: animated {
            $0.selectNextTab()
        }),
        LotusShortcut("nextTabArrow", key: .rightArrow, modifiers: [.command, .option], action: animated {
            $0.selectNextTab()
        }),
        LotusShortcut("previousTabControlTab", key: .tab, modifiers: [.control, .shift], action: animated {
            $0.selectPreviousTab()
        }),
        LotusShortcut("previousTabCommandTab", key: .tab, modifiers: [.command, .shift], action: animated {
            $0.selectPreviousTab()
        }),
        LotusShortcut("previousTabBracket", key: "[", modifiers: [.command, .shift], action: animated {
            $0.selectPreviousTab()
        }),
        LotusShortcut("previousTabArrow", key: .leftArrow, modifiers: [.command, .option], action: animated {
            $0.selectPreviousTab()
        }),
    ] + (1...9).map { index in
        LotusShortcut("selectTab\(index)", key: KeyEquivalent(Character("\(index)")), modifiers: .command, action: animated {
            $0.selectTabAtIndex(index - 1)
        })
    }

    /// Shortcuts that live outside this table because they need view-local
    /// state. Listed here so conflicts remain visible in one place.
    ///
    /// | Shortcut | Location                        | Why it's local             |
    /// |----------|---------------------------------|----------------------------|
    /// | ⌘L       | `BrowserContainer` URL field    | Needs the `@FocusState`    |
    /// | ⌘Q       | Menu bar (`LotusApp.commands`)  | Standard menu-item route   |
    /// | Esc/↩    | `QuitConfirmationView` buttons  | Sheet-local default/cancel |
    static let localExceptions: [String] = [
        "⌘L — Focus URL bar (BrowserContainer, @FocusState)",
        "⌘Q — Quit (menu bar CommandGroup → requestQuit)",
        "Esc / ↩ — Quit confirmation sheet buttons",
    ]

    /// All entries routed through the NSEvent key-down monitor.
    static var eventMonitorEntries: [LotusShortcut] {
        table.filter { $0.usesEventMonitor }
    }

    /// Surfaces conflicting registrations (same key + modifiers appearing
    /// more than once). Intentionally allows exact duplicates created by
    /// multiple bindings for one logical action only when ids differ but
    /// actions differ — those are real conflicts worth flagging in debug.
    static func debugAssertNoConflicts() {
        var seen: [String: String] = [:]
        for shortcut in table {
            let combo = "\(shortcut.modifiers.rawValue)-\(shortcut.key)"
            if let existingID = seen[combo], existingID != shortcut.id {
                assertionFailure(
                    "Keyboard shortcut conflict: \(shortcut.displayString) is bound to both '\(existingID)' and '\(shortcut.id)'"
                )
            } else {
                seen[combo] = shortcut.id
            }
        }
    }
}

// MARK: - Event Monitor Routing

enum KeyboardShortcutRouter {

    private static let keyCodeToKey: [UInt16: KeyEquivalent] = [
        123: .leftArrow,
        124: .rightArrow,
        125: .downArrow,
        126: .upArrow,
        48: .tab,
        36: .return,
        53: .escape,
    ]

    /// Matches a key-down event against the event-monitor entries of the
    /// global shortcut table. Returns nil if the event was consumed.
    static func handleKeyEvent(_ event: NSEvent, browserState: BrowserState) -> NSEvent? {
        guard event.type == .keyDown else { return event }

        let key = keyCodeToKey[event.keyCode]
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiers = EventModifiers(flags)

        let match = LotusShortcuts.eventMonitorEntries.first { shortcut in
            shortcut.key == key && shortcut.modifiers == modifiers
        }

        guard let match else { return event }
        if match.guardsTextInput && browserState.isAnyTextInputFocused {
            return event
        }

        DispatchQueue.main.async {
            match.action(browserState)
        }
        // Consume the event even when the action is a no-op (e.g. no history),
        // matching the previous monitor behavior.
        return nil
    }
}

private extension EventModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        var modifiers: EventModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        self = modifiers
    }
}

// MARK: - SwiftUI Rendering

/// Renders every non-event-monitor entry in the shortcut table as an
/// invisible button, following the established invisible-button pattern.
struct GlobalShortcutHandlers: View {
    @ObservedObject var browserState: BrowserState

    var body: some View {
        ForEach(LotusShortcuts.table.filter { !$0.usesEventMonitor }) { shortcut in
            Button("") {
                shortcut.action(browserState)
            }
            .keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .focusable(false)
    }
}
