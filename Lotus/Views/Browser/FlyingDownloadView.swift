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
    let isThemeLight: Bool

    init(filename: String, iconName: String, startPoint: CGPoint, themeColor: Color? = nil, isThemeLight: Bool = false) {
        self.filename = filename
        self.iconName = iconName
        self.startPoint = startPoint
        self.themeColor = themeColor
        self.isThemeLight = isThemeLight
    }
}

/// A floating badge showing the file icon and name that pops up at the cursor,
/// uses the active titlebar/window theme color with a slight border, and smoothly
/// jumps/flies into the Downloads button in the top right toolbar.
struct FlyingDownloadView: View {
    let payload: FlyingDownloadPayload
    let targetPoint: CGPoint
    let onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPoint: CGPoint
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0.0
    @State private var rotationAngle: Double = 0.0

    init(payload: FlyingDownloadPayload, targetPoint: CGPoint, onComplete: @escaping () -> Void) {
        self.payload = payload
        self.targetPoint = targetPoint
        self.onComplete = onComplete
        self._currentPoint = State(initialValue: payload.startPoint)
    }

    private var textColor: Color {
        if payload.themeColor != nil {
            return payload.isThemeLight ? Color.black.opacity(0.90) : Color.white.opacity(0.95)
        }
        return colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var iconColor: Color {
        if payload.themeColor != nil {
            return payload.isThemeLight ? Color.black.opacity(0.85) : Color.white.opacity(0.92)
        }
        return Color.accentColor
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
            return payload.isThemeLight ? Color.black.opacity(0.16) : Color.white.opacity(0.24)
        }
        return colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }

    var body: some View {
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
        .onAppear {
            // Step 1: Pop up at cursor location with initial rotation tilt
            withAnimation(.spring(response: 0.16, dampingFraction: 0.70)) {
                scale = 1.05
                opacity = 1.0
                rotationAngle = -5.0
            }

            // Step 2: Wiggle rotation immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.60)) {
                    rotationAngle = 6.0
                }
            }

            // Step 3: Swing immediately across to the top-right downloads icon without delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                    currentPoint = targetPoint
                    scale = 0.20
                    opacity = 0.0
                }
            }

            // Step 4: Complete flight and trigger the catch pulse on the downloads button
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
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
