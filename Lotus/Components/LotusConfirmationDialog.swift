//
//  LotusConfirmationDialog.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI

/// Preset styles for confirmation dialog header icon squircle badges.
enum LotusDialogIconStyle {
    case destructive(systemImage: String = "trash.fill")
    case warning(systemImage: String = "exclamationmark.triangle.fill")
    case accent(systemImage: String, color: Color = .accentColor)
    case custom(gradient: LinearGradient, systemImage: String)

    var systemImage: String {
        switch self {
        case .destructive(let img): return img
        case .warning(let img): return img
        case .accent(let img, _): return img
        case .custom(_, let img): return img
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .destructive:
            return LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.45, blue: 0.45),
                    Color(red: 0.92, green: 0.20, blue: 0.20),
                    Color(red: 0.85, green: 0.08, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .warning:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.75, blue: 0.25),
                    Color(red: 0.95, green: 0.58, blue: 0.10),
                    Color(red: 0.90, green: 0.42, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .accent(_, let color):
            return LinearGradient(
                colors: [color.opacity(0.85), color, color.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .custom(let gradient, _):
            return gradient
        }
    }
}

/// A unified, macOS-styled confirmation modal dialog component.
///
/// Encapsulates the animated backdrop, rounded modal card container,
/// icon squircle, typography, hover animations, and action buttons.
struct LotusConfirmationDialog<Content: View, Actions: View>: View {
    let iconStyle: LotusDialogIconStyle?
    let title: String
    let subtitle: String?
    let cardWidth: CGFloat
    let onCancel: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let actions: () -> Actions

    @Environment(\.colorScheme) private var colorScheme

    init(
        iconStyle: LotusDialogIconStyle? = nil,
        title: String,
        subtitle: String? = nil,
        cardWidth: CGFloat = 440,
        onCancel: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.iconStyle = iconStyle
        self.title = title
        self.subtitle = subtitle
        self.cardWidth = cardWidth
        self.onCancel = onCancel
        self.content = content
        self.actions = actions
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? Color.white.opacity(0.65) : Color(nsColor: .secondaryLabelColor)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.14) : Color(nsColor: .windowBackgroundColor)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(colorScheme == .dark ? 0.45 : 0.28)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    onCancel()
                }

            // Modal Card
            VStack(alignment: .leading, spacing: 0) {
                // Header Icon Badge
                if let icon = iconStyle {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(icon.gradient)
                            .frame(width: 38, height: 38)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.10), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 5, y: 2)

                        Image(systemName: icon.systemImage)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                    }
                    .padding(.bottom, 14)
                }

                // Title
                Text(title)
                    .font(.system(size: 18.5, weight: .bold))
                    .foregroundColor(foregroundPrimary)
                    .lineLimit(2)
                    .padding(.bottom, 6)

                // Subtitle
                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundColor(foregroundSecondary)
                        .padding(.bottom, 20)
                }

                // Custom Content Slot
                content()

                // Actions Row
                HStack(spacing: 8) {
                    Spacer(minLength: 12)
                    actions()
                }
                .padding(.top, (subtitle == nil || subtitle?.isEmpty == true) ? 16 : 4)
            }
            .padding(22)
            .frame(width: cardWidth)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.18), radius: 30, x: 0, y: 14)
            .offset(y: -45)
            .transition(
                .asymmetric(
                    insertion: .offset(y: -14).combined(with: .opacity),
                    removal: .offset(y: -14).combined(with: .opacity)
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(100)
    }
}

// MARK: - Standard Action Buttons

/// Standard Cancel button with "ESC" badge and keyboard shortcut.
struct LotusDialogCancelButton: View {
    var title: String = "Cancel"
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? Color.white.opacity(0.65) : Color(nsColor: .secondaryLabelColor)
    }

    private var fill: Color {
        if colorScheme == .dark {
            return isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.10)
        } else {
            return isHovered ? Color.black.opacity(0.10) : Color.black.opacity(0.06)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(foregroundPrimary)

                Text("ESC")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(foregroundSecondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08))
                    )
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
        .onHover { isHovered = $0 }
    }
}

/// Standard Secondary / Neutral button without keyboard shortcut.
struct LotusDialogSecondaryButton: View {
    let title: String
    var shortcutText: String? = nil
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? Color.white.opacity(0.65) : Color(nsColor: .secondaryLabelColor)
    }

    private var fill: Color {
        if colorScheme == .dark {
            return isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.10)
        } else {
            return isHovered ? Color.black.opacity(0.10) : Color.black.opacity(0.06)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(foregroundPrimary)

                if let shortcut = shortcutText {
                    Text(shortcut)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(foregroundSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08))
                        )
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// Standard Confirm / Destructive button with Return keyboard shortcut.
struct LotusDialogActionButton: View {
    let title: String
    var isDestructive: Bool = true
    var systemIcon: String? = nil
    var shortcutImage: String? = "return"
    let action: () -> Void

    @State private var isHovered: Bool = false

    private var backgroundColor: Color {
        if isDestructive {
            return isHovered ? Color(red: 0.98, green: 0.15, blue: 0.15) : Color(red: 0.90, green: 0.05, blue: 0.05)
        } else {
            return isHovered ? Color.accentColor.opacity(0.88) : Color.accentColor
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon = systemIcon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                if let shortcut = shortcutImage {
                    Image(systemName: shortcut)
                        .font(.system(size: 11, weight: .bold))
                        .opacity(0.85)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [])
        .onHover { isHovered = $0 }
    }
}
