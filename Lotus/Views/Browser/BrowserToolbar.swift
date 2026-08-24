//
//  BrowserToolbar.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

struct BrowserToolbar: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow

    @State private var urlInputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isInputHovered: Bool = false

    @State private var backOffset: CGFloat = 0
    @State private var forwardOffset: CGFloat = 0
    /// True for the remainder of the runloop tick in which the selected tab changed.
    /// Focus gains arriving during that window are spurious SwiftUI field-editor
    /// restorations from the view diff, not user clicks, so they get dropped.
    @State private var isSwitchingTabs: Bool = false
    @Binding var isDownloadsPopoverPresented: Bool
    @State private var isCatchingDownload: Bool = false
    @State private var showDownloadSuccessRing: Bool = false
    @State private var downloadRingScale: CGFloat = 0.85
    @State private var downloadRingOpacity: Double = 0.0
    @State private var isZoomIndicatorVisible: Bool = false
    @State private var isBloomActive: Bool = false
    @State private var bloomScale: CGFloat = 0.6
    @State private var bloomOpacity: Double = 0.0

    private var activeTabId: UUID {
        tabId ?? browserState.selectedTabId
    }

    private var isLoading: Bool {
        browserState.isLoading(for: activeTabId)
    }

    private var theme: BrowserChromeTheme {
        BrowserChromeTheme(browserState: browserState, tabId: activeTabId, colorScheme: colorScheme)
    }

    private var currentURL: URL? {
        browserState.url(for: activeTabId)
    }

    private var currentTab: TabItem? {
        browserState.tab(for: activeTabId)
    }

    private var canGoBack: Bool {
        browserState.canGoBack(for: activeTabId)
    }

    private var canGoForward: Bool {
        browserState.canGoForward(for: activeTabId)
    }

    private var isLeftmostContainer: Bool {
        guard let firstId = browserState.currentTabIds.first else { return true }
        return activeTabId == firstId
    }

    private var currentZoomLevel: CGFloat {
        browserState.zoomLevel(for: activeTabId)
    }

    private var clampedDownloadProgress: CGFloat {
        CGFloat(max(0.08, min(1.0, browserState.overallDownloadProgress)))
    }

    private var hairlineAccentColor: Color {
        let url = browserState.url(for: activeTabId)
        if let host = url?.host?.lowercased(), host.contains("apple.com") {
            return colorScheme == .dark ? Color.white : Color.black
        }
        if let faviconURL = browserState.tab(for: activeTabId)?.faviconURL,
           let extracted = FaviconColorExtractor.shared.color(for: faviconURL) {
            return extracted
        }
        if let theme = browserState.themeColor(for: activeTabId) {
            return theme
        }
        return Color(nsColor: .controlAccentColor)
    }

    var body: some View {
        HStack(spacing: 8) {
            if isLeftmostContainer {
                Button {
                    browserState.toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13, weight: .regular))
                }
                .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
                .focusable(false)
                .padding(.leading, -1)
            }

            Button {
                backOffset = -2.5
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    backOffset = 0
                }
                browserState.goBack(for: activeTabId)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .offset(x: backOffset)
                    .animation(.spring(response: 0.28, dampingFraction: 0.62), value: backOffset)
            }
            .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
            .disabled(!canGoBack)
            .opacity(canGoBack ? 1.0 : 0.35)
            .animation(.easeInOut(duration: 0.2), value: canGoBack)
            .focusable(false)

            Button {
                forwardOffset = 2.5
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    forwardOffset = 0
                }
                browserState.goForward(for: activeTabId)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .offset(x: forwardOffset)
                    .animation(.spring(response: 0.28, dampingFraction: 0.62), value: forwardOffset)
            }
            .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1.0 : 0.35)
            .animation(.easeInOut(duration: 0.2), value: canGoForward)
            .focusable(false)

            Button {
                if isLoading {
                    browserState.stopLoading(for: activeTabId)
                } else {
                    browserState.reload(for: activeTabId)
                }
            } label: {
                ZStack {
                    if isLoading {
                        Image(systemName: "xmark")
                            .font(.system(size: 10.5, weight: .semibold))
                            .frame(width: 14, height: 14, alignment: .center)
                            .transition(.reloadTransition)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11.5, weight: .regular))
                            .frame(width: 14, height: 14, alignment: .center)
                            .transition(.reloadTransition)
                    }
                }
                .animation(.spring(response: 0.30, dampingFraction: 0.76), value: isLoading)
            }
            .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
            .disabled(currentURL?.isLotusPage == true)
            .opacity(currentURL?.isLotusPage == true ? 0.35 : 1.0)
            .focusable(false)

            ZStack(alignment: .trailing) {
                ZStack(alignment: .leading) {
                    if !isEditingOrHovering, let host = prettifiedHost {
                        HStack(spacing: 4) {
                            Text(host)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(theme.foregroundPrimary)

                            if let detail = prettifiedDetail {
                                Text("/")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(theme.foregroundSecondary.opacity(0.3))

                                Text(detail)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(theme.foregroundSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .padding(.trailing, currentZoomLevel != 1.0 ? 54 : 0)
                        .opacity(urlCopyFeedback != nil ? 0 : 1)
                        .allowsHitTesting(false)
                    }

                    TextField(
                        "",
                        text: $urlInputText,
                        prompt: Text("Search the web or type a URL").foregroundColor(theme.foregroundSecondary)
                    )
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(theme.foregroundPrimary)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .focused($isInputFocused)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .padding(.trailing, currentZoomLevel != 1.0 ? 54 : 0)
                    .opacity((!isEditingOrHovering && prettifiedHost != nil) || urlCopyFeedback != nil ? 0 : 1)
                    .allowsHitTesting(false)
                    .onKeyPress(.escape) {
                        syncInputText()
                        isInputFocused = false
                        return .handled
                    }

                    if let feedback = urlCopyFeedback {
                        URLCopyFeedbackToast(feedback: feedback, theme: theme, accentColor: hairlineAccentColor)
                            .id(feedback.id)
                            .transition(
                                .asymmetric(
                                    insertion: .offset(y: 12).combined(with: .opacity),
                                    removal: .offset(y: -12).combined(with: .opacity)
                                )
                            )
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    browserState.openCommandPaletteForCurrentTab()
                }

                // Keep the pill mounted through the reset so numericText can
                // animate the final value to 100% before it fades out.
                if isZoomIndicatorVisible || currentZoomLevel != 1.0 {
                    ZoomIndicatorPill(
                        zoomLevel: currentZoomLevel,
                        isZoomingIn: browserState.lastZoomChangeDirection[activeTabId] ?? true,
                        theme: theme,
                        onReset: {
                            isZoomIndicatorVisible = true
                            browserState.resetZoom(for: activeTabId)
                        }
                    )
                    .padding(.trailing, 4)
                    .transition(
                        .opacity.animation(.easeInOut(duration: 0.30))
                            .combined(with: .scale(scale: 0.90).animation(.easeInOut(duration: 0.30)))
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .background(
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.inputBackground(isFocused: isInputFocused, isHovered: isInputHovered))
                        .animation(.easeInOut(duration: 0.15), value: isInputHovered)
                        .animation(.easeInOut(duration: 0.15), value: isInputFocused)

                    // Delicate radial tint bloom matching the site's theme color, radiating from the left
                    if isBloomActive {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        hairlineAccentColor.opacity(0.42),
                                        hairlineAccentColor.opacity(0.18),
                                        Color.clear
                                    ]),
                                    center: .leading,
                                    startRadius: 0,
                                    endRadius: 280
                                )
                            )
                            .scaleEffect(x: bloomScale, y: 1.0, anchor: .leading)
                            .opacity(bloomOpacity)
                    }

                    HairlineProgressIndicator(browserState: browserState, tabId: activeTabId)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: currentZoomLevel)
            .onHover { hovering in
                isInputHovered = hovering
            }
            .onSubmit {
                submit(with: urlInputText)
            }
            .onExitCommand {
                syncInputText()
                isInputFocused = false
            }

            Button {
                isDownloadsPopoverPresented.toggle()
            } label: {
                ZStack {
                    if browserState.hasActiveDownloads {
                        let activeColor = theme.themeColor != nil ? (theme.isThemeLight ? Color.black : Color.white) : hairlineAccentColor
                        ZStack {
                            Circle()
                                .stroke(activeColor.opacity(0.25), lineWidth: 2.0)
                                .frame(width: 15, height: 15)

                            Circle()
                                .trim(from: 0.0, to: clampedDownloadProgress)
                                .stroke(
                                    activeColor,
                                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 15, height: 15)
                                .animation(.linear(duration: 0.12), value: browserState.overallDownloadProgress)

                            Image(systemName: "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(activeColor)
                        }
                        .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 13, weight: .regular))
                    }
                }
                .scaleEffect(isCatchingDownload ? 1.18 : 1.0)
                .animation(.spring(response: 0.18, dampingFraction: 0.44), value: isCatchingDownload)
                .overlay(
                    Group {
                        if showDownloadSuccessRing {
                            Circle()
                                .stroke(hairlineAccentColor.opacity(0.90), lineWidth: 1.5)
                                .scaleEffect(downloadRingScale)
                                .opacity(downloadRingOpacity)
                        }
                    }
                )
            }
            .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
            .focusable(false)
            .help("Downloads")
            .onChange(of: browserState.downloadCatchPulseTrigger) { _, _ in
                // 1. Double heartbeat spring bounce: 1.0 -> 1.18 -> 1.0
                showDownloadSuccessRing = true
                downloadRingScale = 0.80
                downloadRingOpacity = 0.90

                withAnimation(.spring(response: 0.16, dampingFraction: 0.40)) {
                    isCatchingDownload = true
                }
                withAnimation(.easeOut(duration: 0.55)) {
                    downloadRingScale = 1.85
                    downloadRingOpacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.58)) {
                        isCatchingDownload = false
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
                    showDownloadSuccessRing = false
                }
            }
            .popover(isPresented: $isDownloadsPopoverPresented, arrowEdge: .bottom) {
                RecentDownloadsPopover(browserState: browserState) {
                    isDownloadsPopoverPresented = false
                }
            }

            ShieldButton(browserState: browserState, tabId: activeTabId, theme: theme)

            Menu {
                Button {
                    browserState.openCommandPalette()
                } label: {
                    Label("New Tab", systemImage: "plus")
                }

                Button {
                    openWindow(id: "main")
                } label: {
                    Label("New Window", systemImage: "macwindow.badge.plus")
                }

                Divider()

                Button {
                    browserState.addTabBelow(title: "Downloads", url: .lotusDownloads)
                } label: {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }

                Button {
                    browserState.addTabBelow(title: "History", url: .lotusHistory)
                } label: {
                    Label("History", systemImage: "clock")
                }

                Button {
                    browserState.addTabBelow(title: "Settings", url: .lotusSettings)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }

                Button {
                    browserState.reopenLastClosedTab()
                } label: {
                    Label("Reopen Closed Tab", systemImage: "arrow.uturn.left")
                }

                Divider()

                Button {
                    browserState.copyPageURL(for: activeTabId)
                } label: {
                    Label("Copy Address", systemImage: "link")
                }
                .disabled(currentURL == nil || currentURL?.isLotusPage == true)

                Button {
                    browserState.toggleShield(for: activeTabId)
                } label: {
                    Label(
                        browserState.isShieldActive(for: activeTabId) ? "Pause Shields on this Site" : "Resume Shields on this Site",
                        systemImage: browserState.isShieldActive(for: activeTabId) ? "shield.slash" : "shield.checkered"
                    )
                }
                .disabled(currentURL?.isLotusPage != false)

                Button {
                    browserState.printPage(for: activeTabId)
                } label: {
                    Label("Print", systemImage: "printer")
                }
                .disabled(currentURL?.isLotusPage != false)

                Button {
                    browserState.togglePictureInPicture(for: activeTabId)
                } label: {
                    Label("Picture in Picture", systemImage: "pip")
                }
                .disabled(currentURL?.isLotusPage != false)

                Button {
                    browserState.openFind(for: activeTabId)
                } label: {
                    Label("Find in Page", systemImage: "magnifyingglass")
                }
                .disabled(currentURL?.isLotusPage != false)

                Button {
                    browserState.toggleSidebar()
                } label: {
                    Label(
                        browserState.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar",
                        systemImage: "sidebar.left"
                    )
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .regular))
            }
            .menuStyle(.button)
            .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
            .menuIndicator(.hidden)
            .fixedSize()
            .focusable(false)
            .padding(.trailing, -8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(theme.backgroundColor)
        .onAppear {
            syncInputText()
            isInputFocused = false
        }
        .onChange(of: activeTabId) {
            handleTabSwitch()
        }
        .onChange(of: browserState.url(for: activeTabId)) {
            syncInputText()
        }
        .onChange(of: currentZoomLevel) { _, newZoomLevel in
            if newZoomLevel != 1.0 {
                isZoomIndicatorVisible = true
            } else if isZoomIndicatorVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    if currentZoomLevel == 1.0 {
                        withAnimation(.easeInOut(duration: 0.30)) {
                            isZoomIndicatorVisible = false
                        }
                    }
                }
            }
        }
        .onChange(of: isInputFocused) { _, isFocused in
            if isFocused {
                if isSwitchingTabs {
                    // Spurious re-focus while the tab switch is still settling.
                    isInputFocused = false
                    return
                }
                syncInputText()
                DispatchQueue.main.async {
                    // Re-verify before selecting: focus may already have been
                    // lost again during this runloop tick.
                    guard isInputFocused, !isSwitchingTabs else { return }
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
            } else {
                syncInputText()
            }
        }
        .onChange(of: browserState.focusAddressBarTabId) { _, targetId in
            if targetId == activeTabId {
                isInputFocused = true
                DispatchQueue.main.async {
                    isInputFocused = true
                    if browserState.focusAddressBarTabId == activeTabId {
                        browserState.focusAddressBarTabId = nil
                    }
                }
            }
        }
        .onChange(of: urlCopyFeedback) { _, feedback in
            if feedback?.outcome == .copied {
                triggerRadialBloom()
            }
        }
        .onChange(of: browserState.themeBloomTrigger[activeTabId]) { _, _ in
            triggerRadialBloom()
        }
    }

    private func triggerRadialBloom() {
        bloomScale = 0.6
        bloomOpacity = 0.85
        isBloomActive = true
        withAnimation(.easeOut(duration: 0.68)) {
            bloomScale = 1.65
            bloomOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            isBloomActive = false
        }
    }

    private var isEditingOrHovering: Bool {
        isInputFocused || isInputHovered
    }

    private var urlCopyFeedback: URLCopyFeedback? {
        guard let feedback = browserState.urlCopyFeedback, feedback.tabId == activeTabId else { return nil }
        return feedback
    }

    private var prettifiedHost: String? {
        guard let url = currentURL else { return nil }
        if let lotusTitle = url.lotusPageTitle {
            return lotusTitle
        }
        guard let host = url.host, !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var prettifiedDetail: String? {
        guard let url = currentURL, !url.isLotusPage else { return nil }
        if let title = currentTab?.title, !title.isEmpty, title != prettifiedHost, title != url.absoluteString {
            return title
        }
        if !url.path.isEmpty && url.path != "/" {
            return url.path
        }
        return nil
    }

    /// Ends address-bar editing synchronously and arms the spurious-focus guard
    /// for the rest of the current runloop tick.
    ///
    /// Deferring the resign to SwiftUI's own update cycle left a stale field
    /// editor installed on the URL field across tab switches, which both made
    /// the bar look selected and caused WebTabHostNSView's deferred
    /// first-responder pass to bail out. Ending the edit here is deterministic.
    private func handleTabSwitch() {
        isSwitchingTabs = true
        if isInputFocused {
            NSApp.keyWindow?.makeFirstResponder(nil)
            isInputFocused = false
        }
        syncInputText()
        DispatchQueue.main.async {
            isSwitchingTabs = false
        }
    }

    private func syncInputText() {
        if let url = currentURL, url.isLotusPage {
            // Show the URL for internal pages (e.g. lotus://history).
            urlInputText = url.absoluteString
        } else if let abs = currentURL?.absoluteString, !abs.isEmpty {
            urlInputText = abs
        } else {
            urlInputText = currentTab?.title ?? ""
        }
    }

    private func submit(with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isInputFocused = false
        browserState.navigateTab(id: activeTabId, to: trimmed)
    }
}

