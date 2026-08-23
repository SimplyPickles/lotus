//
//  WebViewFactory.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import AppKit
import WebKit

/// The single place where WKWebViews and their configurations are built,
/// so tab webviews and WebKit-supplied popup webviews share identical setup.
enum WebViewFactory {

    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    /// Preferences applied to every configuration, including configurations
    /// handed to us by WebKit for popups (`createWebViewWith`).
    static func applySharedPreferences(to configuration: WKWebViewConfiguration) {
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.isElementFullscreenEnabled = true
        // WebKit's video presentation-mode API (native Picture in Picture)
        // is gated behind this preference; Safari enables it for itself but
        // bare WKWebViews may not get it — leaving
        // `webkitSupportsPresentationMode('picture-in-picture')` false so
        // PiP silently no-ops. The setter is private but long-established;
        // KVC resolves either `set…:` or `_set…:`, and the responds-checks
        // avoid an undefined-key exception on WebKit builds lacking both.
        let prefs = configuration.preferences
        if prefs.responds(to: NSSelectorFromString("setAllowsPictureInPictureMediaPlayback:"))
            || prefs.responds(to: NSSelectorFromString("_setAllowsPictureInPictureMediaPlayback:")) {
            prefs.setValue(true, forKey: "allowsPictureInPictureMediaPlayback")
        }
    }

    /// Builds the full configuration for a new tab's webview, wiring the
    /// Lotus script message handlers and user scripts.
    static func makeConfiguration(messageHandler: WKScriptMessageHandler) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        applySharedPreferences(to: config)
        config.websiteDataStore = WKWebsiteDataStore.default()
        // Internal pages load through the lotus:// scheme handler so they
        // participate in the webview's back-forward list.
        config.setURLSchemeHandler(LotusSchemeHandler(), forURLScheme: LotusSchemeHandler.scheme)
        config.userContentController.add(messageHandler, name: UserScripts.inputFocusHandlerName)
        config.userContentController.add(messageHandler, name: UserScripts.contextMenuHandlerName)
        config.userContentController.addUserScript(
            WKUserScript(source: UserScripts.inputFocusMonitor, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        config.userContentController.addUserScript(
            WKUserScript(source: UserScripts.contextMenuMonitor, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        return config
    }

    /// Creates a webview with Lotus's standard settings and delegate wiring.
    static func makeWebView(configuration: WKWebViewConfiguration, delegate: WKNavigationDelegate & WKUIDelegate) -> WKWebView {
        let webView = LotusWebView(frame: .zero, configuration: configuration)
        webView.browserState = delegate as? BrowserState
        webView.customUserAgent = userAgent
        webView.navigationDelegate = delegate
        webView.uiDelegate = delegate
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = NSColor.windowBackgroundColor
        webView.wantsLayer = true
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        return webView
    }
}
