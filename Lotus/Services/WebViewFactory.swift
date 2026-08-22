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
    static func applySharedPreferences(to configuration: WKWebViewConfiguration, processPool: WKProcessPool) {
        configuration.processPool = processPool
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
    }

    /// Builds the full configuration for a new tab's webview, wiring the
    /// Lotus script message handlers and user scripts.
    static func makeConfiguration(processPool: WKProcessPool, messageHandler: WKScriptMessageHandler) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        applySharedPreferences(to: config, processPool: processPool)
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.userContentController.add(messageHandler, name: UserScripts.credentialHandlerName)
        config.userContentController.add(messageHandler, name: UserScripts.inputFocusHandlerName)
        config.userContentController.addUserScript(
            WKUserScript(source: UserScripts.inputFocusMonitor, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        config.userContentController.addUserScript(
            WKUserScript(source: UserScripts.credentialCapture, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        return config
    }

    /// Creates a webview with Lotus's standard settings and delegate wiring.
    static func makeWebView(configuration: WKWebViewConfiguration, delegate: WKNavigationDelegate & WKUIDelegate) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: configuration)
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