private struct URLCopyFeedbackToast: View {
    let feedback: URLCopyFeedback
    let theme: BrowserChromeTheme
    let accentColor: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: feedback.systemImage)
                .font(.system(size: 12, weight: .semibold))

            Text(feedback.message)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundColor(feedback.outcome == .copied ? accentColor : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

// MARK: - Reload / Stop Icon Transition

private struct SpinAndScaleTransitionModifier: ViewModifier {
    let rotation: Double
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    static var reloadTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: SpinAndScaleTransitionModifier(rotation: -90, scale: 0.6, opacity: 0),
                identity: SpinAndScaleTransitionModifier(rotation: 0, scale: 1.0, opacity: 1)
            ),
            removal: .modifier(
                active: SpinAndScaleTransitionModifier(rotation: 90, scale: 0.6, opacity: 0),
                identity: SpinAndScaleTransitionModifier(rotation: 0, scale: 1.0, opacity: 1)
            )
        )
    }
}

// MARK: - Zoom Indicator Pill

private struct ZoomIndicatorPill: View {
    let zoomLevel: CGFloat
    let isZoomingIn: Bool
    let theme: BrowserChromeTheme
    let onReset: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var percentValue: Int {
        Int(round(zoomLevel * 100))
    }

    private var percentText: String {
        "\(percentValue)%"
    }

    var body: some View {
        Button(action: onReset) {
            HStack(spacing: 2) {
                Text("\(percentValue)")
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: !isZoomingIn))
                    // Keep the rolling digits in a stable vertical lane. Without
                    // this, the transition's intermediate glyphs can move the
                    // pill's baseline up and down as their bounds change.
                    .frame(height: 13, alignment: .center)
                    .clipped()

                Text("%")
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.74), value: percentValue)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(theme.foregroundPrimary.opacity(isHovered ? 1.0 : 0.72))
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isHovered
                          ? (colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08))
                          : (colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04)))
            )
            .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Zoom level \(percentText). Click to reset to 100%.")
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
