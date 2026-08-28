//
//  HistoryConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

enum HistoryConfirmationType: Equatable {
    case clearAll(totalCount: Int)
    case deleteSelected(ids: Set<UUID>)
}

struct HistoryConfirmationView: View {
    let confirmation: HistoryConfirmationType
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var isHoveringCancel: Bool = false
    @State private var isHoveringConfirm: Bool = false

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

    private func secondaryButtonFill(isHovered: Bool) -> Color {
        if colorScheme == .dark {
            return isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.10)
        } else {
            return isHovered ? Color.black.opacity(0.10) : Color.black.opacity(0.06)
        }
    }

    private var title: String {
        switch confirmation {
        case .clearAll:
            return "Clear browsing history?"
        case .deleteSelected(let ids):
            return ids.count == 1 ? "Delete 1 history item?" : "Delete \(ids.count) history items?"
        }
    }

    private var subtitle: String {
        switch confirmation {
        case .clearAll(let count):
            let itemText = count == 1 ? "page" : "pages"
            return "This will remove all \(count) \(itemText) from your browsing history. This action cannot be undone."
        case .deleteSelected(let ids):
            let itemText = ids.count == 1 ? "this page" : "these \(ids.count) pages"
            return "This will remove \(itemText) from your browsing history. This action cannot be undone."
        }
    }

    private var confirmButtonTitle: String {
        switch confirmation {
        case .clearAll:
            return "Clear All"
        case .deleteSelected:
            return "Delete"
        }
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
                // Icon Squircle
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.45, blue: 0.40),
                                    Color(red: 0.92, green: 0.20, blue: 0.20)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.10), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 5, y: 2)

                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                }
                .padding(.bottom, 14)

                // Title
                Text(title)
                    .font(.system(size: 18.5, weight: .bold))
                    .foregroundColor(foregroundPrimary)
                    .padding(.bottom, 6)

                // Subtitle
                Text(subtitle)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundColor(foregroundSecondary)
                    .padding(.bottom, 22)

                // Buttons row
                HStack(spacing: 8) {
                    Spacer(minLength: 12)

                    // Cancel button
                    Button {
                        onCancel()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Cancel")
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
                                .fill(secondaryButtonFill(isHovered: isHoveringCancel))
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    .onHover { isHoveringCancel = $0 }

                    // Confirm / Delete button
                    Button {
                        onConfirm()
                    } label: {
                        HStack(spacing: 5) {
                            Text(confirmButtonTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)

                            Image(systemName: "return")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isHoveringConfirm ? Color(red: 0.98, green: 0.15, blue: 0.15) : Color(red: 0.90, green: 0.05, blue: 0.05))
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                    .onHover { isHoveringConfirm = $0 }
                }
            }
            .padding(22)
            .frame(width: 440)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.18), radius: 30, x: 0, y: 14)
            // The overlay is hosted below the browser toolbar; compensate so
            // the dialog is centered in the full browser container.
            .offset(y: -20)
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
