//
//  FlyingDownloadView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import AppKit

/// Data payload for a flying download animation.
struct FlyingDownloadPayload: Identifiable, Equatable {
    let id = UUID()
    let filename: String
    let iconName: String
    let startPoint: CGPoint
    let themeColor: Color?
    let gradientColors: [Color]?
    let isThemeLight: Bool

    init(
        filename: String,
        iconName: String,
        startPoint: CGPoint,
        themeColor: Color? = nil,
        gradientColors: [Color]? = nil,
        isThemeLight: Bool = false
    ) {
        self.filename = filename
        self.iconName = iconName
        self.startPoint = startPoint
        self.themeColor = themeColor
        self.gradientColors = gradientColors
        self.isThemeLight = isThemeLight
    }
}

/// A floating badge showing the file icon and name that pops up at the cursor,
/// uses the active titlebar/window theme color with a slight border, and smoothly
/// jumps/flies into the Downloads button in the top right toolbar.
struct FlyingDownloadView: View {
    let payload: FlyingDownloadPayload
    let targetPoint: CGPoint
    var browserState: BrowserState? = nil
    let onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPoint: CGPoint
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0.0
    @State private var rotationAngle: Double = 0.0

    @State private var backdropOpacity: Double = 0.0

    init(payload: FlyingDownloadPayload, targetPoint: CGPoint, browserState: BrowserState? = nil, onComplete: @escaping () -> Void) {
        self.payload = payload
        self.targetPoint = targetPoint
        self.browserState = browserState
        self.onComplete = onComplete
        self._currentPoint = State(initialValue: payload.startPoint)
    }

    private var effectiveTargetPoint: CGPoint {
        browserState?.downloadsButtonCenter ?? targetPoint
    }

    private var isBackgroundLight: Bool {
        if let theme = payload.themeColor {
            if let ns = NSColor(theme).usingColorSpace(.sRGB) {
                let lum = 0.299 * Double(ns.redComponent) + 0.587 * Double(ns.greenComponent) + 0.114 * Double(ns.blueComponent)
                return lum > 0.55
            }
            return payload.isThemeLight
        }
        return colorScheme == .light
    }

    private var textColor: Color {
        if payload.themeColor != nil {
            return isBackgroundLight ? Color.black.opacity(0.92) : Color.white.opacity(0.98)
        }
        return colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var iconColor: Color {
        if payload.themeColor != nil {
            return isBackgroundLight ? Color.black.opacity(0.85) : Color.white.opacity(0.92)
        }
        return Color.accentColor
    }

    private var trailColors: [Color] {
        if let colors = payload.gradientColors, !colors.isEmpty {
            return colors
        }
        if let color = payload.themeColor {
            return [color, color.opacity(0.6)]
        }
        return [Color.accentColor, Color.accentColor.opacity(0.6)]
    }

    private var primaryFaviconColor: Color {
        payload.gradientColors?.first ?? payload.themeColor ?? Color.accentColor
    }

    private var pillBackground: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, state: .active)
            if let theme = payload.themeColor {
                theme.opacity(0.90)
            } else {
                (colorScheme == .dark
                    ? Color(nsColor: .windowBackgroundColor).opacity(0.85)
                    : Color(nsColor: .windowBackgroundColor).opacity(0.92))
            }
        }
        .clipShape(Capsule())
    }

    private var borderStrokeColor: Color {
        if payload.themeColor != nil {
            return isBackgroundLight ? Color.black.opacity(0.18) : Color.white.opacity(0.24)
        }
        return colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }

    private var flightTiltAngle: Double {
        let dest = effectiveTargetPoint
        let dx = dest.x - payload.startPoint.x
        let dy = dest.y - payload.startPoint.y
        let radians = atan2(dy, dx)
        let degrees = radians * 180.0 / .pi
        // Natural banking tilt towards destination (top-right trajectory yields a negative angle)
        return max(-35.0, min(35.0, degrees * 0.65))
    }

    var body: some View {
        ZStack {
            // Subtle darkening backdrop over the window
            Color.black
                .opacity(backdropOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Subtle, transparent colored gradient trail trailing behind the flying badge
            ZStack {
                // Layer 1: Wide atmospheric ambient diffusion
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                (trailColors.count > 1 ? trailColors.last! : primaryFaviconColor).opacity(0.20),
                                primaryFaviconColor.opacity(0.38)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 260 * max(0.4, scale), height: 80 * max(0.4, scale))
                    .blur(radius: 64)

                // Layer 2: Mid-range diffused glow
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                (trailColors.count > 1 ? trailColors.last! : primaryFaviconColor).opacity(0.30),
                                primaryFaviconColor.opacity(0.52)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 180 * max(0.4, scale), height: 50 * max(0.4, scale))
                    .blur(radius: 32)

                // Layer 3: Inner soft core streak trailing behind
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                primaryFaviconColor.opacity(0.40),
                                primaryFaviconColor.opacity(0.68)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 110 * max(0.4, scale), height: 28 * max(0.4, scale))
                    .blur(radius: 6)
            }
            .rotationEffect(.degrees(rotationAngle))
            .position(
                x: currentPoint.x - cos(rotationAngle * .pi / 180.0) * (64 * max(0.4, scale)),
                y: currentPoint.y - sin(rotationAngle * .pi / 180.0) * (64 * max(0.4, scale))
            )
            .opacity(opacity)
            .allowsHitTesting(false)

            HStack(spacing: 7) {
                Image(systemName: payload.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(payload.filename)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 170)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                pillBackground
                    .overlay(
                        Capsule()
                            .stroke(borderStrokeColor, lineWidth: 1.0)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.16), radius: 10, y: 3)
            )
            .rotationEffect(.degrees(rotationAngle))
            .scaleEffect(scale)
            .opacity(opacity)
            .position(currentPoint)
            .allowsHitTesting(false)
        }
        .onAppear {
            // Step 1: Pop in at cursor and dip downwards (+65pt) with smooth deceleration
            withAnimation(.easeOut(duration: 0.18)) {
                backdropOpacity = colorScheme == .dark ? 0.25 : 0.18
            }

            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                currentPoint = CGPoint(x: payload.startPoint.x, y: payload.startPoint.y + 65)
                scale = 1.0
                opacity = 1.0
                rotationAngle = 8.5
            }

            // Step 2: Seamlessly swoop out of the dip bottom across to the downloads button
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                let dest = effectiveTargetPoint
                withAnimation(.easeIn(duration: 0.36)) {
                    backdropOpacity = 0.0
                }

                withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
                    currentPoint = dest
                    scale = 0.16
                    opacity = 0.0
                    rotationAngle = flightTiltAngle
                }
            }

            // Step 3: Complete flight and trigger the catch pulse on the downloads button
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
                onComplete()
            }
        }
    }

    /// Resolves current cursor position relative to window coordinate space.
    static func currentMouseWindowLocation() -> CGPoint {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            return CGPoint(x: 300, y: 250)
        }
        let mouseLocInWindow = window.mouseLocationOutsideOfEventStream
        let windowHeight = window.frame.height
        let swiftUIY = max(30, min(windowHeight - 30, windowHeight - mouseLocInWindow.y))
        let swiftUIX = max(30, min(window.frame.width - 30, mouseLocInWindow.x))
        return CGPoint(x: swiftUIX, y: swiftUIY)
    }
}
