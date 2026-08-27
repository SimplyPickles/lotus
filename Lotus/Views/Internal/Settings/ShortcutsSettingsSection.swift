//
//  ShortcutsSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct ShortcutsSettingsSection: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil

    var body: some View {
        VStack(spacing: 16) {
            SettingsSectionCard(
                title: "Keyboard Shortcuts",
                footer: "Quickly navigate tabs, split panes, and browser tools using customizable hotkeys."
            ) {
                KeyboardShortcutsSettingsRow(browserState: browserState, tabId: tabId)
            }
        }
    }
}

// MARK: - Rows

private struct KeyboardShortcutsSettingsRow: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Keyboard shortcuts")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Customize shortcuts and key bindings")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Button("Customize Shortcuts") {
                if let url = URL(string: "lotus://shortcuts") {
                    browserState.loadURL(url, in: tabId)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(width: 160, height: 28, alignment: .trailing)
            .focusable(false)
            .focusEffectDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }
}
