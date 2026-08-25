//
//  AboutSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct AboutSettingsSection: View {
    @ObservedObject var browserState: BrowserState
    @AppStorage("lotus.browser.userAgentMode") private var userAgentMode: String = "safari"
    @AppStorage("lotus.browser.customUserAgentString") private var customUserAgentString: String = ""

    var body: some View {
        SettingsSectionCard(title: SettingsCategory.about.rawValue, systemImage: SettingsCategory.about.systemImage) {
            SettingsRow(
                systemImage: "info.circle",
                title: "Lotus Browser",
                detail: "Version 1.0 (macOS)"
            )
            SettingsDivider()
            UserAgentSettingsRow(userAgentMode: $userAgentMode, customUserAgentString: $customUserAgentString)
            SettingsDivider()
            ClearDataSettingsRow(browserState: browserState)
        }
    }
}

// MARK: - Rows

private struct UserAgentSettingsRow: View {
    @Binding var userAgentMode: String
    @Binding var customUserAgentString: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "network")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("User Agent")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text("Browser identity identifier sent to web servers")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer()

                Picker("User Agent", selection: $userAgentMode) {
                    Text("Safari / WebKit (Default)").tag("safari")
                    Text("Google Chrome").tag("chrome")
                    Text("Custom").tag("custom")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 190, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)

            if userAgentMode == "custom" {
                Divider()
                    .overlay(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                    .padding(.horizontal, 14)

                HStack(spacing: 8) {
                    TextField("Enter custom User-Agent string…", text: $customUserAgentString)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }
}

private struct ClearDataSettingsRow: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? Color.red.opacity(0.85) : Color.red)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Clear all data")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Caches, history, download history, logins, cookies, and website data")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Button(role: .destructive) {
                withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
                    browserState.isClearAllDataConfirmationPresented = true
                }
            } label: {
                Text("Clear All Data…")
                    .foregroundColor(Color.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(width: 150, height: 28, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}
