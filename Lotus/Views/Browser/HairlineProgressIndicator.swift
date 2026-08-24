//
//  HairlineProgressIndicator.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import Combine
import QuartzCore

struct HairlineProgressIndicator: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    @ObservedObject private var colorExtractor = FaviconColorExtractor.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentProgress: Double = 0.0
    @State private var targetProgress: Double = 0.0
    @State private var opacity: Double = 0.0
    @State private var isFinishing: Bool = false
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var fadeTask: Task<Void, Never>? = nil

    private let hairlineHeight: CGFloat = 1.0

    private var activeTabId: UUID {
        tabId ?? browserState.selectedTabId
    }

    private var isInternalPage: Bool {
        browserState.url(for: activeTabId)?.isLotusPage == true
    }

    private var isLoading: Bool {
        browserState.isLoading(for: activeTabId)
    }

    private var estimatedProgress: Double {
        browserState.estimatedProgress(for: activeTabId)
    }

    private var detectedAccentColor: Color {
        let url = browserState.url(for: activeTabId)
        if let host = url?.host?.lowercased(), host.contains("apple.com") {
            return colorScheme == .dark ? Color.white : Color.black
        }
        if let faviconURL = browserState.tab(for: activeTabId)?.faviconURL,
           let extracted = colorExtractor.color(for: faviconURL) {
            return extracted
        }
        if let theme = browserState.themeColor(for: activeTabId) {
            return theme
        }
        return Color(nsColor: .controlAccentColor)
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let totalHeight = geometry.size.height
            let progressWidth = max(0, min(totalWidth, totalWidth * CGFloat(currentProgress)))

            ZStack(alignment: .bottomLeading) {
                if opacity > 0 && progressWidth > 0 {
                    // Subtle ambient gradient wash inside the input box
                    LinearGradient(
                        stops: [
                            .init(color: detectedAccentColor.opacity(colorScheme == .dark ? 0.10 : 0.06), location: 0.0),
                            .init(color: detectedAccentColor.opacity(colorScheme == .dark ? 0.05 : 0.03), location: 0.70),
                            .init(color: detectedAccentColor.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: progressWidth, height: totalHeight)

                    // Delicate vertical tint softening upwards
                    LinearGradient(
                        colors: [
                            detectedAccentColor.opacity(colorScheme == .dark ? 0.07 : 0.04),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(width: progressWidth, height: totalHeight)

                    // Thin 1.0pt hairline indicator bar along the bottom edge
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: detectedAccentColor.opacity(0.25), location: 0.0),
                                        .init(color: detectedAccentColor.opacity(0.65), location: 0.65),
                                        .init(color: detectedAccentColor.opacity(0.85), location: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: progressWidth, height: hairlineHeight)

                        // Delicate feathering at the advancing tip
                        if progressWidth > 6 {
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.28),
                                    Color.white.opacity(0.10)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: min(20, progressWidth), height: hairlineHeight)
                            .offset(x: max(0, progressWidth - 20))
                        }
                    }
                    .frame(height: hairlineHeight)
                    .shadow(color: detectedAccentColor.opacity(0.30), radius: 1.0, x: 0, y: 0)
                }
            }
            .frame(width: totalWidth, height: totalHeight, alignment: .bottomLeading)
            .opacity(opacity)
        }
        .allowsHitTesting(false)
        .onAppear {
            if isLoading && !isInternalPage {
                targetProgress = max(0.08, estimatedProgress)
                currentProgress = targetProgress * 0.5
                withAnimation(.easeOut(duration: 0.15)) {
                    opacity = 1.0
                }
                startAnimationLoop()
            }
        }
        .onChange(of: activeTabId) {
            fadeTask?.cancel()
            fadeTask = nil
            if isLoading && !isInternalPage {
                targetProgress = max(0.08, estimatedProgress)
                currentProgress = targetProgress
                isFinishing = false
                withAnimation(.easeOut(duration: 0.15)) {
                    opacity = 1.0
                }
                startAnimationLoop()
            } else {
                resetState()
            }
        }
        .onChange(of: isLoading) { _, loading in
            if isInternalPage {
                resetState()
                return
            }

            if loading {
                fadeTask?.cancel()
                fadeTask = nil
                isFinishing = false
                targetProgress = max(0.08, estimatedProgress)
                if opacity == 0 {
                    currentProgress = 0.02
                    withAnimation(.easeOut(duration: 0.15)) {
                        opacity = 1.0
                    }
                }
                startAnimationLoop()
            } else {
                if opacity > 0 && currentProgress > 0 {
                    isFinishing = true
                    targetProgress = 1.0
                    startAnimationLoop()
                } else {
                    resetState()
                }
            }
        }
        .onChange(of: estimatedProgress) { _, newProgress in
            guard isLoading, !isInternalPage else { return }
            let clamped = max(0.08, min(0.96, newProgress))
            if clamped > targetProgress {
                targetProgress = clamped
            }
        }
        .onChange(of: browserState.url(for: activeTabId)) {
            if isInternalPage {
                resetState()
            }
        }
    }

    private func resetState() {
        animationTask?.cancel()
        animationTask = nil
        fadeTask?.cancel()
        fadeTask = nil
        currentProgress = 0.0
        targetProgress = 0.0
        opacity = 0.0
        isFinishing = false
    }

    private func startAnimationLoop() {
        guard animationTask == nil else { return }

        animationTask = Task { @MainActor in
            var lastTime = CACurrentMediaTime()

            while !Task.isCancelled {
                let currentTime = CACurrentMediaTime()
                let dt = min(max(currentTime - lastTime, 0.001), 0.05)
                lastTime = currentTime

                let isStillRunning = updateInterpolation(dt: dt)

                if !isStillRunning {
                    break
                }

                try? await Task.sleep(nanoseconds: 16_666_667)
            }

            animationTask = nil
        }
    }

    private func updateInterpolation(dt: Double) -> Bool {
        if isInternalPage {
            resetState()
            return false
        }

        if isLoading && !isFinishing {
            // Gentle continuous trickle if network is waiting on data
            if targetProgress < 0.90 {
                targetProgress += (0.90 - targetProgress) * 0.04 * dt
            }

            // Smooth fluid approach towards targetProgress
            let diff = targetProgress - currentProgress
            if diff > 0.0001 {
                let rate = max(3.5, min(7.5, diff * 10.0))
                currentProgress += diff * min(1.0, rate * dt)
            }

            return true
        } else if isFinishing {
            // Swiftly glide to 1.0 on completion
            let diff = 1.0 - currentProgress
            if diff > 0.001 {
                currentProgress += diff * min(1.0, 11.0 * dt)
                return true
            } else {
                currentProgress = 1.0
                isFinishing = false
                startFadeOut()
                browserState.triggerPageLoadShimmer(for: activeTabId)
                return false
            }
        } else {
            return false
        }
    }

    private func startFadeOut() {
        fadeTask?.cancel()
        fadeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.28)) {
                opacity = 0.0
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            if !isLoading {
                resetState()
            }
        }
    }
}
