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
    @Environment(\.colorScheme) private var colorScheme

    private var effectiveHovered: Bool {
        isHovered && !isDraggingAnyTab
    }

    private var faviconColors: [Color] {
        if let host = tab.url?.host?.lowercased(), host.contains("apple.com") {
            let base = colorScheme == .dark ? Color.white : Color.black
            return [base, base.opacity(0.65)]
        }
        if let faviconURL = tab.faviconURL, let extracted = colorExtractor.colors(for: faviconURL), !extracted.isEmpty {
            return Array(extracted.prefix(3))
        }
        if let faviconURL = tab.faviconURL, let extracted = colorExtractor.color(for: faviconURL) {
            return [extracted, extracted]
        }
        let fallback = colorScheme == .dark ? Color.white : Color(nsColor: .labelColor)
        return [fallback, fallback.opacity(0.65)]
    }

    private var primaryColor: Color {
        faviconColors.first ?? (colorScheme == .dark ? Color.white : Color(nsColor: .labelColor))
    }

    private var secondaryColor: Color? {
        faviconColors.count > 1 ? faviconColors[1] : nil
    }

    private var tertiaryColor: Color? {
        faviconColors.count > 2 ? faviconColors[2] : nil
    }

    private var backgroundGradient: LinearGradient {
        let startOpacity: Double
        let endOpacity: Double

        if colorScheme == .light {
            if isSelected {
                startOpacity = 0.22
                endOpacity = 0.10
            } else if isInSplit {
                startOpacity = 0.18
                endOpacity = 0.08
            } else if effectiveHovered {
                startOpacity = 0.14
                endOpacity = 0.06
            } else {
                startOpacity = 0.10
                endOpacity = 0.04
            }
        } else {
            if isSelected {
                startOpacity = 0.24
                endOpacity = 0.10
            } else if isInSplit {
                startOpacity = 0.18
                endOpacity = 0.07
            } else if effectiveHovered {
                startOpacity = 0.14
                endOpacity = 0.05
            } else {
                startOpacity = 0.08
                endOpacity = 0.03
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
                startOpacity = 0.45
                endOpacity = 0.20
            } else if isInSplit {
                startOpacity = 0.35
                endOpacity = 0.16
            } else if effectiveHovered {
                startOpacity = 0.26
                endOpacity = 0.11
            } else {
                startOpacity = 0.18
                endOpacity = 0.07
            }
        } else {
            if isSelected {
                startOpacity = 0.55
                endOpacity = 0.26
            } else if isInSplit {
                startOpacity = 0.42
                endOpacity = 0.20
            } else if effectiveHovered {
                startOpacity = 0.30
                endOpacity = 0.14
            } else {
                startOpacity = 0.20
                endOpacity = 0.09
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
                                ? Color.white.opacity(0.85)
                                : (effectiveHovered
                                    ? Color.white.opacity(0.70)
                                    : Color.white.opacity(0.52)))
                            : (isSelected
                                ? Color.white.opacity(0.10)
                                : (effectiveHovered
                                    ? Color.white.opacity(0.06)
                                    : Color.white.opacity(0.03)))
                    )

                if isSelected, let namespace {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(backgroundGradient)
                        .matchedGeometryEffect(id: "activeTabHighlight", in: namespace)
                } else {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(backgroundGradient)
                }
            }
        )
        .shadow(
            color: colorScheme == .light
                ? Color.black.opacity(isSelected ? 0.06 : (effectiveHovered ? 0.03 : 0.015))
                : Color.black.opacity(isSelected ? 0.20 : (effectiveHovered ? 0.12 : 0.06)),
            radius: isSelected ? 3 : 1.5,
            x: 0,
            y: 1
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: isSelected ? 1.5 : (isInSplit ? 1.25 : 1))
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
