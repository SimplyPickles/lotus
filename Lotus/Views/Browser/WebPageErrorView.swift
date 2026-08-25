//
//  WebPageErrorView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI

struct WebPageErrorView: View {
    let error: PageLoadError
    let theme: BrowserChromeTheme
    let onRetry: () -> Void
    let onOpenHTTPFallback: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var isRetrying: Bool = false
    @State private var isHoveringRetry: Bool = false
    @State private var isHoveringFallback: Bool = false

    private var foregroundPrimary: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? Color.white.opacity(0.55) : Color(nsColor: .secondaryLabelColor)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var accentColor: Color {
        theme.themeColor ?? Color(nsColor: .controlAccentColor)
    }

    var body: some View {
        ZStack {
            // Under-page background matching browser theme
            theme.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Error Icon Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14),
                                    accentColor.opacity(colorScheme == .dark ? 0.06 : 0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .stroke(accentColor.opacity(colorScheme == .dark ? 0.35 : 0.22), lineWidth: 1)
                        )

                    Image(systemName: error.systemImage)
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(accentColor)
                }

                // Title & Description
                VStack(spacing: 8) {
                    Text(error.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(foregroundPrimary)
                        .multilineTextAlignment(.center)

                    Text(error.message)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(foregroundSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 440)
                }

                // URL & Error Code Detail Pill
                if let url = error.url {
                    HStack(spacing: 8) {
                        Text(url.absoluteString)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(foregroundSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text("•")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(foregroundSecondary.opacity(0.4))

                        Text("Error \(error.code)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(foregroundSecondary.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(cardBackground)
                            .overlay(
                                Capsule()
                                    .stroke(cardStroke, lineWidth: 1)
                            )
                    )
                    .frame(maxWidth: 480)
                }

                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        isRetrying = true
                        onRetry()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            isRetrying = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .rotationEffect(.degrees(isRetrying ? 360 : 0))
                                .animation(isRetrying ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default, value: isRetrying)

                            Text("Try Again")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(accentColor)
                                .opacity(isHoveringRetry ? 0.90 : 1.0)
                        )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .onHover { isHoveringRetry = $0 }

                    if error.isHTTPSEnforcedFailure, let fallback = onOpenHTTPFallback {
                        Button {
                            fallback()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.open")
                                    .font(.system(size: 12, weight: .regular))

                                Text("Load via Insecure HTTP")
                                    .font(.system(size: 13, weight: .regular))
                            }
                            .foregroundColor(foregroundPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(cardStroke, lineWidth: 1)
                                    )
                                    .opacity(isHoveringFallback ? 0.8 : 1.0)
                            )
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .onHover { isHoveringFallback = $0 }
                    }
                }
                .padding(.top, 8)
            }
            .padding(32)
            .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
}
