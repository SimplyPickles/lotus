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
    @ObservedObject private var contentBlocker = ContentBlockerService.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lotus.browser.appearance") private var appearanceMode: String = "system"
    @AppStorage("lotus.browser.chromeTintingMode") private var chromeTintingMode: String = "adaptive"
    @AppStorage("lotus.browser.searchEngine") private var searchEngine: String = "google"
    @AppStorage("lotus.browser.searchSuggestionsEnabled") private var searchSuggestionsEnabled: Bool = true
    @AppStorage("lotus.browser.bangsEnabled") private var bangsEnabled: Bool = true
    @AppStorage("lotus.browser.autoFolderNames") private var autoFolderNames: Bool = true
    @AppStorage("lotus.browser.tidyDownloadsEnabled") private var tidyDownloadsEnabled: Bool = true
    @AppStorage("lotus.browser.showsBrowserFrame") private var showsBrowserFrame: Bool = true
    @AppStorage("lotus.browser.showsRoundedWebCorners") private var showsRoundedWebCorners: Bool = true
    @AppStorage("lotus.browser.showsWebpageShimmer") private var showsWebpageShimmer: Bool = true
    @AppStorage("lotus.browser.topBarVisibility") private var topBarVisibility: String = "always"
    @AppStorage("lotus.browser.startupBehavior") private var startupBehavior: String = "restore"
    @AppStorage("lotus.browser.newTabPosition") private var newTabPosition: String = "below"
    @AppStorage("lotus.browser.autoCloseBlankTabs") private var autoCloseBlankTabs: Bool = false
    @AppStorage("lotus.browser.userAgentMode") private var userAgentMode: String = "safari"
    @AppStorage("lotus.browser.customUserAgentString") private var customUserAgentString: String = ""
    @AppStorage("lotus.browser.autoplayPolicy") private var autoplayPolicy: String = "audio"
    @AppStorage("lotus.browser.autoPiPEnabled") private var autoPiPEnabled: Bool = true
    @AppStorage("lotus.browser.lowPowerModeShimmerDisabled") private var lowPowerModeShimmerDisabled: Bool = false

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

                settingsSection("General & Startup") {
                    SearchEngineSettingsRow(searchEngine: $searchEngine)

                    StartupBehaviorSettingsRow(startupBehavior: $startupBehavior)

                    UserAgentSettingsRow(userAgentMode: $userAgentMode, customUserAgentString: $customUserAgentString)
                }

                settingsSection("Search & Command Palette") {
                    SearchSuggestionsSettingsRow(searchSuggestionsEnabled: $searchSuggestionsEnabled)

                    BangsSettingsRow(bangsEnabled: $bangsEnabled)
                }

                settingsSection("Navigation & Tabs") {
                    NewTabPositionSettingsRow(newTabPosition: $newTabPosition)

                    AutoFolderNamesSettingsRow(autoFolderNames: $autoFolderNames)

                    AutoCloseBlankTabsSettingsRow(autoCloseBlankTabs: $autoCloseBlankTabs)
                }

                settingsSection("Media & Performance") {
                    AutoplayPolicySettingsRow(autoplayPolicy: $autoplayPolicy)

                    AutoPiPSettingsRow(autoPiPEnabled: $autoPiPEnabled)

                    LowPowerPerformanceSettingsRow(lowPowerModeShimmerDisabled: $lowPowerModeShimmerDisabled)
                }

                settingsSection("Appearance") {
                    AppearanceSettingsRow(appearanceMode: $appearanceMode)

                    ChromeTintingSettingsRow(chromeTintingMode: $chromeTintingMode)

                    TopBarSettingsRow(topBarVisibility: $topBarVisibility)

                    BrowserFrameSettingsRow(showsBrowserFrame: $showsBrowserFrame)

                    RoundedWebCornersSettingsRow(showsRoundedWebCorners: $showsRoundedWebCorners)

                    WebpageShimmerSettingsRow(showsWebpageShimmer: $showsWebpageShimmer)
                }

                settingsSection("Shields & Privacy") {
                    ShieldsMasterSettingsRow(contentBlocker: contentBlocker)

                    ShieldsTrackingSettingsRow(contentBlocker: contentBlocker)

                    ShieldsFingerprintSettingsRow(contentBlocker: contentBlocker)

                    ShieldsStrictCanvasBlockSettingsRow(contentBlocker: contentBlocker)

                    ShieldsCosmeticSettingsRow(contentBlocker: contentBlocker)

                    ShieldsStrictHTTPSSettingsRow(contentBlocker: contentBlocker)

                    ShieldsDNTSettingsRow(contentBlocker: contentBlocker)

                    ShieldsAllowlistSettingsRow(contentBlocker: contentBlocker)

                    ShieldsStrictPopupBlockedSettingsRow(contentBlocker: contentBlocker)
                }

                settingsSection("History") {
                    OpenHistorySettingsRow(browserState: browserState, tabId: tabId)
                }

                settingsSection("Downloads") {
                    DownloadLocationSettingsRow(browserState: browserState)

                    TidyDownloadsSettingsRow(tidyDownloadsEnabled: $tidyDownloadsEnabled)

                    OpenDownloadsSettingsRow(browserState: browserState, tabId: tabId)
                }

                settingsSection("About") {
                    SettingsRow(
                        systemImage: "info.circle",
                        title: "Lotus",
                        detail: "Pre-Release 1.0"
                    )

                    ClearDataOnQuitSettingsRow(contentBlocker: contentBlocker)

                    ClearDataSettingsRow(browserState: browserState)
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

private struct AutoFolderNamesSettingsRow: View {
    @Binding var autoFolderNames: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Auto folder names")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Toggle("Auto folder names", isOn: $autoFolderNames)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }
}

private struct ShieldsMasterSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Block ads & trackers")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Automatically blocks ads, analytics, and telemetry")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Block ads & trackers", isOn: $contentBlocker.isAdBlockingEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct ShieldsTrackingSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Block third-party tracking scripts")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Toggle("Block third-party tracking scripts", isOn: $contentBlocker.blockTrackersEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .disabled(!contentBlocker.isAdBlockingEnabled)
        .opacity(contentBlocker.isAdBlockingEnabled ? 1.0 : 0.45)
    }
}

