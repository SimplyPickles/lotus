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
    var isMultiSelected: Bool = false
    var isInSplit: Bool = false
    var isDraggingAnyTab: Bool = false
    var namespace: Namespace.ID? = nil
    var isRenaming: Bool = false
    var isPlayingAudio: Bool = false
    var isMuted: Bool = false
    var onToggleMute: () -> Void = {}
    var onCommitRename: (String) -> Void = { _ in }
    var onCancelRename: () -> Void = {}
    let onSelect: () -> Void

    @State private var isHovered: Bool = false
    @State private var draftTitle: String = ""
    @FocusState private var isTitleFocused: Bool
    @ObservedObject private var colorExtractor = FaviconColorExtractor.shared
    @AppStorage("lotus.browser.pinnedTabTintingMode") private var pinnedTabTintingMode: String = "adaptive"
    @Environment(\.colorScheme) private var colorScheme

    private var effectiveHovered: Bool {
        isHovered && !isDraggingAnyTab
    }

    private var faviconColors: [Color] {
        switch pinnedTabTintingMode {
        case "neutral":
            return [colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.12)]
        case "systemAccent":
            return [Color.accentColor]
        default: // "adaptive"
            var rawColors: [Color] = []
            if let faviconURL = tab.faviconURL, let extracted = colorExtractor.colors(for: faviconURL), !extracted.isEmpty {
                rawColors = extracted
            } else if let faviconURL = tab.faviconURL, let extracted = colorExtractor.color(for: faviconURL) {
                rawColors = [extracted]
            }

            let vibrant = rawColors.compactMap { Self.makeVibrant($0) }
            if !vibrant.isEmpty {
                return Array(vibrant.prefix(3))
            }

            return Self.vibrantDomainColors(for: tab)
        }
    }

    private var primaryColor: Color {
        faviconColors.first ?? Self.vibrantDomainColors(for: tab)[0]
    }

    private var secondaryColor: Color? {
        faviconColors.count > 1 ? faviconColors[1] : nil
    }

    private var tertiaryColor: Color? {
        faviconColors.count > 2 ? faviconColors[2] : nil
    }

    /// Checks if a color is non-plain (not white, gray, black, or washed out) and boosts its saturation if needed.
    static func makeVibrant(_ color: Color) -> Color? {
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return nil }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // Filter out gray, monochrome, near-white, or near-black colors
        if s < 0.22 || b < 0.18 || (b > 0.94 && s < 0.32) {
            return nil
        }

        // Boost saturation and brightness for luminous UI presence
        let boostedS = max(s * 1.15, 0.60)
        let boostedB = min(max(b, 0.72), 0.95)
        return Color(nsColor: NSColor(hue: h, saturation: min(boostedS, 1.0), brightness: boostedB, alpha: 1.0))
    }

    /// Produces a deterministic, high-energy vibrant 3-stop palette derived from the tab's domain or title.
    static func vibrantDomainColors(for tab: TabItem) -> [Color] {
        let domainString = tab.url?.host?.lowercased() ?? tab.title.lowercased()
        var hash: UInt64 = 5381
        for byte in domainString.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }

        // 12 curated vibrant hues: Sapphire, Emerald, Violet, Rose, Amber, Cyan, Indigo, Magenta, Coral, Teal, Amethyst, Ruby
        let hues: [CGFloat] = [
            0.58, // Sapphire Blue
            0.38, // Emerald Green
            0.78, // Vivid Violet
            0.96, // Rose Crimson
            0.08, // Warm Amber
            0.48, // Azure Cyan
            0.68, // Electric Indigo
            0.88, // Magenta Pink
            0.14, // Sunset Coral
            0.44, // Mint Teal
            0.82, // Royal Amethyst
            0.03  // Vivid Ruby Red
        ]
        let selectedHueIndex = Int(hash % UInt64(hues.count))
        let baseHue = hues[selectedHueIndex]
        let secondaryHue = (baseHue + 0.08).truncatingRemainder(dividingBy: 1.0)
        let tertiaryHue = (baseHue + 0.16).truncatingRemainder(dividingBy: 1.0)

        let c1 = Color(nsColor: NSColor(hue: baseHue, saturation: 0.78, brightness: 0.78, alpha: 1.0))
        let c2 = Color(nsColor: NSColor(hue: secondaryHue, saturation: 0.72, brightness: 0.84, alpha: 1.0))
        let c3 = Color(nsColor: NSColor(hue: tertiaryHue, saturation: 0.68, brightness: 0.88, alpha: 1.0))

        return [c1, c2, c3]
    }

    private var backgroundGradient: LinearGradient {
        let startOpacity: Double
        let endOpacity: Double

        if colorScheme == .light {
            if isSelected {
                startOpacity = 0.08
                endOpacity = 0.03
            } else if isInSplit {
                startOpacity = 0.06
                endOpacity = 0.02
            } else if effectiveHovered {
                startOpacity = 0.05
                endOpacity = 0.02
            } else {
                startOpacity = 0.03
                endOpacity = 0.01
            }
        } else {
            if isSelected {
                startOpacity = 0.10
                endOpacity = 0.04
            } else if isInSplit {
                startOpacity = 0.07
                endOpacity = 0.03
            } else if effectiveHovered {
                startOpacity = 0.05
                endOpacity = 0.02
            } else {
                startOpacity = 0.03
                endOpacity = 0.01
            }
        }

        var stops: [Gradient.Stop] = [
            .init(color: primaryColor.opacity(startOpacity), location: 0.0),
            .init(color: primaryColor.opacity(startOpacity * 0.85 + endOpacity * 0.15), location: 0.60)
        ]

        if let tertiary = tertiaryColor, let secondary = secondaryColor {
            stops.append(.init(color: secondary.opacity(startOpacity * 0.4 + endOpacity * 0.6), location: 0.85))
            stops.append(.init(color: tertiary.opacity(endOpacity), location: 1.0))
        } else if let secondary = secondaryColor {
            stops.append(.init(color: secondary.opacity(endOpacity), location: 1.0))
        } else {
            stops.append(.init(color: primaryColor.opacity(endOpacity), location: 1.0))
        }

        return LinearGradient(
            stops: stops,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        let startOpacity: Double
        let endOpacity: Double

        if colorScheme == .light {
            if isSelected {
                startOpacity = 0.75
                endOpacity = 0.50
            } else if isInSplit {
                startOpacity = 0.60
                endOpacity = 0.40
            } else if effectiveHovered {
                startOpacity = 0.50
                endOpacity = 0.32
            } else {
                startOpacity = 0.35
                endOpacity = 0.20
            }
        } else {
            if isSelected {
                startOpacity = 0.85
                endOpacity = 0.60
            } else if isInSplit {
                startOpacity = 0.70
                endOpacity = 0.48
            } else if effectiveHovered {
                startOpacity = 0.58
                endOpacity = 0.38
            } else {
                startOpacity = 0.42
                endOpacity = 0.25
            }
        }

        var stops: [Gradient.Stop] = [
            .init(color: primaryColor.opacity(startOpacity), location: 0.0),
            .init(color: primaryColor.opacity(startOpacity * 0.85 + endOpacity * 0.15), location: 0.60)
        ]

        if let tertiary = tertiaryColor, let secondary = secondaryColor {
            stops.append(.init(color: secondary.opacity(startOpacity * 0.4 + endOpacity * 0.6), location: 0.85))
            stops.append(.init(color: tertiary.opacity(endOpacity), location: 1.0))
        } else if let secondary = secondaryColor {
            stops.append(.init(color: secondary.opacity(endOpacity), location: 1.0))
        } else {
            stops.append(.init(color: primaryColor.opacity(endOpacity), location: 1.0))
        }

        return LinearGradient(
            stops: stops,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shadowColor: Color {
        if colorScheme == .light {
            return isSelected ? primaryColor.opacity(0.20) : Color.black.opacity(effectiveHovered ? 0.08 : 0.04)
        } else {
            return isSelected ? primaryColor.opacity(0.28) : Color.black.opacity(effectiveHovered ? 0.22 : 0.12)
        }
    }

    private var shadowRadius: CGFloat {
        isSelected ? 4.0 : (effectiveHovered ? 3.0 : 2.0)
    }

    private var shadowY: CGFloat {
        isSelected ? 1.8 : 1.0
    }

    var body: some View {
        HStack {
            if isRenaming {
                TextField("Tab Title", text: $draftTitle)
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .focused($isTitleFocused)
                    .onSubmit {
                        onCommitRename(draftTitle)
                    }
                    .onKeyPress(.escape) {
                        onCancelRename()
                        return .handled
                    }
            } else {
                ZStack {
                    faviconView
                        .opacity((isMuted || tab.isMuted || (isPlayingAudio && effectiveHovered)) ? 0 : 1)

                    if isMuted || tab.isMuted {
                        Button(action: onToggleMute) {
                            Image(systemName: "speaker.slash.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Unmute Tab")
                    } else if isPlayingAudio && effectiveHovered {
                        Button(action: onToggleMute) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .help("Mute Tab")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 38)
        .background(
            ZStack {
                // Base opaque card layer so pinned tabs are never see-through transparent in light mode
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        colorScheme == .light
                            ? (isSelected
                                ? Color.white.opacity(0.95)
                                : (effectiveHovered
                                    ? Color.white.opacity(0.85)
                                    : Color.white.opacity(0.70)))
                            : (isSelected
                                ? Color.white.opacity(0.10)
                                : (effectiveHovered
                                    ? Color.white.opacity(0.06)
                                    : Color.white.opacity(0.035)))
                    )

                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(backgroundGradient)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: isSelected ? 2.0 : (isInSplit ? 1.75 : (effectiveHovered ? 1.6 : 1.35)))
        )
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: shadowY
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.10), lineWidth: 2)
                )
                .opacity(isMultiSelected ? 1 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onTapGesture {
            if !isRenaming {
                onSelect()
            }
        }
        .onHover { hovering in
            guard !isDraggingAnyTab else {
                isHovered = false
                return
            }
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onChange(of: isRenaming) { _, renaming in
            if renaming {
                draftTitle = tab.title
                isTitleFocused = true
                DispatchQueue.main.async {
                    isTitleFocused = true
                }
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
            Image(systemName: tab.url?.internalPageSystemImage ?? "globe")
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
