//
//  LotusSettingsView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct LotusSettingsView: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lotus.browser.appearance") private var appearanceMode: String = "system"
    @AppStorage("lotus.browser.searchEngine") private var searchEngine: String = "google"
    @AppStorage("lotus.browser.showsBrowserFrame") private var showsBrowserFrame: Bool = true
    @AppStorage("lotus.browser.showsRoundedWebCorners") private var showsRoundedWebCorners: Bool = true
    @AppStorage("lotus.browser.topBarVisibility") private var topBarVisibility: String = "always"

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 28) {
                header

                settingsSection("General") {
                    SearchEngineSettingsRow(searchEngine: $searchEngine)
                    
                    DownloadLocationSettingsRow(browserState: browserState)
                }

                settingsSection("Appearance") {
                    AppearanceSettingsRow(appearanceMode: $appearanceMode)

                    TopBarSettingsRow(topBarVisibility: $topBarVisibility)

                    BrowserFrameSettingsRow(showsBrowserFrame: $showsBrowserFrame)

                    RoundedWebCornersSettingsRow(showsRoundedWebCorners: $showsRoundedWebCorners)
                }

                settingsSection("About") {
                    SettingsRow(
                        systemImage: "info.circle",
                        title: "Lotus",
                        detail: "Pre-Release 1.0"
                    )
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 40)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .background(Color.clear)
        .transaction { $0.animation = nil }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "gearshape")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [.white, .white.opacity(0.5)]
                            : [Color(nsColor: .labelColor), Color(nsColor: .labelColor).opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("Settings")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(foregroundPrimary)

                Text("Customize Lotus")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(foregroundSecondary)
            }
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(foregroundSecondary)
                .padding(.leading, 14)

            VStack(spacing: 0, content: content)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(cardStroke, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsRow: View {
    let systemImage: String
    let title: String
    let detail: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Text(detail)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
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
            .pickerStyle(.menu)
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct SearchEngineSettingsRow: View {
    @Binding var searchEngine: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Search engine")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Picker("Search engine", selection: $searchEngine) {
                ForEach(URLInputResolver.SearchEngine.allCases, id: \.rawValue) { engine in
                    Text(engine.displayName).tag(engine.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct DownloadLocationSettingsRow: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
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