private struct ShieldsCosmeticSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Hide cosmetic ad placeholders")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Toggle("Hide cosmetic ad placeholders", isOn: $contentBlocker.blockCosmeticElementsEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .disabled(!contentBlocker.isAdBlockingEnabled)
        .opacity(contentBlocker.isAdBlockingEnabled ? 1.0 : 0.45)
    }
}

private struct ShieldsFingerprintSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "theatermasks")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Advanced fingerprint protection")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Masks device metrics, Canvas, WebGL, and WebAudio")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Advanced fingerprint protection", isOn: $contentBlocker.fingerprintProtectionEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .disabled(!contentBlocker.isAdBlockingEnabled)
        .opacity(contentBlocker.isAdBlockingEnabled ? 1.0 : 0.45)
    }
}

private struct ShieldsAllowlistSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false
    @State private var newDomainInput: String = ""

    private var allowlist: [String] {
        contentBlocker.allowlistedDomains.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Whitelisted websites")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text(allowlist.isEmpty ? "No sites whitelisted" : "\(allowlist.count) site\(allowlist.count == 1 ? "" : "s") allowed")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)

            if isExpanded {
                VStack(spacing: 8) {
                    Divider()
                        .overlay(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                        .padding(.horizontal, 14)

                    // Add new domain input
                    HStack(spacing: 8) {
                        TextField("Add website domain (e.g. example.com)", text: $newDomainInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                addDomain()
                            }

                        Button("Add") {
                            addDomain()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    // Allowlist items
                    if allowlist.isEmpty {
                        Text("No websites have shields disabled.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(allowlist, id: \.self) { domain in
                                HStack {
                                    Text(domain)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .primary)

                                    Spacer()

                                    Button {
                                        contentBlocker.removeAllowlistDomain(domain)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundColor(Color.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove from whitelist")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
            }
        }
    }

    private func addDomain() {
        let clean = newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        contentBlocker.addAllowlistDomain(clean)
        newDomainInput = ""
    }
}

private struct ShieldsStrictPopupBlockedSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false
    @State private var newDomainInput: String = ""

    private var blockedList: [String] {
        contentBlocker.strictPopupBlockedDomains.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Strict popup & link blocklist")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text(blockedList.isEmpty ? "No sites strictly blocked" : "\(blockedList.count) site\(blockedList.count == 1 ? "" : "s") blocking all popups/links")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)

            if isExpanded {
                VStack(spacing: 8) {
                    Divider()
                        .overlay(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                        .padding(.horizontal, 14)

                    // Add new domain input
                    HStack(spacing: 8) {
                        TextField("Add website domain (e.g. example.com)", text: $newDomainInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                addDomain()
                            }

                        Button("Add") {
                            addDomain()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    // Blocklist items
                    if blockedList.isEmpty {
                        Text("No websites are currently blocking all popups/links.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(blockedList, id: \.self) { domain in
                                HStack {
                                    Text(domain)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .primary)

                                    Spacer()

                                    Button {
                                        contentBlocker.setStrictPopupBlocking(for: domain, enabled: false)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundColor(Color.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove strict popup block")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
            }
        }
    }

    private func addDomain() {
        let clean = newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        contentBlocker.setStrictPopupBlocking(for: clean, enabled: true)
        newDomainInput = ""
    }
}

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
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }
}

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
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
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

private struct StartupBehaviorSettingsRow: View {
    @Binding var startupBehavior: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "power")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("On startup")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Choose how Lotus opens when launched")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("On startup", selection: $startupBehavior) {
                Text("Restore previous session").tag("restore")
                Text("Open command palette").tag("empty")
                Text("Open pinned tabs only").tag("pinnedOnly")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 190, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct UserAgentSettingsRow: View {
    @Binding var userAgentMode: String
    @Binding var customUserAgentString: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false

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

private struct NewTabPositionSettingsRow: View {
    @Binding var newTabPosition: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("New tab placement")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Where new tabs appear in the sidebar strip")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("New tab placement", selection: $newTabPosition) {
                Text("Below active tab").tag("below")
                Text("At the end of strip").tag("end")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 170, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct AutoCloseBlankTabsSettingsRow: View {
    @Binding var autoCloseBlankTabs: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Auto-close blank tabs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Automatically closes unused empty tabs when opening new links")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Auto-close blank tabs", isOn: $autoCloseBlankTabs)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct AutoplayPolicySettingsRow: View {
    @Binding var autoplayPolicy: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.slash")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Autoplay policy")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Control automatic playback of videos and audio")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("Autoplay policy", selection: $autoplayPolicy) {
                Text("Block Audio Media").tag("audio")
                Text("Block All Autoplay").tag("blockAll")
                Text("Allow All").tag("allowAll")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 170, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct AutoPiPSettingsRow: View {
    @Binding var autoPiPEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pip.enter")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Automatic Picture in Picture")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Pops playing videos into floating PiP when switching tabs")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Automatic Picture in Picture", isOn: $autoPiPEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct LowPowerPerformanceSettingsRow: View {
    @Binding var lowPowerModeShimmerDisabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.badge.automatic")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Optimize for battery & low power")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Suppresses animations and page shimmers during Low Power Mode")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Optimize for battery & low power", isOn: $lowPowerModeShimmerDisabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
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

private struct SearchSuggestionsSettingsRow: View {
    @Binding var searchSuggestionsEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Search suggestions")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Show live completions from search engine in command palette")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Search suggestions", isOn: $searchSuggestionsEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct BangsSettingsRow: View {
    @Binding var bangsEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false
    @State private var disabledList: [String] = (UserDefaults.standard.stringArray(forKey: "lotus.browser.disabledBangIDs") ?? [])

    private var allProviders: [SiteSearchProvider] {
        SiteSearchProvider.all
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Site search shortcuts (!bangs)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text("Direct site search using prefixes like !yt, !gh, !w, !r")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer()

                Toggle("Site search shortcuts (!bangs)", isOn: $bangsEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .disabled(!bangsEnabled)
                .opacity(bangsEnabled ? 1.0 : 0.45)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)

            if isExpanded && bangsEnabled {
                VStack(spacing: 8) {
                    Divider()
                        .overlay(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                        .padding(.horizontal, 14)

                    VStack(spacing: 2) {
                        ForEach(allProviders) { provider in
                            let isProviderEnabled = !disabledList.contains(provider.id)
                            HStack(spacing: 10) {
                                Image(systemName: provider.iconName)
                                    .font(.system(size: 12))
                                    .foregroundColor(provider.accentColor)
                                    .frame(width: 18)

                                Text(provider.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .primary)

                                Spacer()

                                Text(provider.triggers.map { "!\($0)" }.joined(separator: ", "))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.40) : .secondary)
                                    .padding(.trailing, 8)

                                Toggle("", isOn: Binding(
                                    get: { isProviderEnabled },
                                    set: { enabled in
                                        if enabled {
                                            disabledList.removeAll(where: { $0 == provider.id })
                                        } else {
                                            if !disabledList.contains(provider.id) {
                                                disabledList.append(provider.id)
                                            }
                                        }
                                        UserDefaults.standard.set(disabledList, forKey: "lotus.browser.disabledBangIDs")
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
    }
}

private struct ShieldsStrictCanvasBlockSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.fill.and.line.vertical.and.square.fill")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Canvas extraction defense mode")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text(contentBlocker.strictCanvasBlockEnabled ? "Strictly blocks HTMLCanvasElement.toDataURL() readout" : "Injects random noise jitter into Canvas extraction (Recommended)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("Canvas extraction defense mode", selection: $contentBlocker.strictCanvasBlockEnabled) {
                Text("Random Noise Jitter").tag(false)
                Text("Strict Complete Block").tag(true)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 180, alignment: .trailing)
            .disabled(!contentBlocker.fingerprintProtectionEnabled || !contentBlocker.isAdBlockingEnabled)
            .opacity((contentBlocker.fingerprintProtectionEnabled && contentBlocker.isAdBlockingEnabled) ? 1.0 : 0.45)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}


