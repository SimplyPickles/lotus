//
//  BrowserState+Printing.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import AppKit
import WebKit

extension BrowserState {

    /// Opens the native macOS print panel for a web page.
    func printPage(for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        guard url(for: id)?.isLotusPage != true,
              let webView = webViewStore[id] else { return }

        let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic

        let printOp = webView.printOperation(with: printInfo)
        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true

        if let window = webView.window ?? NSApp.keyWindow {
            printOp.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            printOp.run()
        }
    }
}
