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

    // MARK: - Script Message Handling & AutoFill

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == UserScripts.inputFocusHandlerName,
           let body = message.body as? [String: Any],
           let isFocused = body["isFocused"] as? Bool {
            if message.webView === self.webViewStore[selectedTabId] {
                DispatchQueue.main.async { [weak self] in
                    self?.isWebInputFocused = isFocused
                }
            }
            return
        }

        guard message.name == UserScripts.credentialHandlerName,
              let body = message.body as? [String: Any],
              message.webView === self.webViewStore[selectedTabId] else {
            return
        }

        let event = body["event"] as? String ?? "submit"
        let host = message.webView?.url?.host ?? body["server"] as? String ?? ""

        if event == "focus" {
            guard !host.isEmpty, let webView = message.webView else { return }
            let creds = keychainManager.fetchCredentials(for: host)
            if let first = creds.first {
                autoFillController.fillCredentials(in: webView, username: first.username, password: first.password)
            } else {
                autoFillController.performAutoFillRequest(for: webView)
            }
        } else if event == "submit" {
            guard let username = body["username"] as? String,
                  let password = body["password"] as? String,
                  !username.isEmpty, !password.isEmpty, !host.isEmpty else {
                return
            }

            let cred = KeychainCredential(server: host, username: username, password: password)
            DispatchQueue.main.async { [weak self] in
                self?.pendingSaveCredential = cred
                self?.keychainManager.saveCredential(server: host, username: username, password: password)
            }
        }
    }

    func triggerAutoFill(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        let webView = getWebView(for: targetId)
        autoFillController.performAutoFillRequest(for: webView)
    }

    func syncFocusStateForActiveTab() {
        guard let wv = webViewStore[selectedTabId] else {
            isWebInputFocused = false
            return
        }
        wv.evaluateJavaScript(UserScripts.checkInputFocus) { _, _ in }
    }
}
