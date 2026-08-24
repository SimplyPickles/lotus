//
//  PopupConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import SwiftUI

struct PopupConfirmationRequest: Identifiable {
    let id = UUID()
    let sourceTabId: UUID
    let sourceHost: String
    let targetURL: URL?
    let targetHost: String
}

struct PopupConfirmationView: View {
    @ObservedObject var browserState: BrowserState
    @State private var isHoveringCancel: Bool = false
    @State private var isHoveringOpen: Bool = false

    private var request: PopupConfirmationRequest? {
        browserState.pendingPopupRequest
    }

    var body: some View {
        guard let request = request else {
            return AnyView(EmptyView())
        }

        return AnyView(
            ZStack {
                // Dimmed backdrop
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        browserState.cancelOpenPopup()
                    }

                // Modal Card
                VStack(alignment: .leading, spacing: 0) {
                    // Icon Squircle
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.20, green: 0.55, blue: 0.95),
                                        Color(red: 0.10, green: 0.40, blue: 0.85)
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

                        Image(systemName: "plus.rectangle.on.rectangle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                    }
                    .padding(.bottom, 14)

                    // Title
                    Text("Open tab to \(request.targetHost)?")
                        .font(.system(size: 18.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, 6)
                        .lineLimit(2)

                    // Subtitle
                    Text("The website at \(request.sourceHost) is attempting to open a new tab.")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.65))
                        .padding(.bottom, 22)

                    // Buttons row
                    HStack(spacing: 8) {
                        Spacer(minLength: 12)

                        // Cancel button
                        Button {
                            browserState.cancelOpenPopup()
                        } label: {
                            HStack(spacing: 6) {
                                Text("Don't Open")
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

                        // Open Tab button
                        Button {
                            browserState.confirmOpenPopup()
                        } label: {
                            HStack(spacing: 5) {
                                Text("Open Tab")
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
                                    .fill(isHoveringOpen ? Color(red: 0.15, green: 0.50, blue: 0.95) : Color(red: 0.08, green: 0.42, blue: 0.88))
                            )
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: [])
                        .onHover { isHoveringOpen = $0 }
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
        )
    }
}
