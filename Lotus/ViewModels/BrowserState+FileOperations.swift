//
//  BrowserState+FileOperations.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import AppKit
import WebKit
import UniformTypeIdentifiers

extension BrowserState {

    /// Opens a standard macOS Open Panel for the user to select a local HTML/PDF/image file to view.
    func openFilePrompt() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .html,
            .webArchive,
            .pdf,
            .image,
            .svg,
            .plainText,
            .json,
            .xml
        ]
        panel.prompt = "Open"
        panel.message = "Choose a file to open in Lotus"

        panel.begin { [weak self] result in
            guard result == .OK, let fileURL = panel.url, let self = self else { return }
            self.addTabBelow(
                title: fileURL.lastPathComponent,
                url: fileURL,
                select: true
            )
        }
    }

    /// Saves the current web page to disk as an HTML or WebArchive document.
    func savePageAs(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        guard let currentURL = url(for: targetId), !currentURL.isLotusPage,
              let webView = webViewStore[targetId] else { return }

        let panel = NSSavePanel()
        let pageTitle = tab(for: targetId)?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let baseName = pageTitle.isEmpty ? (currentURL.host ?? "Webpage") : pageTitle
        let cleanName = baseName.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "\(cleanName).html"
        panel.allowedContentTypes = [.html, .webArchive]
        panel.prompt = "Save"
        panel.message = "Save page to disk"

        panel.begin { result in
            guard result == .OK, let destination = panel.url else { return }
            webView.createWebArchiveData { archiveResult in
                if destination.pathExtension.lowercased() == "webarchive", case .success(let data) = archiveResult {
                    try? data.write(to: destination)
                } else {
                    webView.evaluateJavaScript("document.documentElement.outerHTML") { htmlResult, _ in
                        if let html = htmlResult as? String {
                            try? html.write(to: destination, atomically: true, encoding: .utf8)
                        }
                    }
                }
            }
        }
    }
}
