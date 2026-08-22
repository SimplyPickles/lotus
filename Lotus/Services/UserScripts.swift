//
//  UserScripts.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation

/// JavaScript sources injected into web content or evaluated on demand.
///
/// Keeping every script in one place makes the app's JS footprint auditable
/// and keeps large string literals out of state/controller code.
enum UserScripts {

    // MARK: - Message Handler Names

    static let credentialHandlerName = "lotusCredentialHandler"
    static let inputFocusHandlerName = "lotusInputFocusHandler"

    // MARK: - Injected at Document Start

    /// Tracks whether an editable element (input/textarea/contenteditable) is
    /// focused inside the page and reports changes to the app, so keyboard
    /// shortcuts can avoid stealing keystrokes from web forms.
    static let inputFocusMonitor = """
    (function() {
        function isEditable(el) {
            try {
                if (!el) return false;
                if (el.isContentEditable) return true;
                var tag = el.tagName ? el.tagName.toUpperCase() : '';
                return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT';
            } catch(e) { return false; }
        }
        window.__lotusCheckInputFocus = function() {
            try {
                var el = document.activeElement;
                var focused = isEditable(el);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                    window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: focused });
                }
            } catch(e) {}
        };
        document.addEventListener('focusin', function(e) {
            try {
                if (isEditable(e.target)) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                        window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: true });
                    }
                }
            } catch(e) {}
        }, true);
        document.addEventListener('focusout', function(e) {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                    window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: false });
                }
            } catch(e) {}
        }, true);
    })();
    """

    // MARK: - Injected at Document End

    /// Watches password fields and form submissions to drive keychain
    /// autofill and save prompts.
    static let credentialCapture = """
    (function() {
        function setupFormListeners() {
            try {
                document.addEventListener('focusin', function(e) {
                    try {
                        var target = e.target;
                        if (target && target.tagName === 'INPUT' && (target.type === 'password' || target.autocomplete === 'current-password')) {
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusCredentialHandler) {
                                window.webkit.messageHandlers.lotusCredentialHandler.postMessage({
                                    event: 'focus',
                                    server: window.location.hostname || ''
                                });
                            }
                        }
                    } catch(e) {}
                }, true);

                document.addEventListener('submit', function(e) {
                    try {
                        var form = e.target;
                        if (!form) return;
                        var passwordInput = form.querySelector('input[type="password"]');
                        if (!passwordInput || !passwordInput.value) return;

                        var userInput = form.querySelector('input[type="text"], input[type="email"], input[name*="user"], input[name*="login"], input[name*="email"], input[autocomplete="username"]');
                        var username = userInput ? userInput.value : '';

                        if (username && passwordInput.value) {
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusCredentialHandler) {
                                window.webkit.messageHandlers.lotusCredentialHandler.postMessage({
                                    event: 'submit',
                                    username: username,
                                    password: passwordInput.value,
                                    server: window.location.hostname || ''
                                });
                            }
                        }
                    } catch(e) {}
                }, true);
            } catch(e) {}
        }

        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', setupFormListeners);
        } else {
            setupFormListeners();
        }
    })();
    """

    // MARK: - Evaluated On Demand

    /// Stops and detaches all media elements before a tab's webview is torn down.
    static let pauseAllMedia = """
    (function() {
        var media = document.querySelectorAll('audio, video');
        media.forEach(function(m) {
            try { m.pause(); m.src = ''; } catch(e){}
        });
        if (window.AudioContext || window.webkitAudioContext) {
            try { (window.AudioContext || window.webkitAudioContext).close(); } catch(e){}
        }
    })();
    """

    /// Returns the page's effective theme color (meta tag, body, or root background).
    static let themeColorProbe = """
    (function() {
        var meta = document.querySelector('meta[name="theme-color"]');
        if (meta && meta.content) return meta.content;
        var bodyStyle = window.getComputedStyle(document.body);
        var bg = bodyStyle.backgroundColor;
        if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') return bg;
        var docStyle = window.getComputedStyle(document.documentElement);
        var docBg = docStyle.backgroundColor;
        if (docBg && docBg !== 'rgba(0, 0, 0, 0)' && docBg !== 'transparent') return docBg;
        return null;
    })()
    """

    /// Re-reports the page's current input-focus state (see `inputFocusMonitor`).
    static let checkInputFocus = "window.__lotusCheckInputFocus ? window.__lotusCheckInputFocus() : void 0;"
}
