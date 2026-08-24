//
//  FolderContextMenu.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import AppKit

/// Header with folder name and tab count hosted inside a native macOS context menu.
struct FolderContextMenuHeaderView: View {
    let folder: TabFolder
    let tabCount: Int
    let onSelectColor: (FolderColor) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(folder.color.color)

                Text(folder.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(tabCount) \(tabCount == 1 ? "tab" : "tabs")")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 7)

            FolderColorSwatchPicker(folder: folder, onSelectColor: onSelectColor)
        }
        .focusable(false)
        .focusEffectDisabled()
    }
}

struct FolderColorSwatchPicker: View {
    let folder: TabFolder
    let onSelectColor: (FolderColor) -> Void

    @State private var hoveredColor: FolderColor? = nil

    var body: some View {
        HStack(spacing: 3) {
            ForEach(FolderColor.allCases) { color in
                let isSelected = color == folder.color
                let isHovered = color == hoveredColor

                ZStack {
                    if isSelected {
                        Circle()
                            .stroke(color.color, lineWidth: 1.75)
                            .frame(width: 20, height: 20)

                        Circle()
                            .fill(color.color)
                            .frame(width: 13, height: 13)
                    } else {
                        if isHovered {
                            Circle()
                                .stroke(color.color.opacity(0.45), lineWidth: 1.25)
                                .frame(width: 20, height: 20)
                        }

                        Circle()
                            .fill(color.color)
                            .frame(width: 15, height: 15)
                    }
                }
                .frame(width: 20, height: 20)
                .contentShape(Circle())
                .onTapGesture {
                    onSelectColor(color)
                }
                .onHover { hovering in
                    hoveredColor = hovering ? color : (hoveredColor == color ? nil : hoveredColor)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .focusable(false)
        .focusEffectDisabled()
    }
}

/// Custom hosting view that suppresses focus rings inside menus.
final class MenuPaletteHostingView<Content: View>: NSHostingView<Content> {
    override var acceptsFirstResponder: Bool { false }
    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }
}

/// AppKit hosting view for native folder context menus with embedded color swatches.
struct FolderContextMenuHost: NSViewRepresentable {
    let folder: TabFolder
    let browserState: BrowserState
    let onRename: () -> Void
    let onClose: () -> Void
    let onDelete: () -> Void

    func makeNSView(context: Context) -> FolderContextMenuNSView {
        let view = FolderContextMenuNSView()
        view.folder = folder
        view.browserState = browserState
        view.onRename = onRename
        view.onClose = onClose
        view.onDelete = onDelete
        return view
    }

    func updateNSView(_ nsView: FolderContextMenuNSView, context: Context) {
        nsView.folder = folder
        nsView.browserState = browserState
        nsView.onRename = onRename
        nsView.onClose = onClose
        nsView.onDelete = onDelete
    }
}

final class FolderContextMenuNSView: NSView {
    var folder: TabFolder?
    var browserState: BrowserState?
    var onRename: (() -> Void)?
    var onClose: (() -> Void)?
    var onDelete: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only intercept right-clicks so left clicks (collapse/expand) and
        // DragGesture (reordering) pass straight through to SwiftUI.
        guard let currentEvent = NSApp.currentEvent,
              currentEvent.type == .rightMouseDown || currentEvent.type == .rightMouseUp else {
            return nil
        }
        return super.hitTest(point)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let folder = folder, let browserState = browserState else { return nil }
        return buildMenu(folder: folder, browserState: browserState)
    }

    private func buildMenu(folder: TabFolder, browserState: BrowserState) -> NSMenu {
        let menu = NSMenu()

        // 1. Folder title, tab count, and color swatches
        let tabCount = browserState.tabs.filter { $0.folderId == folder.id }.count
        let headerView = FolderContextMenuHeaderView(
            folder: folder,
            tabCount: tabCount,
            onSelectColor: { [weak menu] newColor in
                browserState.setFolderColor(id: folder.id, to: newColor)
                menu?.cancelTracking()
            }
        )
        let hostingView = MenuPaletteHostingView(rootView: headerView)
        hostingView.focusRingType = .none
        let fitting = hostingView.fittingSize
        hostingView.frame = NSRect(x: 0, y: 0, width: fitting.width, height: fitting.height)

        let headerItem = NSMenuItem()
        headerItem.view = hostingView
        menu.addItem(headerItem)

        // 2. Rename...
        let renameItem = NSMenuItem(title: "Rename...", action: #selector(handleRename), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Close All Tabs in Folder
        let closeItem = NSMenuItem(title: "Close All Tabs in Folder", action: #selector(handleClose), keyEquivalent: "")
        closeItem.target = self
        menu.addItem(closeItem)

        // 4. Delete Folder
        let deleteItem = NSMenuItem(title: "Ungroup Folder", action: #selector(handleDelete), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        return menu
    }

    @objc private func handleRename() {
        onRename?()
    }

    @objc private func handleClose() {
        onClose?()
    }

    @objc private func handleDelete() {
        onDelete?()
    }
}
