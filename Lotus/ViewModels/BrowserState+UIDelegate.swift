//
//  BrowserState+UIDelegate.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import AppKit
import WebKit

extension BrowserState {

    // MARK: - WKUIDelegate JS Panels & File Open

    func webViewDidClose(_ webView: WKWebView) {
        if let tabId = webViewStore.first(where: { $0.value === webView })?.key {
            DispatchQueue.main.async { [weak self] in
                self?.removeTab(id: tabId)
            }
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = defaultText ?? ""
        alert.accessoryView = input
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn ? input.stringValue : nil)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
        openPanel.canChooseDirectories = parameters.allowsDirectories
        openPanel.canChooseFiles = true
        openPanel.begin { result in
            if result == .OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }

    // MARK: - Script Message Handling

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == UserScripts.inputFocusHandlerName,
           let body = message.body as? [String: Any],
           let isFocused = body["isFocused"] as? Bool {
            let isActive = message.webView === self.webViewStore[selectedTabId] || self.currentTabIds.contains { self.webViewStore[$0] === message.webView }
            if isActive {
                DispatchQueue.main.async { [weak self] in
                    self?.isWebInputFocused = isFocused
                }
            }
            return
        }

        if message.name == UserScripts.contextMenuHandlerName,
           let body = message.body as? [String: Any] {
            if let imageURLString = body["imageURL"] as? String, let url = URL(string: imageURLString) {
                self.lastContextMenuImageURL = url
            } else {
                self.lastContextMenuImageURL = nil
            }

            if let linkURLString = body["linkURL"] as? String, let url = URL(string: linkURLString) {
                self.lastContextMenuLinkURL = url
            } else {
                self.lastContextMenuLinkURL = nil
            }
            return
        }

        if message.name == UserScripts.shieldDeflectHandlerName {
            if let tabId = webViewStore.first(where: { $0.value === message.webView })?.key {
                DispatchQueue.main.async { [weak self] in
                    self?.triggerShieldDeflect(for: tabId)
                }
            }
            return
        }
    }

    func syncFocusStateForActiveTab() {
        guard let wv = webViewStore[selectedTabId] else {
            isWebInputFocused = false
            return
        }
        wv.evaluateJavaScript(UserScripts.checkInputFocus, in: nil, in: .defaultClient) { _ in }
    }
}
