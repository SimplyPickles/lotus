//
//  LotusWebView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import AppKit
import WebKit

/// Custom WKWebView subclass that intercepts context menu download actions
/// and routes them through Lotus's download manager.
final class LotusWebView: WKWebView {

    weak var browserState: BrowserState?

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        enhanceContextMenu(menu)
    }

    private func enhanceContextMenu(_ menu: NSMenu) {
        guard browserState != nil else { return }

        for item in menu.items {
            let title = item.title.lowercased()
            if title.contains("save image") || title.contains("download image") {
                let origTarget = item.target
                let origAction = item.action
                item.target = self
                item.action = #selector(handleDownloadImageItem(_:))
                item.representedObject = MenuItemForwarder(target: origTarget, action: origAction)
            } else if title.contains("download linked file") || title.contains("save link as") {
                let origTarget = item.target
                let origAction = item.action
                item.target = self
                item.action = #selector(handleDownloadLinkItem(_:))
                item.representedObject = MenuItemForwarder(target: origTarget, action: origAction)
            }
        }
    }

    @objc private func handleDownloadImageItem(_ sender: NSMenuItem) {
        if let imageURL = browserState?.lastContextMenuImageURL {
            browserState?.downloadURL(imageURL)
        } else if let forwarder = sender.representedObject as? MenuItemForwarder,
                  let target = forwarder.target as? NSObject,
                  let action = forwarder.action {
            _ = target.perform(action, with: sender)
        }
    }

    @objc private func handleDownloadLinkItem(_ sender: NSMenuItem) {
        if let linkURL = browserState?.lastContextMenuLinkURL {
            browserState?.downloadURL(linkURL)
        } else if let forwarder = sender.representedObject as? MenuItemForwarder,
                  let target = forwarder.target as? NSObject,
                  let action = forwarder.action {
            _ = target.perform(action, with: sender)
        }
    }
}

private final class MenuItemForwarder: NSObject {
    weak var target: AnyObject?
    let action: Selector?

    init(target: AnyObject?, action: Selector?) {
        self.target = target
        self.action = action
    }
}
