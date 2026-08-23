//
//  BrowserContainer.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import WebKit

struct BrowserContainer: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lotus.browser.showsRoundedWebCorners") private var showsRoundedWebCorners: Bool = true
    @AppStorage("lotus.browser.topBarVisibility") private var topBarVisibility: String = "always"
    @AppStorage("lotus.browser.showsTopBar") private var legacyShowsTopBar: Bool = true
    @State private var isThemeBloomActive: Bool = false
    @State private var isPointerInside: Bool = false
    @State private var isDownloadsPopoverPresented: Bool = false

    private var activeTabId: UUID {
        tabId ?? browserState.selectedTabId
    }

    private var theme: BrowserChromeTheme {
        BrowserChromeTheme(browserState: browserState, tabId: activeTabId, colorScheme: colorScheme)
    }

    private var isInternalLotusPage: Bool {
        browserState.url(for: activeTabId)?.isLotusPage == true
    }

    private var containerBackground: Color {
        theme.backgroundColor.opacity(
            isInternalLotusPage
                ? (colorScheme == .dark ? 0.76 : 0.82)
                : (colorScheme == .dark ? 0.86 : 0.90)
        )
    }

    private var isFocusedContainer: Bool {
        browserState.selectedTabId == activeTabId
    }

    private var isInSplitView: Bool {
        browserState.currentTabIds.count >= 2
    }

    private var containerStrokeColor: Color {
        if isInSplitView {
            if isFocusedContainer {
                return colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.22)
            } else {
                return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
            }
        }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var containerStrokeWidth: CGFloat {
        if isInSplitView && isFocusedContainer {
            return 1.5
        }
        return 1.0
    }

    private var containerCornerRadius: CGFloat {
        showsRoundedWebCorners ? 10 : 0
    }

    private var showsTopBar: Bool {
        switch topBarVisibility {
        case "never":
            return false
        case "hover":
            return isPointerInside || isDownloadsPopoverPresented
        default:
            return true
        }
    }

    private func updateTopBarHover(at location: CGPoint) {
        guard topBarVisibility == "hover" else { return }
        isPointerInside = location.y <= 46
    }

    private func migrateTopBarVisibilityIfNeeded() {
        guard UserDefaults.standard.object(forKey: "lotus.browser.topBarVisibility") == nil else { return }
        topBarVisibility = legacyShowsTopBar ? "always" : "never"
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            BrowserToolbar(
                browserState: browserState,
                tabId: activeTabId,
                isDownloadsPopoverPresented: $isDownloadsPopoverPresented
            )
                .zIndex(10)

            Divider()
                .overlay(theme.foregroundPrimary.opacity(0.075))
                .padding(.vertical, -1)
                .zIndex(10)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if topBarVisibility == "always" {
                topBar
            }

            ZStack(alignment: .topTrailing) {
                ZStack {
                    WebTabContainerView(browserState: browserState, tabId: activeTabId)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .padding(.trailing, -1)
                        .background(theme.backgroundColor)
                        .opacity(isInternalLotusPage ? 0 : 1)
                        .allowsHitTesting(!isInternalLotusPage)

                    if isInternalLotusPage {
                        if browserState.url(for: activeTabId)?.host == "history" {
                            LotusHistoryView(browserState: browserState, tabId: activeTabId)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if browserState.url(for: activeTabId)?.host == "downloads" {
                            LotusDownloadsView(browserState: browserState, tabId: activeTabId)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if browserState.url(for: activeTabId)?.host == "settings" {
                            LotusSettingsView(browserState: browserState, tabId: activeTabId)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // Unrecognized internal page — plain themed background.
                            containerBackground
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .transaction { $0.animation = nil }

                if browserState.isFindPresented && browserState.selectedTabId == activeTabId && !isInternalLotusPage {
                    FindBarView(browserState: browserState, tabId: activeTabId)
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                        .zIndex(100)
                        .transition(
                            .asymmetric(
                                insertion: .offset(y: -14).combined(with: .opacity),
                                removal: .offset(y: -14).combined(with: .opacity)
                            )
                        )
                }

            }
            .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.isFindPresented)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        .overlay(alignment: .top) {
            if topBarVisibility == "hover" && showsTopBar {
                topBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: showsTopBar)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(
            ZStack {
                containerBackground

                if let themeColor = theme.themeColor, isThemeBloomActive {
                    RadialGradient(
                        colors: [
                            themeColor.opacity(colorScheme == .dark ? 0.38 : 0.24),
                            themeColor.opacity(colorScheme == .dark ? 0.12 : 0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 420
                    )
                    .blur(radius: 28)
                    .scaleEffect(isThemeBloomActive ? 1.05 : 0.94)
                    .opacity(isThemeBloomActive ? 1.0 : 0.0)
                    .allowsHitTesting(false)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous))
        .overlay(
            Group {
                if isInSplitView && isFocusedContainer {
                    RoundedRectangle(cornerRadius: showsRoundedWebCorners ? 12 : 0, style: .continuous)
                        .stroke(containerStrokeColor, lineWidth: 1.5)
                        .padding(-2)
                } else {
                    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                        .stroke(containerStrokeColor, lineWidth: 1.0)
                }
            }
        )
        .shadow(
            color: (isInSplitView && isFocusedContainer)
                ? (colorScheme == .dark ? Color.black.opacity(0.30) : Color.black.opacity(0.08))
                : Color.clear,
            radius: 4,
            x: 0,
            y: 1
        )
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isFocusedContainer)
        .contentShape(RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous))
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                updateTopBarHover(at: location)
            case .ended:
                isPointerInside = false
            }
        }
        .onAppear(perform: migrateTopBarVisibilityIfNeeded)
        .onChange(of: browserState.themeBloomTrigger[activeTabId]) { _, trigger in
            guard trigger != nil, theme.themeColor != nil, !isInternalLotusPage else { return }
            withAnimation(.easeOut(duration: 0.38)) {
                isThemeBloomActive = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                withAnimation(.easeIn(duration: 0.55)) {
                    isThemeBloomActive = false
                }
            }
        }
        .onTapGesture {
            if browserState.selectedTabId != activeTabId {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                    browserState.selectTab(activeTabId)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BrowserContainer(browserState: BrowserState())
        .frame(width: 800, height: 600)
}
