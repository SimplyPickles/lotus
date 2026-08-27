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

    init(browserState: BrowserState, tabId: UUID? = nil, colorScheme: ColorScheme) {
        let id = tabId ?? browserState.selectedTabId
        let isInternal = browserState.url(for: id)?.isLotusPage == true
        let isShieldActive = browserState.isShieldActive(for: id)
        self.isInternalPage = isInternal
        
        let tintMode = UserDefaults.standard.string(forKey: "lotus.browser.titlebarChromeTintingMode")
            ?? UserDefaults.standard.string(forKey: "lotus.browser.chromeTintingMode")
            ?? "adaptive"
        
        switch tintMode {
        case "neutral":
            self.themeColor = nil
            self.isThemeLight = colorScheme == .light
        case "systemAccent":
            self.themeColor = browserState.currentProfile.color == .grey ? nil : browserState.currentProfile.color.color
            let accent = LotusAccentColor(rawValue: browserState.currentProfile.color.accentColorEquivalent.rawValue) ?? .white
            self.isThemeLight = browserState.currentProfile.color == .grey ? (colorScheme == .light) : (accent == .yellow)
        default: // "adaptive"
            if isInternal {
                self.themeColor = nil
                self.isThemeLight = colorScheme == .light
            } else {
                let resolvedTheme = browserState.themeColor(for: id) ?? (id == browserState.selectedTabId ? browserState.activeThemeColor : nil)
                self.themeColor = resolvedTheme
                self.isThemeLight = resolvedTheme != nil ? browserState.isThemeLight(for: id) : (colorScheme == .light)
            }
        }
        
        self.colorScheme = colorScheme
    }

    init(browserState: BrowserState, colorScheme: ColorScheme) {
        self.init(browserState: browserState, tabId: nil, colorScheme: colorScheme)
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
