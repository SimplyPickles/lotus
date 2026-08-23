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

    func makeNSView(context: Context) -> WebTabHostNSView {
        let hostView = WebTabHostNSView()
        if !isInternalLotusPage {
            hostView.updateActiveWebView(browserState.getWebView(for: activeTabId))
        }
        return hostView
    }

    func updateNSView(_ nsView: WebTabHostNSView, context: Context) {
        if !isInternalLotusPage {
            nsView.updateActiveWebView(browserState.getWebView(for: activeTabId))
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
        self.layer?.cornerRadius = 0
        self.layer?.maskedCorners = []
        self.layer?.masksToBounds = false
        self.autoresizesSubviews = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateActiveWebView(_ newWebView: WKWebView) {
        newWebView.underPageBackgroundColor = NSColor.windowBackgroundColor
        newWebView.wantsLayer = true
        newWebView.layer?.cornerRadius = 0
        newWebView.layer?.maskedCorners = []
        newWebView.layer?.masksToBounds = false

        clearCornerRadii(in: newWebView)
        newWebView.autoresizingMask = [.width, .height]

        let isTabSwitch = newWebView !== currentWebView

        if isTabSwitch {
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
                    subview.isHidden = true
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
