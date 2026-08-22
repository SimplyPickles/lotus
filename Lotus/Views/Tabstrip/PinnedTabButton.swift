//
//  PinnedTabButton.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import Combine

struct PinnedTabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered: Bool = false
    @ObservedObject private var colorExtractor = FaviconColorExtractor.shared
    @Environment(\.colorScheme) private var colorScheme

    private var outlineColor: Color {
        if let host = tab.url?.host?.lowercased(), host.contains("apple.com") {
            return colorScheme == .dark ? Color.white : Color.black
        }
        if let faviconURL = tab.faviconURL, let extracted = colorExtractor.color(for: faviconURL) {
            return extracted
        }
        return colorScheme == .dark ? Color.white : Color(nsColor: .labelColor)
    }

    private var backgroundGradient: LinearGradient {
        let topColor: Color
        let bottomColor: Color

        if colorScheme == .light {
            if isSelected {
                topColor = Color.white.opacity(0.95)
                bottomColor = Color.white.opacity(0.88)
            } else if isHovered {
                topColor = Color.white.opacity(0.75)
                bottomColor = Color.white.opacity(0.65)
            } else {
                topColor = Color.white.opacity(0.55)
                bottomColor = Color.white.opacity(0.45)
            }
        } else {
            if isSelected {
                topColor = outlineColor.opacity(0.5)
                bottomColor = outlineColor.opacity(0.4)
            } else if isHovered {
                topColor = outlineColor.opacity(0.14)
                bottomColor = outlineColor.opacity(0.10)
            } else {
                topColor = outlineColor.opacity(0.08)
                bottomColor = outlineColor.opacity(0.04)
            }
        }

        return LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var strokeColor: Color {
        if colorScheme == .light {
            if isSelected {
                return outlineColor.opacity(0.25)
            } else if isHovered {
                return Color.black.opacity(0.10)
            } else {
                return Color.black.opacity(0.06)
            }
        } else {
            if isSelected {
                return outlineColor.opacity(0.85)
            } else if isHovered {
                return outlineColor.opacity(0.35)
            } else {
                return outlineColor.opacity(0.12)
            }
        }
    }

    var body: some View {
        ZStack {
            faviconView
                .frame(width: 18, height: 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundGradient)
                .shadow(color: colorScheme == .light ? Color.black.opacity(isSelected ? 0.10 : 0.05) : Color.clear, radius: isSelected ? 3 : 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(strokeColor, lineWidth: isSelected ? 1.5 : 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .focusable(false)
    }

    @ViewBuilder
    private var faviconView: some View {
        if let host = tab.url?.host?.lowercased(), host.contains("apple.com") {
            Image(systemName: "apple.logo")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        } else if tab.url?.scheme == "lotus" || tab.url?.absoluteString.hasPrefix("lotus://") == true {
            Image(systemName: "camera.macro")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : Color(nsColor: .labelColor))
        } else if let faviconURL = tab.faviconURL {
            CachedFaviconView(
                url: faviconURL,
                defaultSystemName: "globe",
                fallbackColor: colorScheme == .dark ? .white.opacity(0.7) : Color(nsColor: .secondaryLabelColor),
                size: 16
            )
            .frame(width: 16, height: 16, alignment: .center)
        } else {
            defaultGlyph
        }
    }

    private var defaultGlyph: some View {
        Image(systemName: "globe")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : Color(nsColor: .secondaryLabelColor))
    }
}
