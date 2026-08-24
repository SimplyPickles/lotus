//
//  WebTabContainerView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import WebKit

struct WebTabContainerView: NSViewRepresentable {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil

    private var activeTabId: UUID {
        tabId ?? browserState.selectedTabId
    }

    private var isInternalLotusPage: Bool {
        let url = browserState.url(for: activeTabId)
        return url?.scheme == "lotus" || url?.absoluteString.hasPrefix("lotus://") == true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var lastShimmerTrigger: Int = 0
    }

    func makeNSView(context: Context) -> WebTabHostNSView {
        let hostView = WebTabHostNSView()
        context.coordinator.lastShimmerTrigger = browserState.pageLoadShimmerTrigger[activeTabId] ?? 0
        if !isInternalLotusPage {
            hostView.updateActiveWebView(browserState.getWebView(for: activeTabId))
        }
        return hostView
    }

    func updateNSView(_ nsView: WebTabHostNSView, context: Context) {
        if !isInternalLotusPage {
            nsView.updateActiveWebView(browserState.getWebView(for: activeTabId))
            let currentTrigger = browserState.pageLoadShimmerTrigger[activeTabId] ?? 0
            if currentTrigger > context.coordinator.lastShimmerTrigger {
                context.coordinator.lastShimmerTrigger = currentTrigger
                let showsShimmer = UserDefaults.standard.object(forKey: "lotus.browser.showsWebpageShimmer") as? Bool ?? true
                let lowPowerModeDisabled = UserDefaults.standard.bool(forKey: "lotus.browser.lowPowerModeShimmerDisabled")
                let isThermalOrBatterySaving = ProcessInfo.processInfo.isLowPowerModeEnabled
                
                if showsShimmer && !(lowPowerModeDisabled && isThermalOrBatterySaving) {
                    let color = browserState.detectedAccentNSColor(for: activeTabId)
                    nsView.triggerShimmer(color: color)
                }
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WebTabHostNSView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

final class WebTabHostNSView: NSView {
    private var currentWebView: WKWebView?
    private var shimmerOverlayView: NSView?

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.layer?.cornerRadius = 0
        self.layer?.maskedCorners = []
        self.layer?.masksToBounds = true
        self.autoresizesSubviews = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func triggerShimmer(color: NSColor) {
        guard bounds.width > 0, bounds.height > 0 else { return }

        shimmerOverlayView?.removeFromSuperview()

        let w = bounds.width
        let h = bounds.height
        let bandHeight = max(h * 0.90, 520)

        let overlay = ShimmerOverlayNSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        overlay.wantsLayer = true
        overlay.layer?.masksToBounds = true
        overlay.autoresizingMask = [.width, .height]

        let gradient = CAGradientLayer()
        gradient.frame = NSRect(x: 0, y: 0, width: w, height: bandHeight)
        gradient.startPoint = CGPoint(x: 0.5, y: 1.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 0.0)

        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let baseColor = color.usingColorSpace(.sRGB) ?? NSColor.controlAccentColor

        // Luminous shimmer wave: delicate ambient wings with a subtle glint core
        let c0 = baseColor.withAlphaComponent(0.0).cgColor
        let cWing = baseColor.withAlphaComponent(isDark ? 0.012 : 0.008).cgColor
        let cBody = baseColor.withAlphaComponent(isDark ? 0.036 : 0.026).cgColor
        let cInner = baseColor.withAlphaComponent(isDark ? 0.065 : 0.048).cgColor
        let cPeak = baseColor.withAlphaComponent(isDark ? 0.090 : 0.068).cgColor

        gradient.colors = [
            c0,
            cWing,
            cBody,
            cInner,
            cPeak,
            cInner,
            cBody,
            cWing,
            c0
        ]
        gradient.locations = [
            0.0,
            0.18,
            0.34,
            0.44,
            0.50,
            0.56,
            0.66,
            0.82,
            1.0
        ]

        overlay.layer?.addSublayer(gradient)
        addSubview(overlay, positioned: .above, relativeTo: currentWebView)
        self.shimmerOverlayView = overlay

        // Slide upward from bottom to top
        let startY = -bandHeight / 2
        let endY = h + bandHeight / 2

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak overlay] in
            if self?.shimmerOverlayView === overlay {
                overlay?.removeFromSuperview()
                self?.shimmerOverlayView = nil
            }
        }

        let duration: CFTimeInterval = 0.55

        let anim = CABasicAnimation(keyPath: "position.y")
        anim.fromValue = startY
        anim.toValue = endY
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(controlPoints: 0.20, 0.0, 0.24, 1.0)
        anim.isRemovedOnCompletion = false
        anim.fillMode = .forwards

        let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnim.values = [0.0, 1.0, 1.0, 0.0]
        opacityAnim.keyTimes = [0.0, 0.12, 0.86, 1.0]
        opacityAnim.duration = duration
        opacityAnim.isRemovedOnCompletion = false
        opacityAnim.fillMode = .forwards

        gradient.add(anim, forKey: "shimmerUp")
        gradient.add(opacityAnim, forKey: "shimmerFade")
        CATransaction.commit()
    }

    func updateActiveWebView(_ newWebView: WKWebView) {
        let isTabSwitch = newWebView !== currentWebView

        if isTabSwitch {
            newWebView.underPageBackgroundColor = NSColor.windowBackgroundColor
            newWebView.wantsLayer = true
            newWebView.layer?.cornerRadius = 0
            newWebView.layer?.maskedCorners = []
            newWebView.layer?.masksToBounds = false

            clearCornerRadii(in: newWebView)
            newWebView.autoresizingMask = [.width, .height]

            if newWebView.superview != self {
                addSubview(newWebView)
            } else {
                addSubview(newWebView, positioned: .above, relativeTo: nil)
            }
            newWebView.frame = bounds
            newWebView.isHidden = false
            currentWebView = newWebView

            for subview in subviews {
                if subview !== newWebView {
                    subview.removeFromSuperview()
                }
            }

            applyBoundsToSubviews()

            DispatchQueue.main.async { [weak self, weak newWebView] in
                guard let self = self, let wv = newWebView, !wv.isHidden else { return }
                let win = wv.window ?? self.window ?? NSApp.keyWindow
                if let responder = win?.firstResponder, (responder is NSTextView || responder is NSTextField) {
                    return
                }
                win?.makeFirstResponder(wv)
            }
        } else {
            if newWebView.isHidden {
                newWebView.isHidden = false
            }
            applyBoundsToSubviews()
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        applyBoundsToSubviews()
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        applyBoundsToSubviews()
    }

    override var frame: NSRect {
        didSet {
            applyBoundsToSubviews()
        }
    }

    override var bounds: NSRect {
        didSet {
            applyBoundsToSubviews()
        }
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        applyBoundsToSubviews()
    }

    override func layout() {
        super.layout()
        applyBoundsToSubviews()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyBoundsToSubviews()
        if let currentWebView = currentWebView, !currentWebView.isHidden {
            let win = self.window ?? NSApp.keyWindow
            if let responder = win?.firstResponder, (responder is NSTextView || responder is NSTextField) {
                return
            }
            win?.makeFirstResponder(currentWebView)
        }
    }

    override func viewWillDraw() {
        super.viewWillDraw()
        applyBoundsToSubviews()
    }

    private func applyBoundsToSubviews() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let targetFrame = NSRect(x: 0, y: 0, width: ceil(bounds.width), height: ceil(bounds.height))
        for subview in subviews {
            if subview.frame != targetFrame {
                subview.frame = targetFrame
                subview.needsLayout = true
            }
        }
    }

    private func clearCornerRadii(in view: NSView) {
        view.layer?.cornerRadius = 0
        view.layer?.maskedCorners = []

        for subview in view.subviews {
            clearCornerRadii(in: subview)
        }
    }
}

// MARK: - Shimmer Overlay NSView

final class ShimmerOverlayNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
