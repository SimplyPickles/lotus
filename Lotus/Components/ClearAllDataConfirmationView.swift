//
//  ClearAllDataConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import SwiftUI

struct ClearAllDataConfirmationView: View {
    @ObservedObject var browserState: BrowserState
    @State private var isHoveringCancel: Bool = false
    @State private var isHoveringClear: Bool = false
    @State private var isClearing: Bool = false

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    if !isClearing {
                        withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
                            browserState.isClearAllDataConfirmationPresented = false
                        }
                    }
                }

            // Modal Card
            VStack(alignment: .leading, spacing: 0) {
                // Warning Icon Squircle
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.32, blue: 0.28),
                                    Color(red: 0.82, green: 0.12, blue: 0.12)
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
                Text("Clear all browsing data?")
                    .font(.system(size: 18.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 6)

                // Subtitle
                Text("This will permanently clear all history, download history, disk & memory caches, cookies, saved logins, and website data. Open tabs will reload.")
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 22)

                // Buttons row
                HStack(spacing: 8) {
                    Spacer(minLength: 12)

                    // Cancel button
                    Button {
                        withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
                            browserState.isClearAllDataConfirmationPresented = false
                        }
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
                    .disabled(isClearing)
                    .onHover { isHoveringCancel = $0 }

                    // Clear All Data button
                    Button {
                        isClearing = true
                        browserState.clearAllBrowserData {
                            isClearing = false
                            withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
                                browserState.isClearAllDataConfirmationPresented = false
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isClearing {
                                ProgressView()
                                    .controlSize(.small)
                                    .colorScheme(.dark)
                            } else {
                                Text("Clear All Data")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)

                                Image(systemName: "return")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isHoveringClear ? Color(red: 0.98, green: 0.15, blue: 0.15) : Color(red: 0.90, green: 0.05, blue: 0.05))
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(isClearing)
                    .onHover { isHoveringClear = $0 }
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
    }
}
