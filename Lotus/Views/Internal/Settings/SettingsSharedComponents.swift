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

// MARK: - Category Pill

struct SettingsCategoryPill: View {
    let category: SettingsCategory
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 10.5, weight: .medium))

                Text(category.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected
                ? .white
                : (isHovered
                    ? (colorScheme == .dark ? .white : Color(nsColor: .labelColor))
                    : (colorScheme == .dark ? .white.opacity(0.60) : Color(nsColor: .secondaryLabelColor))))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected
                        ? Color.accentColor
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
