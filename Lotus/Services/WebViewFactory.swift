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

    static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
    static let chromeUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

    static var currentUserAgent: String {
        let mode = UserDefaults.standard.string(forKey: "lotus.browser.userAgentMode") ?? "safari"
        switch mode {
        case "chrome":
            return chromeUserAgent
        case "custom":
            let custom = UserDefaults.standard.string(forKey: "lotus.browser.customUserAgentString") ?? ""
            return custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? safariUserAgent : custom
        default:
            return safariUserAgent
        }
    }

    /// Shared WebKit process pool ensuring all tabs and popup webviews
    /// share identical network session state, WebAuthn sessions, and cookies.
    static let sharedProcessPool = WKProcessPool()

    /// Preferences applied to every configuration, including configurations
    /// handed to us by WebKit for popups (`createWebViewWith`).
    static func applySharedPreferences(to configuration: WKWebViewConfiguration) {
        configuration.processPool = sharedProcessPool
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.isElementFullscreenEnabled = true

        // Autoplay Policy
        let autoplayPolicy = UserDefaults.standard.string(forKey: "lotus.browser.autoplayPolicy") ?? "audio"
        switch autoplayPolicy {
        case "allowAll":
            configuration.mediaTypesRequiringUserActionForPlayback = []
        case "blockAll":
            configuration.mediaTypesRequiringUserActionForPlayback = .all
        default: // "audio" - block media that plays audio automatically
            configuration.mediaTypesRequiringUserActionForPlayback = .audio
        }

        // Enable WebAuthn / Passkeys / Cross-device verification features on WebKit configuration
        let configPrefs = configuration.preferences
        let webAuthnSelectors = [
            "setWebAuthenticationEnabled:",
            "_setWebAuthenticationEnabled:",
            "setWebAuthenticationModernEnabled:",
            "_setWebAuthenticationModernEnabled:",
            "setWebAuthenticationLocalAuthenticatorEnabled:",
            "_setWebAuthenticationLocalAuthenticatorEnabled:"
        ]
        for selStr in webAuthnSelectors {
            let sel = NSSelectorFromString(selStr)
            if configPrefs.responds(to: sel) {
                configPrefs.perform(sel, with: true as NSNumber)
            }
        }

        // WebKit's video presentation-mode API (native Picture in Picture)
        // is gated behind this preference; Safari enables it for itself but
        // bare WKWebViews may not get it — leaving
        // `webkitSupportsPresentationMode('picture-in-picture')` false so
        // PiP silently no-ops. The setter is private; try both the plain and
        // underscored Objective-C spellings via perform, then fall back to
        // KVC. A failure is logged in debug instead of silently skipped.
        let prefs = configuration.preferences
        if prefs.responds(to: NSSelectorFromString("setAllowsPictureInPictureMediaPlayback:"))
            || prefs.responds(to: NSSelectorFromString("_setAllowsPictureInPictureMediaPlayback:")) {
            prefs.setValue(true, forKey: "allowsPictureInPictureMediaPlayback")
        }
    }

    /// Builds the full configuration for a new tab's webview.
    static func makeConfiguration(messageHandler: WKScriptMessageHandler) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.processPool = sharedProcessPool
        config.websiteDataStore = WKWebsiteDataStore.default()
        configure(config, messageHandler: messageHandler)
        return config
    }

    /// Applies Lotus behavior to a newly-created configuration before it is
    /// used to construct a webview.
    static func configure(_ configuration: WKWebViewConfiguration, messageHandler: WKScriptMessageHandler) {
        applySharedPreferences(to: configuration)
        // Internal pages load through the lotus:// scheme handler so they
        // participate in the webview's back-forward list.
        configuration.setURLSchemeHandler(LotusSchemeHandler(), forURLScheme: LotusSchemeHandler.scheme)

        let weakMessageHandler = WeakScriptMessageHandler(target: messageHandler)
        configuration.userContentController.add(
            weakMessageHandler,
            contentWorld: .defaultClient,
            name: UserScripts.inputFocusHandlerName
        )
        configuration.userContentController.add(
            weakMessageHandler,
            contentWorld: .defaultClient,
            name: UserScripts.contextMenuHandlerName
        )
        configuration.userContentController.add(
            weakMessageHandler,
            contentWorld: .page,
            name: UserScripts.shieldDeflectHandlerName
        )
        configuration.userContentController.add(
            weakMessageHandler,
            contentWorld: .defaultClient,
            name: UserScripts.shieldDeflectHandlerName
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: UserScripts.inputFocusMonitor,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .defaultClient
            )
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: UserScripts.contextMenuMonitor,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .defaultClient
            )
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: UserScripts.contentBlockerScriptlet,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .defaultClient
            )
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: UserScripts.globalPrivacyControlScriptlet,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .page
            )
        )
        let fpScript = UserScripts.antiFingerprintingScript(
            disabledDomains: ContentBlockerService.shared.fingerprintDisabledDomains,
            strictCanvasBlock: ContentBlockerService.shared.strictCanvasBlockEnabled
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: fpScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .page
            )
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: UserScripts.youtubeAdBlockScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .page
            )
        )

        // Apply Shields content blocking rules
        ContentBlockerService.shared.apply(to: configuration)
    }

    /// Normalizes a configuration supplied to `WKUIDelegate`. WebKit documents
    /// this as a copy of the source webview's configuration, so its scheme
    /// handler, scripts, and message handlers are already present. Re-adding
    /// them would attempt duplicate registration and can raise an exception.
    static func configurePopup(_ configuration: WKWebViewConfiguration) {
        applySharedPreferences(to: configuration)
    }

    /// Creates a webview with Lotus's standard settings and delegate wiring.
    static func makeWebView(configuration: WKWebViewConfiguration, delegate: WKNavigationDelegate & WKUIDelegate) -> WKWebView {
        let webView = LotusWebView(frame: .zero, configuration: configuration)
        webView.browserState = delegate as? BrowserState
        webView.customUserAgent = currentUserAgent
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

/// WKUserContentController retains its script message handlers. Holding the
/// BrowserState directly would create a cycle through its WKWebView store.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: (any WKScriptMessageHandler)?

    init(target: any WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
