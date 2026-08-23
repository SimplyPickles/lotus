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

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic

        webView.printOperation(with: printInfo).run()
    }
}
