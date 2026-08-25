//
//  AppearanceSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct AppearanceSettingsSection: View {
    @AppStorage("lotus.browser.accentColor") private var accentColor: String = "white"
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
            AccentColorPickerRow(selectedAccent: $accentColor)
            SettingsDivider()
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

private struct AccentColorPickerRow: View {
    @Binding var selectedAccent: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Accent color")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            HStack(spacing: 10) {
                ForEach(LotusAccentColor.allCases) { accent in
                    AccentColorDot(
                        accent: accent,
                        isSelected: selectedAccent == accent.rawValue,
                        action: {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                selectedAccent = accent.rawValue
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }
}

private struct AccentColorDot: View {
    let accent: LotusAccentColor
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Circle()
                        .strokeBorder(
                            colorScheme == .dark ? Color.white : Color(nsColor: .labelColor),
                            lineWidth: 1.5
                        )
                        .frame(width: 26, height: 26)
                        .transition(.scale.combined(with: .opacity))
                }

                Circle()
                    .fill(accent.swatchColor)
                    .frame(width: 19, height: 19)
                    .overlay(
                        Group {
                            if accent == .white && colorScheme == .light {
                                Circle()
                                    .strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
                            }
                        }
                    )
            }
            .frame(width: 28, height: 28)
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(accent.displayName)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

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
            .untintedDropdown()
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
                Text("Accent").tag("systemAccent")
            }
            .labelsHidden()
            .untintedDropdown()
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
                Text("Center address bar preview")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Centers text in inactive URL address bar")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Center address bar preview", isOn: $centerURLPreview)
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
            Image(systemName: "command")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Center Command Palette")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Centers the palette in the window instead of top-aligning")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Center Command Palette", isOn: $centerCommandPaletteOverWebview)
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
            Image(systemName: "menubar.rectangle")
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
            .untintedDropdown()
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
