//
//  PrivacySettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct PrivacySettingsSection: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    @ObservedObject var contentBlocker: ContentBlockerService

    var body: some View {
        VStack(spacing: 16) {
            SettingsSectionCard(title: "Browsing History & Site Data") {
                OpenHistorySettingsRow(browserState: browserState, tabId: tabId)
                SettingsDivider()
                ManageWebsiteDataSettingsRow(browserState: browserState, tabId: tabId)
            }

            SettingsSectionCard(
                title: "Privacy & Security Options",
                footer: "Lotus automatically upgrades HTTP connections to HTTPS and strips tracking telemetry from copied URLs."
            ) {
                ShieldsStrictHTTPSSettingsRow(contentBlocker: contentBlocker)
                SettingsDivider()
                ShieldsDNTSettingsRow(contentBlocker: contentBlocker)
                SettingsDivider()
                ShieldsCopyCleanURLSettingsRow(contentBlocker: contentBlocker)
                SettingsDivider()
                ClearDataOnQuitSettingsRow(contentBlocker: contentBlocker)
            }
        }
    }
}

// MARK: - Rows

private struct OpenHistorySettingsRow: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID?
    @Environment(\.colorScheme) private var colorScheme

    private var historyCount: Int {
        browserState.historyEntries.count
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Browsing history")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text(historyCount == 0 ? "No visited pages recorded" : "\(historyCount) visited page\(historyCount == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Button("Open History") {
                if let url = URL(string: "lotus://history") {
                    browserState.loadURL(url, in: tabId)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(width: 150, height: 28, alignment: .trailing)
            .focusable(false)
            .focusEffectDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }
}

private struct ManageWebsiteDataSettingsRow: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Website data & cookies")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Inspect and delete cookies, caches, and local storage per site")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Button("Open Website Data") {
                if let url = URL(string: "lotus://data") {
                    browserState.loadURL(url, in: tabId)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(width: 150, height: 28, alignment: .trailing)
            .focusable(false)
            .focusEffectDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct ShieldsStrictHTTPSSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Strict HTTPS (HTTPS-Only Mode)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Automatically upgrades insecure http:// connections to https://")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Strict HTTPS", isOn: $contentBlocker.httpsOnlyModeEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct ShieldsDNTSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Send “Do Not Track” & Global Privacy Control (GPC)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Sends DNT: 1 and Sec-GPC: 1 headers with outgoing web requests")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Do Not Track & GPC", isOn: $contentBlocker.dntEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct ShieldsCopyCleanURLSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Copy clean URLs (strip tracking parameters)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Automatically removes UTM, Facebook, Google, and tracking tags when copying links (⇧⌘C)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Copy clean URLs", isOn: $contentBlocker.copyCleanURLAutomatically)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct ClearDataOnQuitSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Clear data on quit")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Wipes cookies, caches, history, and downloads when Lotus closes")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Clear data on quit", isOn: $contentBlocker.clearDataOnQuit)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}
