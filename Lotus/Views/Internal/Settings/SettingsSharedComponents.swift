//
//  SettingsSharedComponents.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

enum SettingsCategoryGroup: String, CaseIterable, Identifiable {
    case general = "General"
    case security = "Privacy & Security"
    case tools = "Tools & Advanced"

    var id: String { rawValue }
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General & Search"
    case appearance = "Appearance"
    case tabs = "Tabs & Sidebar"
    case profiles = "Profiles"
    case shields = "Shields & Blocking"
    case privacy = "Privacy & Data"
    case downloads = "Downloads"
    case media = "Media & Performance"
    case shortcuts = "Shortcuts"
    case about = "About"

    var id: String { rawValue }

    var group: SettingsCategoryGroup {
        switch self {
        case .general, .appearance, .tabs, .profiles:
            return .general
        case .shields, .privacy, .downloads:
            return .security
        case .media, .shortcuts, .about:
            return .tools
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .profiles: return "person.crop.circle.fill"
        case .tabs: return "sidebar.left"
        case .media: return "bolt.fill"
        case .shields: return "shield.fill"
        case .privacy: return "lock.shield.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .shortcuts: return "keyboard.fill"
        case .about: return "info.circle.fill"
        }
    }

    var iconBackground: Color {
        switch self {
        case .general: return Color(nsColor: .systemGray)
        case .appearance: return Color(nsColor: .systemPurple)
        case .profiles: return Color(nsColor: .systemOrange)
        case .tabs: return Color(nsColor: .systemBlue)
        case .shields: return Color(nsColor: .systemRed)
        case .privacy: return Color(nsColor: .systemIndigo)
        case .downloads: return Color(nsColor: .systemTeal)
        case .media: return Color(nsColor: .systemGreen)
        case .shortcuts: return Color(nsColor: .systemPink)
        case .about: return Color(nsColor: .systemGray)
        }
    }

    var title: String {
        switch self {
        case .general: return "General & Search"
        case .appearance: return "Appearance"
        case .tabs: return "Tabs & Sidebar"
        case .profiles: return "Profiles"
        case .shields: return "Shields & Blocking"
        case .privacy: return "Privacy & Data"
        case .downloads: return "Downloads"
        case .media: return "Media & Performance"
        case .shortcuts: return "Keyboard Shortcuts"
        case .about: return "About Lotus"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Default browser, startup behavior, and search engine preferences"
        case .appearance: return "Theme, window framing, accent colors, and toolbar layout"
        case .tabs: return "Tab strip behavior, automatic grouping, and inactive tab archiving"
        case .profiles: return "Independent profile spaces with separate cookies, tabs, and logins"
        case .shields: return "Tracker blocking, cosmetic filtering, and custom element zapper"
        case .privacy: return "Browsing history, cookie management, and connection security"
        case .downloads: return "File download directory, tidy filenames, and download logs"
        case .media: return "Autoplay restrictions, Picture-in-Picture, and memory saver"
        case .shortcuts: return "Key bindings, hotkeys, and quick navigation actions"
        case .about: return "Browser version details, user agent configuration, and diagnostics"
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
        case .white: return "Monochrome"
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
            return Color(nsColor: .controlAccentColor)
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
            return Color.primary
        default:
            return color
        }
    }

    var folderColorEquivalent: FolderColor {
        switch self {
        case .white: return .grey
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
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

extension FolderColor {
    var accentColorEquivalent: LotusAccentColor {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .grey: return .white
        }
    }
}

// MARK: - Sidebar Item (macOS & Arc/Dia Style)

struct SettingsSidebarItem: View {
    let category: SettingsCategory
    let isSelected: Bool
    var accentColor: Color? = nil
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var activeAccent: Color {
        accentColor ?? Color(nsColor: .controlAccentColor)
    }

    private var isAccentLight: Bool {
        if let accent = accentColor {
            return accent == FolderColor.yellow.color
        }
        return false
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                // Vibrant macOS-style squircle badge icon
                ZStack {
                    RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                        .fill(category.iconBackground.gradient)
                        .frame(width: 20, height: 20)

                    Image(systemName: category.systemImage)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(category.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(
                        isSelected
                            ? (isAccentLight ? Color.black : Color.white)
                            : (colorScheme == .dark ? Color.white.opacity(0.92) : Color(nsColor: .labelColor))
                    )
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .fill(isSelected ? activeAccent : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
    }
}

// MARK: - Settings Section Card (macOS Inset Grouped Card with Zero Outlines)

struct SettingsSectionCard<Content: View>: View {
    let title: String?
    let footer: String?
    let systemImage: String?
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    init(title: String? = nil, footer: String? = nil, systemImage: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.systemImage = systemImage
        self.content = content
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white
    }

    var body: some View {
        Spacer()
        VStack(alignment: .leading, spacing: 6) {
            if let title = title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : Color(nsColor: .labelColor))
                    .padding(.leading, 4)
                    .padding(.bottom, 1)
            }

            VStack(spacing: 0, content: content)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(cardFill)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .focusEffectDisabled()

            if let footer = footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.48) : Color(nsColor: .secondaryLabelColor))
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Settings Divider (Inset Separator)

struct SettingsDivider: View {
    @Environment(\.colorScheme) private var colorScheme
    var leadingInset: CGFloat = 14

    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

// MARK: - Generic Settings Row

struct SettingsRow: View {
    let systemImage: String?
    let title: String
    let detail: String

    @Environment(\.colorScheme) private var colorScheme

    init(systemImage: String? = nil, title: String, detail: String) {
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : Color(nsColor: .labelColor))

            Spacer()

            Text(detail)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor))
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
            .tint(Color(nsColor: .controlTextColor))
            .accentColor(Color(nsColor: .controlTextColor))
            .foregroundColor(Color(nsColor: .controlTextColor))
            .focusable(false)
            .focusEffectDisabled()
    }
}
