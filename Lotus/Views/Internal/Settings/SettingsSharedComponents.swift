//
//  SettingsSharedComponents.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General & Search"
    case appearance = "Appearance"
    case tabs = "Tabs & Sidebar"
    case media = "Media & Performance"
    case shields = "Shields & Blocking"
    case privacy = "Privacy & Data"
    case downloads = "Downloads"
    case shortcuts = "Shortcuts"
    case about = "About"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintpalette"
        case .tabs: return "sidebar.left"
        case .media: return "bolt"
        case .shields: return "shield.checkered"
        case .privacy: return "lock.shield"
        case .downloads: return "arrow.down.circle"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Accent Colors

enum LotusAccentColor: String, CaseIterable, Identifiable {
    case white = "white"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .white: return "Default (System)"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        }
    }

    static var systemAccentColor: Color {
        guard let accentPref = UserDefaults.standard.object(forKey: "AppleAccentColor") as? Int else {
            // "Multicolor" is selected in macOS System Settings -> Apple Blue
            return Color(nsColor: .systemBlue)
        }

        switch accentPref {
        case 0: return Color(nsColor: .systemRed)
        case 1: return Color(nsColor: .systemOrange)
        case 2: return Color(nsColor: .systemYellow)
        case 3: return Color(nsColor: .systemGreen)
        case 4: return Color(nsColor: .systemBlue)
        case 5: return Color(nsColor: .systemPurple)
        case 6: return Color(nsColor: .systemPink)
        case -1: return Color(nsColor: .systemGray)
        default:
            return Color(nsColor: .systemBlue)
        }
    }

    var color: Color {
        switch self {
        case .white:
            return LotusAccentColor.systemAccentColor
        case .blue:
            return FolderColor.blue.color
        case .purple:
            return FolderColor.purple.color
        case .pink:
            return FolderColor.pink.color
        case .red:
            return FolderColor.red.color
        case .orange:
            return FolderColor.orange.color
        case .yellow:
            return FolderColor.yellow.color
        case .green:
            return FolderColor.green.color
        }
    }

    var swatchColor: Color {
        switch self {
        case .white:
            return Color.white
        default:
            return color
        }
    }

    var hexString: String {
        switch self {
        case .white:
            if let accentPref = UserDefaults.standard.object(forKey: "AppleAccentColor") as? Int {
                switch accentPref {
                case 0: return "#FF3B30" // Red
                case 1: return "#FF9500" // Orange
                case 2: return "#FFCC00" // Yellow
                case 3: return "#34C759" // Green
                case 4: return "#007AFF" // Blue
                case 5: return "#AF52DE" // Purple
                case 6: return "#FF2D55" // Pink
                case -1: return "#8E8E93" // Graphite
                default: return "#007AFF"
                }
            }
            return "#007AFF"
        case .blue: return "#007AFF"
        case .purple: return "#AF52DE"
        case .pink: return "#FF2D55"
        case .red: return "#FF3B30"
        case .orange: return "#FF9500"
        case .yellow: return "#FFCC00"
        case .green: return "#34C759"
        }
    }

    static var current: LotusAccentColor {
        let key = UserDefaults.standard.string(forKey: "lotus.browser.accentColor") ?? "white"
        return LotusAccentColor(rawValue: key) ?? .white
    }

    static var currentAccentHex: String {
        current.hexString
    }
}

// MARK: - Category Pill

struct SettingsCategoryPill: View {
    let category: SettingsCategory
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lotus.browser.accentColor") private var accentColorKey: String = "white"

    private var activeFill: Color {
        let accent = LotusAccentColor(rawValue: accentColorKey) ?? .white
        return accent.color
    }

    private var activeTextColor: Color {
        let accent = LotusAccentColor(rawValue: accentColorKey) ?? .white
        if accent == .yellow {
            return Color.black
        }
        return Color.white
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 10.5, weight: .medium))

                Text(category.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected
                ? activeTextColor
                : (isHovered
                    ? (colorScheme == .dark ? .white : Color(nsColor: .labelColor))
                    : (colorScheme == .dark ? .white.opacity(0.60) : Color(nsColor: .secondaryLabelColor))))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected
                        ? activeFill
                        : (isHovered
                            ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Settings Section Card

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(foregroundSecondary)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(foregroundSecondary)
            }
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

// MARK: - Settings Divider

struct SettingsDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    private var separatorColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
    }

    var body: some View {
        Rectangle()
            .fill(separatorColor)
            .frame(height: 1)
            .padding(.leading, 48)
    }
}

// MARK: - Generic Settings Row

struct SettingsRow: View {
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

// MARK: - Untinted Dropdown Extension

extension View {
    func untintedDropdown() -> some View {
        self
            .pickerStyle(.menu)
            .tint(Color.primary)
            .accentColor(Color.primary)
    }
}
