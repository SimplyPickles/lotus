//
//  CustomShortcut.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI
import AppKit

/// Represents user-configured keyboard shortcuts stored persistently.
struct CustomShortcutData: Codable, Equatable, Hashable {
    var keyChar: String
    var isSpecialKey: String? // "leftArrow", "rightArrow", "upArrow", "downArrow", "tab", "delete", "return"
    var command: Bool
    var shift: Bool
    var option: Bool
    var control: Bool

    var displayString: String {
        var parts: [String] = []
        if command { parts.append("⌘") }
        if shift { parts.append("⇧") }
        if option { parts.append("⌥") }
        if control { parts.append("^") }
        if let special = isSpecialKey {
            switch special {
            case "leftArrow": parts.append("←")
            case "rightArrow": parts.append("→")
            case "upArrow": parts.append("↑")
            case "downArrow": parts.append("↓")
            case "tab": parts.append("⇥")
            case "return": parts.append("↩")
            case "delete": parts.append("⌫")
            default: parts.append(special)
            }
        } else {
            parts.append(keyChar.uppercased())
        }
        return parts.joined()
    }

    var eventModifiers: EventModifiers {
        var mods: EventModifiers = []
        if command { mods.insert(.command) }
        if shift { mods.insert(.shift) }
        if option { mods.insert(.option) }
        if control { mods.insert(.control) }
        return mods
    }

    var keyEquivalent: KeyEquivalent {
        if let special = isSpecialKey {
            switch special {
            case "leftArrow": return .leftArrow
            case "rightArrow": return .rightArrow
            case "upArrow": return .upArrow
            case "downArrow": return .downArrow
            case "tab": return .tab
            case "return": return .return
            case "delete": return .delete
            default: break
            }
        }
        guard let first = keyChar.lowercased().first else { return KeyEquivalent("a") }
        return KeyEquivalent(first)
    }
}
