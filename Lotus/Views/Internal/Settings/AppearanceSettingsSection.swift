//
//  AppearanceSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct AppearanceSettingsSection: View {
    @AppStorage("lotus.browser.appearance") private var appearanceMode: String = "system"
    @AppStorage("lotus.browser.chromeTintingMode") private var chromeTintingMode: String = "adaptive"
    @AppStorage("lotus.browser.centerURLPreview") private var centerURLPreview: Bool = false
    @AppStorage("lotus.browser.centerCommandPaletteOverWebview") private var centerCommandPaletteOverWebview: Bool = false
    @AppStorage("lotus.browser.topBarVisibility") private var topBarVisibility: String = "always"
    @AppStorage("lotus.browser.showsBrowserFrame") private var showsBrowserFrame: Bool = true
    @AppStorage("lotus.browser.showsRoundedWebCorners") private var showsRoundedWebCorners: Bool = true
    @AppStorage("lotus.browser.showsWebpageShimmer") private var showsWebpageShimmer: Bool = true

    var body: some View {
        SettingsSectionCard(title: SettingsCategory.appearance.rawValue, systemImage: SettingsCategory.appearance.systemImage) {
            AppearanceSettingsRow(appearanceMode: $appearanceMode)
            SettingsDivider()
            ChromeTintingSettingsRow(chromeTintingMode: $chromeTintingMode)
            SettingsDivider()
            CenterURLPreviewSettingsRow(centerURLPreview: $centerURLPreview)
            SettingsDivider()
            CenterCommandPaletteSettingsRow(centerCommandPaletteOverWebview: $centerCommandPaletteOverWebview)
            SettingsDivider()
            TopBarSettingsRow(topBarVisibility: $topBarVisibility)
            SettingsDivider()
            BrowserFrameSettingsRow(showsBrowserFrame: $showsBrowserFrame)
            SettingsDivider()
            RoundedWebCornersSettingsRow(showsRoundedWebCorners: $showsRoundedWebCorners)
            SettingsDivider()
            WebpageShimmerSettingsRow(showsWebpageShimmer: $showsWebpageShimmer)
        }
    }
}

// MARK: - Rows

private struct AppearanceSettingsRow: View {
    @Binding var appearanceMode: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Theme")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Picker("Theme", selection: $appearanceMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct ChromeTintingSettingsRow: View {
    @Binding var chromeTintingMode: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintpalette")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Dynamic site chrome tinting")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Tints sidebar and toolbar with current site's dominant accent")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("Dynamic site chrome tinting", selection: $chromeTintingMode) {
                Text("Adaptive").tag("adaptive")
                Text("Neutral").tag("neutral")
                Text("System").tag("systemAccent")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 140, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct CenterURLPreviewSettingsRow: View {
    @Binding var centerURLPreview: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.aligncenter")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Center URL preview")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Centers the domain preview and lock icon in the address bar when not hovering")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Center URL preview", isOn: $centerURLPreview)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct CenterCommandPaletteSettingsRow: View {
    @Binding var centerCommandPaletteOverWebview: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Center command palette over webview")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Aligns the command palette to the web content area instead of the full window when sidebar is open")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Center command palette over webview", isOn: $centerCommandPaletteOverWebview)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct TopBarSettingsRow: View {
    @Binding var topBarVisibility: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Top bar")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Picker("Top bar", selection: $topBarVisibility) {
                Text("Always").tag("always")
                Text("Hover").tag("hover")
                Text("Never").tag("never")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct BrowserFrameSettingsRow: View {
    @Binding var showsBrowserFrame: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.inset.filled")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Browser frame")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Toggle("Browser frame", isOn: $showsBrowserFrame)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct RoundedWebCornersSettingsRow: View {
    @Binding var showsRoundedWebCorners: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Rounded web corners")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Toggle("Rounded web corners", isOn: $showsRoundedWebCorners)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct WebpageShimmerSettingsRow: View {
    @Binding var showsWebpageShimmer: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Webpage shimmer")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Toggle("Webpage shimmer", isOn: $showsWebpageShimmer)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}
