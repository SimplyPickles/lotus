//
//  DownloadsSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct DownloadsSettingsSection: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    @AppStorage("lotus.browser.tidyDownloadsEnabled") private var tidyDownloadsEnabled: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            SettingsSectionCard(
                title: "Download Location & Tidy",
                footer: "Tidy downloads automatically sanitizes messy hashes, timestamps, and tracking tags from downloaded file names."
            ) {
                DownloadLocationSettingsRow(browserState: browserState)
                SettingsDivider()
                TidyDownloadsSettingsRow(tidyDownloadsEnabled: $tidyDownloadsEnabled)
                SettingsDivider()
                OpenDownloadsSettingsRow(browserState: browserState, tabId: tabId)
            }
        }
    }
}

// MARK: - Rows

private struct OpenDownloadsSettingsRow: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID?
    @Environment(\.colorScheme) private var colorScheme

    private var downloadCount: Int {
        browserState.downloads.count
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Download history")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text(downloadCount == 0 ? "No download records" : "\(downloadCount) file\(downloadCount == 1 ? "" : "s") downloaded")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Button("Open Downloads") {
                if let url = URL(string: "lotus://downloads") {
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

private struct DownloadLocationSettingsRow: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Download location")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text(browserState.downloadDirectory.lastPathComponent)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Change…") {
                browserState.chooseDownloadLocation()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(width: 150, height: 28, alignment: .trailing)
            .focusable(false)
            .focusEffectDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct TidyDownloadsSettingsRow: View {
    @Binding var tidyDownloadsEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Tidy downloads")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Automatically cleans up messy filenames, UUIDs, and URL hashes")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Tidy downloads", isOn: $tidyDownloadsEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}
