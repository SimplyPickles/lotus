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

    // MARK: - Hardware & Media Permissions

    @available(macOS 12.0, *)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let host = origin.host.lowercased()
        let permType: SitePermissionType
        let typeName: String
        switch type {
        case .camera:
            permType = .camera
            typeName = "Camera"
        case .microphone:
            permType = .microphone
            typeName = "Microphone"
        case .cameraAndMicrophone:
            permType = .camera
            typeName = "Camera and Microphone"
        @unknown default:
            permType = .camera
            typeName = "Camera"
        }

        let savedState = SitePermissionStore.shared.state(for: host, type: permType)
        switch savedState {
        case .allow:
            decisionHandler(.grant)
        case .deny:
            decisionHandler(.deny)
        case .prompt:
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "“\(host)” Would Like to Access Your \(typeName)"
                alert.informativeText = "You can manage site permissions anytime from the security lock in the address bar."
                alert.addButton(withTitle: "Allow")
                alert.addButton(withTitle: "Don’t Allow")
                if let window = webView.window ?? NSApp.keyWindow {
                    alert.beginSheetModal(for: window) { response in
                        let granted = response == .alertFirstButtonReturn
                        SitePermissionStore.shared.set(state: granted ? .allow : .deny, for: host, type: permType)
                        decisionHandler(granted ? .grant : .deny)
                    }
                } else {
                    let response = alert.runModal()
                    let granted = response == .alertFirstButtonReturn
                    SitePermissionStore.shared.set(state: granted ? .allow : .deny, for: host, type: permType)
                    decisionHandler(granted ? .grant : .deny)
                }
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        requestGeolocationPermissionForOrigin origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let host = origin.host.lowercased()
        let savedState = SitePermissionStore.shared.state(for: host, type: .geolocation)
        switch savedState {
        case .allow:
            decisionHandler(.grant)
        case .deny:
            decisionHandler(.deny)
        case .prompt:
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "“\(host)” Would Like to Use Your Location"
                alert.informativeText = "You can manage site permissions anytime from the security lock in the address bar."
                alert.addButton(withTitle: "Allow")
                alert.addButton(withTitle: "Don’t Allow")
                if let window = webView.window ?? NSApp.keyWindow {
                    alert.beginSheetModal(for: window) { response in
                        let granted = response == .alertFirstButtonReturn
                        SitePermissionStore.shared.set(state: granted ? .allow : .deny, for: host, type: .geolocation)
                        decisionHandler(granted ? .grant : .deny)
                    }
                } else {
                    let response = alert.runModal()
                    let granted = response == .alertFirstButtonReturn
                    SitePermissionStore.shared.set(state: granted ? .allow : .deny, for: host, type: .geolocation)
                    decisionHandler(granted ? .grant : .deny)
                }
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

            self.lastContextMenuSelectedText = body["selectedText"] as? String
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

        if message.name == UserScripts.notificationHandlerName,
           let body = message.body as? [String: Any],
           let callbackId = body["callbackId"] as? String {
            let host = (body["host"] as? String) ?? message.webView?.url?.host ?? "This site"
            let webView = message.webView
            let savedState = SitePermissionStore.shared.state(for: host, type: .notifications)

            func resolveWith(status: String) {
                let safeCallbackId = callbackId.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
                guard !safeCallbackId.isEmpty else { return }
                let safeStatus = (status == "granted" || status == "denied") ? status : "default"
                guard let jsonIdData = try? JSONEncoder().encode(safeCallbackId),
                      let jsonId = String(data: jsonIdData, encoding: .utf8),
                      let jsonStatusData = try? JSONEncoder().encode(safeStatus),
                      let jsonStatus = String(data: jsonStatusData, encoding: .utf8) else {
                    return
                }
                let js = "if (window._lotusNotifCallbacks && window._lotusNotifCallbacks[\(jsonId)]) { window._lotusNotifCallbacks[\(jsonId)](\(jsonStatus)); delete window._lotusNotifCallbacks[\(jsonId)]; }"
                DispatchQueue.main.async {
                    webView?.evaluateJavaScript(js, completionHandler: nil)
                }
            }

            switch savedState {
            case .allow:
                resolveWith(status: "granted")
            case .deny:
                resolveWith(status: "denied")
            case .prompt:
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "“\(host)” Would Like to Send You Notifications"
                    alert.informativeText = "Notifications may include alerts, sounds, and icon badges."
                    alert.addButton(withTitle: "Allow")
                    alert.addButton(withTitle: "Don’t Allow")
                    if let window = webView?.window ?? NSApp.keyWindow {
                        alert.beginSheetModal(for: window) { response in
                            let granted = response == .alertFirstButtonReturn
                            SitePermissionStore.shared.set(state: granted ? .allow : .deny, for: host, type: .notifications)
                            resolveWith(status: granted ? "granted" : "denied")
                        }
                    } else {
                        let response = alert.runModal()
                        let granted = response == .alertFirstButtonReturn
                        SitePermissionStore.shared.set(state: granted ? .allow : .deny, for: host, type: .notifications)
                        resolveWith(status: granted ? "granted" : "denied")
                    }
                }
            }
            return
        }

        if message.name == UserScripts.mediaHandlerName,
           let body = message.body as? [String: Any],
           let tabId = webViewStore.first(where: { $0.value === message.webView })?.key {
            let isPlaying = (body["isPlaying"] as? Bool) ?? false
            let isMuted = (body["isMuted"] as? Bool) ?? false
            let hasAudio = (body["hasAudio"] as? Bool) ?? false
            let hasVideo = (body["hasVideo"] as? Bool) ?? false
            let title = body["title"] as? String
            updateMediaState(for: tabId, isPlaying: isPlaying, isMuted: isMuted, hasAudio: hasAudio, hasVideo: hasVideo, mediaTitle: title)
            return
        }

        if message.name == UserScripts.openSearchHandlerName,
           let body = message.body as? [String: Any],
           let title = body["title"] as? String,
           let href = body["href"] as? String,
           let origin = body["origin"] as? String,
           let host = body["host"] as? String,
           let tabId = webViewStore.first(where: { $0.value === message.webView })?.key {
            registerOpenSearchDescriptor(for: tabId, title: title, href: href, origin: origin, host: host)
            return
        }

        if message.name == UserScripts.zapHandlerName,
           let body = message.body as? [String: Any],
           let action = body["action"] as? String,
           let tabId = webViewStore.first(where: { $0.value === message.webView })?.key {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if action == "zap",
                   let selector = body["selector"] as? String,
                   let domain = body["domain"] as? String {
                    let summary = (body["summary"] as? String) ?? selector
                    self.handleZapEvent(domain: domain, selector: selector, summary: summary, tabId: tabId)
                } else if action == "cancel" {
                    self.stopZapMode(for: tabId)
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
