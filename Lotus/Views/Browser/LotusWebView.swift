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
        guard let browserState = browserState else { return }

        // 1. Link items
        if let linkURL = browserState.lastContextMenuLinkURL {
            let openNewTabItem = NSMenuItem(title: "Open Link in New Tab", action: #selector(handleOpenLinkInNewTab(_:)), keyEquivalent: "")
            openNewTabItem.target = self
            menu.insertItem(openNewTabItem, at: 0)

            let openSplitItem = NSMenuItem(title: "Open Link in Split View", action: #selector(handleOpenLinkInSplitView(_:)), keyEquivalent: "")
            openSplitItem.target = self
            menu.insertItem(openSplitItem, at: 1)

            let copyLinkItem = NSMenuItem(title: "Copy Link Address", action: #selector(handleCopyLinkAddress(_:)), keyEquivalent: "")
            copyLinkItem.target = self
            menu.insertItem(copyLinkItem, at: 2)

            menu.insertItem(.separator(), at: 3)
        }

        // 2. Text Selection items
        if let selectedText = browserState.lastContextMenuSelectedText, !selectedText.isEmpty {
            let engine = UserDefaults.standard.string(forKey: "lotus.browser.searchEngine") ?? "google"
            let engineName: String
            switch engine {
            case "duckduckgo": engineName = "DuckDuckGo"
            case "kagi": engineName = "Kagi"
            case "brave": engineName = "Brave"
            case "bing": engineName = "Bing"
            case "ecosia": engineName = "Ecosia"
            default: engineName = "Google"
            }

            let truncatedText = selectedText.count > 24 ? String(selectedText.prefix(24)) + "…" : selectedText
            let searchItem = NSMenuItem(title: "Search \(engineName) for “\(truncatedText)”", action: #selector(handleSearchSelection(_:)), keyEquivalent: "")
            searchItem.target = self
            menu.insertItem(searchItem, at: 0)
            menu.insertItem(.separator(), at: 1)
        }

        // 3. Image items
        if let imageURL = browserState.lastContextMenuImageURL {
            var downloadIndex = menu.indexOfItem(withTarget: self, andAction: #selector(handleDownloadImageItem(_:)))
            if downloadIndex == -1 {
                for (idx, item) in menu.items.enumerated() {
                    let title = item.title.lowercased()
                    if title.contains("image") {
                        downloadIndex = idx
                        break
                    }
                }
            }

            let copyImageAddressItem = NSMenuItem(title: "Copy Image Address", action: #selector(handleCopyImageAddress(_:)), keyEquivalent: "")
            copyImageAddressItem.target = self
            if downloadIndex >= 0 && downloadIndex < menu.items.count {
                menu.insertItem(copyImageAddressItem, at: downloadIndex + 1)
            } else {
                menu.addItem(copyImageAddressItem)
            }
        }

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

        let hasInspect = menu.items.contains { $0.title.lowercased().contains("inspect") }
        let hasViewSource = menu.items.contains { $0.title.lowercased().contains("source") }

        if !hasViewSource {
            menu.addItem(.separator())
            let sourceItem = NSMenuItem(title: "View Page Source", action: #selector(handleViewPageSource(_:)), keyEquivalent: "u")
            sourceItem.keyEquivalentModifierMask = [.command, .option]
            sourceItem.target = self
            menu.addItem(sourceItem)
        }

        if !hasInspect {
            let inspectItem = NSMenuItem(title: "Inspect Element", action: #selector(handleInspectElement(_:)), keyEquivalent: "i")
            inspectItem.keyEquivalentModifierMask = [.command, .option]
            inspectItem.target = self
            menu.addItem(inspectItem)
        }
    }

    @objc private func handleOpenLinkInNewTab(_ sender: NSMenuItem) {
        if let linkURL = browserState?.lastContextMenuLinkURL {
            browserState?.openTab(at: linkURL, title: linkURL.host ?? "New Tab")
        }
    }

    @objc private func handleOpenLinkInSplitView(_ sender: NSMenuItem) {
        if let linkURL = browserState?.lastContextMenuLinkURL,
           let currentTabId = browserState?.webViewStore.first(where: { $0.value === self })?.key {
            let newTab = browserState?.addTabBelow(currentTabId: currentTabId, title: linkURL.host ?? "New Tab", url: linkURL, select: false)
            if let newTabId = newTab?.id {
                browserState?.openInSplit(id: newTabId, side: .right)
            }
        }
    }

    @objc private func handleCopyLinkAddress(_ sender: NSMenuItem) {
        if let linkURL = browserState?.lastContextMenuLinkURL {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(linkURL.absoluteString, forType: .string)
        }
    }

    @objc private func handleCopyImageAddress(_ sender: NSMenuItem) {
        if let imageURL = browserState?.lastContextMenuImageURL {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(imageURL.absoluteString, forType: .string)
        }
    }

    @objc private func handleSearchSelection(_ sender: NSMenuItem) {
        if let text = browserState?.lastContextMenuSelectedText, !text.isEmpty {
            browserState?.openTab(with: text)
        }
    }

    @objc private func handleViewPageSource(_ sender: NSMenuItem) {
        if let tabId = browserState?.webViewStore.first(where: { $0.value === self })?.key {
            browserState?.viewPageSource(for: tabId)
        }
    }

    @objc private func handleInspectElement(_ sender: NSMenuItem) {
        if let tabId = browserState?.webViewStore.first(where: { $0.value === self })?.key {
            browserState?.inspectElement(for: tabId)
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
