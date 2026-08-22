//
//  BrowserChromeTheme.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

/// Centralizes the browser-chrome color derivations shared by
/// `BrowserContainer` and `BrowserToolbar`.
struct BrowserChromeTheme {
    let isInternalPage: Bool
    let themeColor: Color?
    let isThemeLight: Bool
    let colorScheme: ColorScheme

    init(browserState: BrowserState, colorScheme: ColorScheme) {
        self.isInternalPage = browserState.activeURL?.isLotusPage == true
        self.themeColor = browserState.activeThemeColor
        self.isThemeLight = browserState.isThemeLight
        self.colorScheme = colorScheme
    }

    var backgroundColor: Color {
        if isInternalPage {
            return Color(nsColor: .windowBackgroundColor)
        }
        return themeColor ?? Color(nsColor: .windowBackgroundColor)
    }

    var foregroundPrimary: Color {
        if !isInternalPage && themeColor != nil {
            return isThemeLight ? Color.black : Color.white
        }
        return Color.primary
    }

    var foregroundSecondary: Color {
        if !isInternalPage && themeColor != nil {
            return isThemeLight ? Color.black.opacity(0.60) : Color.white.opacity(0.65)
        }
        return Color.secondary
    }

    func inputBackground(isFocused: Bool, isHovered: Bool) -> Color {
        let hasCustomLightTheme = themeColor != nil && isThemeLight
        let base: Color
        if hasCustomLightTheme {
            base = Color.black
        } else if colorScheme == .dark || themeColor != nil {
            base = Color.white
        } else {
            base = Color.black
        }

        if isFocused {
            return base.opacity(0.12)
        } else if isHovered {
            return base.opacity(0.06)
        } else {
            return Color.clear
        }
    }
}
