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

    private var isInternalLotusPage: Bool {
        browserState.activeURL?.scheme == "lotus" || browserState.activeURL?.absoluteString.hasPrefix("lotus://") == true
    }

    func makeNSView(context: Context) -> WebTabHostNSView {
        let hostView = WebTabHostNSView()
        if !isInternalLotusPage {
            hostView.updateActiveWebView(browserState.activeWebView)
        }
        return hostView
    }

    func updateNSView(_ nsView: WebTabHostNSView, context: Context) {
        if !isInternalLotusPage {
            nsView.updateActiveWebView(browserState.activeWebView)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WebTabHostNSView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

final class WebTabHostNSView: NSView {
    private var currentWebView: WKWebView?

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.layer?.cornerRadius = 10
        if #available(macOS 10.15, *) {
            self.layer?.cornerCurve = .continuous
        }
        self.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        self.layer?.masksToBounds = true
        self.autoresizesSubviews = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateActiveWebView(_ newWebView: WKWebView) {
        newWebView.underPageBackgroundColor = NSColor.windowBackgroundColor
        newWebView.wantsLayer = true
        newWebView.layer?.cornerRadius = 10
        if #available(macOS 10.15, *) {
            newWebView.layer?.cornerCurve = .continuous
        }
        newWebView.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        newWebView.layer?.masksToBounds = true
        newWebView.autoresizingMask = [.width, .height]

        let isTabSwitch = newWebView !== currentWebView

        if isTabSwitch {
            for subview in subviews {
                subview.isHidden = true
            }
            if newWebView.superview != self {
                addSubview(newWebView)
            } else {
                addSubview(newWebView, positioned: .above, relativeTo: nil)
            }
            newWebView.isHidden = false
            currentWebView = newWebView

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
            newWebView.isHidden = false
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
        for subview in subviews {
            if subview.frame != bounds {
                subview.frame = bounds
                subview.needsLayout = true
            }
        }
    }
}
