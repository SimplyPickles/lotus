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
    @Environment(\.colorScheme) private var colorScheme

    private var theme: BrowserChromeTheme {
        BrowserChromeTheme(browserState: browserState, colorScheme: colorScheme)
    }

    private var isInternalLotusPage: Bool {
        browserState.activeURL?.isLotusPage == true
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                BrowserToolbar(browserState: browserState)
                    .zIndex(10)

                Divider()
                    .overlay(theme.foregroundPrimary.opacity(0.03))

                WebTabContainerView(browserState: browserState)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .background(theme.backgroundColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isInternalLotusPage ? 0 : 1)
            .allowsHitTesting(!isInternalLotusPage)

            if isInternalLotusPage {
                LotusNewTabView(browserState: browserState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .transaction { $0.animation = nil }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.foregroundPrimary.opacity(0.06), lineWidth: 1)
        )
        .padding([.top, .trailing, .bottom], 6)
        .padding(.leading, browserState.isSidebarVisible ? 0 : 6)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: browserState.isSidebarVisible)
        .animation(.easeInOut(duration: 0.15), value: isInternalLotusPage ? nil : browserState.activeThemeColor)
    }
}

// MARK: - Preview

#Preview {
    BrowserContainer(browserState: BrowserState())
        .frame(width: 800, height: 600)
}
