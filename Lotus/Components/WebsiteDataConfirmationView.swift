//
//  WebsiteDataConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI

enum WebsiteDataConfirmationType: Equatable {
    case clearAll(totalCount: Int)
    case deleteSelected(domains: Set<String>)
}

struct WebsiteDataConfirmationView: View {
    let confirmation: WebsiteDataConfirmationType
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isHoveringCancel: Bool = false
    @State private var isHoveringConfirm: Bool = false

    private var title: String {
        switch confirmation {
        case .clearAll:
            return "Clear all website data?"
        case .deleteSelected(let domains):
            return domains.count == 1 ? "Delete data for 1 site?" : "Delete data for \(domains.count) sites?"
        }
    }

    private var subtitle: String {
        switch confirmation {
        case .clearAll(let count):
            let siteText = count == 1 ? "site" : "sites"
            return "This will clear cookies, cache, and local storage for all \(count) \(siteText). You may be logged out of active sessions. This action cannot be undone."
        case .deleteSelected(let domains):
            let siteText = domains.count == 1 ? "this site" : "these \(domains.count) sites"
            return "This will clear stored cookies, cache, and local data for \(siteText). This action cannot be undone."
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
            Color.black.opacity(0.45)
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
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 5, y: 2)

                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                }
                .padding(.bottom, 14)

                // Title
                Text(title)
                    .font(.system(size: 18.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 6)

                // Subtitle
                Text(subtitle)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.65))
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
                                .foregroundColor(.white)

                            Text("ESC")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.55))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isHoveringCancel ? Color.white.opacity(0.18) : Color.white.opacity(0.12))
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
                                .foregroundColor(.white)
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
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.13))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 30, x: 0, y: 14)
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
