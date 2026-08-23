//
//  LotusSchemeHandler.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import Foundation
import WebKit

/// Serves `lotus://` URLs inside WKWebView so internal pages become real
/// entries in the back-forward list (enabling ⌘[/⌘] and swipe gestures
/// between internal pages and web content).
///
/// The served document is intentionally blank — internal pages are rendered
/// as SwiftUI overlays while the webview sits at 0 opacity. Only the title
/// matters (it feeds the tab title / navigation entries).
final class LotusSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "lotus"

    private static func pageTitle(for url: URL) -> String {
        switch url.host {
        case "history": return "History"
        case "downloads": return "Downloads"
        case "settings": return "Settings"
        default: return "Lotus"
        }
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>\(Self.pageTitle(for: url))</title>
        <style>html, body { background: transparent; margin: 0; }</style>
        </head>
        <body></body>
        </html>
        """
        let data = Data(html.utf8)

        let response = URLResponse(
            url: url,
            mimeType: "text/html",
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Responses are delivered synchronously in `start`; nothing to cancel.
    }
}
