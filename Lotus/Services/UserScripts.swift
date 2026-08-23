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

    static let inputFocusHandlerName = "lotusInputFocusHandler"
    static let contextMenuHandlerName = "lotusContextMenuHandler"

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
                if (el.getAttribute && (el.getAttribute('contenteditable') === 'true' || el.getAttribute('contenteditable') === '')) return true;
                if (el.closest && el.closest('[contenteditable="true"], [contenteditable=""], [role="textbox"], [role="searchbox"], [role="combobox"]')) return true;
                var tag = el.tagName ? el.tagName.toUpperCase() : '';
                if (tag === 'INPUT') {
                    var type = el.type ? el.type.toLowerCase() : 'text';
                    var nonTextTypes = ['button', 'checkbox', 'color', 'file', 'hidden', 'image', 'radio', 'range', 'reset', 'submit'];
                    return nonTextTypes.indexOf(type) === -1;
                }
                return tag === 'TEXTAREA' || tag === 'SELECT';
            } catch(e) { return false; }
        }
        function getDeepActiveElement() {
            try {
                var el = document.activeElement;
                while (el && el.shadowRoot && el.shadowRoot.activeElement) {
                    el = el.shadowRoot.activeElement;
                }
                return el;
            } catch(e) { return null; }
        }
        window.__lotusCheckInputFocus = function() {
            try {
                var el = getDeepActiveElement();
                var focused = isEditable(el);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                    window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: focused });
                }
            } catch(e) {}
        };
        document.addEventListener('focusin', function(e) {
            try {
                if (isEditable(e.target) || isEditable(getDeepActiveElement())) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                        window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: true });
                    }
                }
            } catch(e) {}
        }, true);
        document.addEventListener('focusout', function(e) {
            try {
                setTimeout(function() {
                    window.__lotusCheckInputFocus();
                }, 10);
            } catch(e) {}
        }, true);
        document.addEventListener('selectionchange', function(e) {
            try {
                var el = getDeepActiveElement();
                if (isEditable(el)) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                        window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: true });
                    }
                }
            } catch(e) {}
        }, true);
    })();
    """

    /// Tracks right-clicked images, links, and media to provide accurate target URLs
    /// for Lotus's download actions.
    static let contextMenuMonitor = """
    (function() {
        function getCleanURL(url) {
            if (!url) return null;
            try {
                return new URL(url, document.baseURI).href;
            } catch(e) {
                return url;
            }
        }

        document.addEventListener('contextmenu', function(e) {
            try {
                var target = e.target;
                var imgURL = null;
                var linkURL = null;

                if (target) {
                    if (target.tagName === 'IMG') {
                        imgURL = target.currentSrc || target.src;
                    } else if (target.tagName === 'VIDEO') {
                        imgURL = target.currentSrc || target.src;
                    }

                    if (!imgURL) {
                        var img = target.closest('img');
                        if (img) imgURL = img.currentSrc || img.src;
                    }

                    if (!imgURL) {
                        var bg = window.getComputedStyle(target).backgroundImage;
                        if (bg && bg.indexOf('url(') === 0) {
                            var match = bg.match(/url\\(["']?(.*?)["']?\\)/);
                            if (match && match[1]) imgURL = match[1];
                        }
                    }

                    var a = target.tagName === 'A' ? target : target.closest('a');
                    if (a && a.href) {
                        linkURL = a.href;
                    }
                }

                imgURL = getCleanURL(imgURL);
                linkURL = getCleanURL(linkURL);

                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusContextMenuHandler) {
                    window.webkit.messageHandlers.lotusContextMenuHandler.postMessage({
                        imageURL: imgURL,
                        linkURL: linkURL
                    });
                }
            } catch(err) {}
        }, true);
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

    // MARK: - Picture in Picture

    /// Returns 'pip' if a video is already in PiP, 'playing' if a candidate
    /// video is actively playing, else 'none'.
    static let pictureInPictureStatus = """
    (function() {
        var videos = Array.prototype.slice.call(document.querySelectorAll('video'));
        for (var i = 0; i < videos.length; i++) {
            try {
                if (videos[i].webkitPresentationMode === 'picture-in-picture') return 'pip';
            } catch (e) {}
        }
        if (document.pictureInPictureElement) return 'pip';
        var playing = videos.some(function(v) {
            return !v.paused && !v.ended && v.readyState > 2 && v.videoWidth > 0;
        });
        return playing ? 'playing' : 'none';
    })();
    """

    /// Puts the best video into native Picture in Picture via WebKit's
    /// presentation-mode API (Safari's own mechanism), falling back to the
    /// standard web PiP API. Prefers the largest actively-playing video but
    /// accepts the largest loaded (paused) one, so the manual menu action
    /// also works on paused players. Returns 'ok' on success.
    static let enterPictureInPicture = """
    (function() {
        var videos = Array.prototype.slice.call(document.querySelectorAll('video'));
        var bySize = function(a, b) {
            return (b.videoWidth * b.videoHeight) - (a.videoWidth * a.videoHeight);
        };
        var candidate = videos.filter(function(v) {
            return !v.paused && !v.ended && v.readyState > 2 && v.videoWidth > 0;
        }).sort(bySize)[0];
        if (!candidate) {
            candidate = videos.filter(function(v) {
                return v.readyState > 0 && v.videoWidth > 0;
            }).sort(bySize)[0];
        }
        if (!candidate) return 'no-playing-video';
        try {
            if (candidate.webkitSupportsPresentationMode &&
                candidate.webkitSupportsPresentationMode('picture-in-picture')) {
                if (candidate.webkitPresentationMode !== 'picture-in-picture') {
                    candidate.webkitSetPresentationMode('picture-in-picture');
                }
                return 'ok';
            }
            if (candidate.requestPictureInPicture) {
                candidate.requestPictureInPicture();
                return 'ok';
            }
        } catch (e) {
            return 'error';
        }
        return 'unsupported';
    })();
    """

    /// Returns any Picture-in-Picture video back inline. Returns 'ok' if a
    /// video was restored.
    static let exitPictureInPicture = """
    (function() {
        var restored = false;
        var videos = Array.prototype.slice.call(document.querySelectorAll('video'));
        videos.forEach(function(v) {
            try {
                if (v.webkitPresentationMode === 'picture-in-picture') {
                    v.webkitSetPresentationMode('inline');
                    restored = true;
                }
            } catch (e) {}
        });
        if (!restored && document.pictureInPictureElement && document.exitPictureInPicture) {
            try { document.exitPictureInPicture(); restored = true; } catch (e) {}
        }
        return restored ? 'ok' : 'none';
    })();
    """

    // MARK: - Find on Page

    /// Clears any text selection and remaining DOM highlight ranges on the page.
    static let clearSelection = """
    (function() {
        try {
            if (window.getSelection) {
                var sel = window.getSelection();
                if (sel && sel.removeAllRanges) {
                    sel.removeAllRanges();
                }
            }
            if (document.selection && document.selection.empty) {
                document.selection.empty();
            }
        } catch(e) {}
    })();
    """

    /// Returns a script that counts all occurrences of a query string across
    /// visible text nodes in the DOM.
    static func countMatchesScript(for query: String, caseSensitive: Bool = false) -> String {
        let jsonQuery: String
        if let data = try? JSONSerialization.data(withJSONObject: [query]),
           let str = String(data: data, encoding: .utf8),
           str.hasPrefix("[") && str.hasSuffix("]") {
            jsonQuery = String(str.dropFirst().dropLast())
        } else {
            jsonQuery = "\"\""
        }

        return """
        (function() {
            var query = \(jsonQuery);
            if (!query || query.length === 0) return 0;
            try {
                var flags = \(caseSensitive ? "'g'" : "'gi'");
                var escaped = query.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
                var regex = new RegExp(escaped, flags);
                var walker = document.createTreeWalker(
                    document.body || document.documentElement,
                    NodeFilter.SHOW_TEXT,
                    {
                        acceptNode: function(node) {
                            if (!node.nodeValue || !node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
                            var parent = node.parentElement;
                            if (!parent) return NodeFilter.FILTER_REJECT;
                            var tag = parent.tagName ? parent.tagName.toUpperCase() : '';
                            if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT' || tag === 'TEXTAREA') {
                                return NodeFilter.FILTER_REJECT;
                            }
                            var style = window.getComputedStyle(parent);
                            if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
                                return NodeFilter.FILTER_REJECT;
                            }
                            return NodeFilter.FILTER_ACCEPT;
                        }
                    }
                );
                var count = 0;
                while (walker.nextNode()) {
                    var matches = walker.currentNode.nodeValue.match(regex);
                    if (matches) {
                        count += matches.length;
                    }
                }
                return count;
            } catch(e) {
                return 0;
            }
        })();
        """
    }
}
