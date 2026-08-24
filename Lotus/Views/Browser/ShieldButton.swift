//
//  ShieldButton.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import SwiftUI

/// Toolbar button showing the shield status for the active tab and opening the ShieldPopover.
struct ShieldButton: View {
    @ObservedObject var browserState: BrowserState
    let tabId: UUID
    let theme: BrowserChromeTheme

    @ObservedObject private var contentBlocker = ContentBlockerService.shared
    @State private var isShieldPopoverPresented: Bool = false

    // Microinteraction states
    @State private var rotationAngle: Double = 0.0
    @State private var iconScale: CGFloat = 1.0

    private var currentURL: URL? {
        browserState.url(for: tabId)
    }

    private var isLotusPage: Bool {
        currentURL?.isLotusPage == true
    }

    private var isShieldActive: Bool {
        contentBlocker.isShieldActive(for: currentURL)
    }

    var body: some View {
        Button {
            isShieldPopoverPresented.toggle()
        } label: {
            ZStack {
                let activeColor = theme.themeColor != nil ? (theme.isThemeLight ? Color.black : Color.white) : Color.accentColor
                let inactiveColor = theme.themeColor != nil ? (theme.isThemeLight ? Color.black.opacity(0.4) : Color.white.opacity(0.4)) : Color.secondary
                Image(systemName: isShieldActive ? "shield.checkered" : "shield.slash")
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundColor(isShieldActive ? activeColor : inactiveColor)
                    .opacity(isShieldActive ? 1.0 : 0.65)
                    .rotationEffect(.degrees(rotationAngle))
                    .scaleEffect(iconScale)
            }
        }
        .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
        .disabled(isLotusPage)
        .opacity(isLotusPage ? 0.35 : 1.0)
        .focusable(false)
        .help(isShieldActive ? "Shields: Active" : "Shields: Paused")
        .onChange(of: isShieldActive) { wasActive, nowActive in
            if !nowActive {
                // Paused: subtle, smooth micro-rotation shake and gentle compression
                withAnimation(.spring(response: 0.16, dampingFraction: 0.52)) {
                    rotationAngle = -6.5
                    iconScale = 0.94
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.55)) {
                        rotationAngle = 3.5
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        rotationAngle = 0.0
                        iconScale = 1.0
                    }
                }
            } else {
                // Resumed / Active: smooth, gentle spring pop
                withAnimation(.spring(response: 0.22, dampingFraction: 0.60)) {
                    iconScale = 1.08
                    rotationAngle = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.75)) {
                        iconScale = 1.0
                    }
                }
            }
        }
        .popover(isPresented: $isShieldPopoverPresented, arrowEdge: .bottom) {
            ShieldPopover(browserState: browserState, tabId: tabId) {
                isShieldPopoverPresented = false
            }
        }
    }
}
