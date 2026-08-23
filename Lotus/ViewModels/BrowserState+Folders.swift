//
//  BrowserState+Folders.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

extension BrowserState {

    // MARK: - Folder Accessors

    func folder(for id: UUID) -> TabFolder? {
        folders.first(where: { $0.id == id })
    }

    /// Unpinned member tabs of a folder, in sidebar order.
    func folderTabs(_ folderId: UUID) -> [TabItem] {
        unpinnedTabs.filter { $0.folderId == folderId }
    }

    // MARK: - Folder CRUD

    /// Returns the next default folder color by cycling through the palette.
    func nextFolderColor() -> FolderColor {
        let palette = FolderColor.allCases
        let index = folders.count % palette.count
        return palette[index]
    }

    /// Creates a folder containing the given tabs (and their split partners, if
    /// any) and returns it so callers can start inline rename.
    @discardableResult
    func createFolder(named name: String = "New Folder", with tabIds: [UUID], color: FolderColor? = nil) -> TabFolder {
        let assignedColor = color ?? nextFolderColor()
        let newFolder = TabFolder(name: name, color: assignedColor)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            folders.append(newFolder)
            moveTabs(tabIds, toFolder: newFolder.id)
        }
        return newFolder
    }

    @discardableResult
    func createFolder(named name: String = "New Folder", with tabId: UUID, color: FolderColor? = nil) -> TabFolder {
        createFolder(named: name, with: [tabId], color: color)
    }

    func setFolderColor(id: UUID, to color: FolderColor) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            folders[index].color = color
        }
    }

    func renameFolder(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = trimmed
    }

    func toggleFolderCollapsed(id: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            folders[index].isCollapsed.toggle()
            normalizeSidebarSelection()
        }
    }

    /// Expands a folder if collapsed (no-op otherwise). Callers wrap in
    /// their own animation.
    func expandFolder(id: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == id }), folders[index].isCollapsed else { return }
        folders[index].isCollapsed = false
    }

    func expandFolderIfNeeded(containing tabId: UUID) {
        guard let folderId = tab(for: tabId)?.folderId,
              let index = folders.firstIndex(where: { $0.id == folderId }),
              folders[index].isCollapsed else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            folders[index].isCollapsed = false
        }
    }

    /// Removes folder metadata that no longer has any member tabs.
    func removeEmptyFolders() {
        let memberFolderIds = Set(tabs.compactMap(\.folderId))
        folders.removeAll { !memberFolderIds.contains($0.id) }
    }

    /// Initiates closing a folder. If the folder has tabs, displays the
    /// confirmation dialog; if empty, deletes the folder immediately.
    func requestCloseFolder(id: UUID) {
        let tabs = folderTabs(id)
        if tabs.isEmpty {
            deleteFolder(id: id)
            return
        }
        withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
            folderToCloseConfirmation = id
        }
    }

    func cancelCloseFolder() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.86)) {
            folderToCloseConfirmation = nil
        }
    }

    func confirmCloseFolder(id: UUID, keepTabs: Bool = false) {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.86)) {
            if keepTabs {
                deleteFolder(id: id)
            } else {
                closeAllTabs(inFolder: id)
            }
            folderToCloseConfirmation = nil
        }
    }

    /// Deletes the folder but keeps its tabs, which become loose (ungrouped)
    /// in place.
    func deleteFolder(id: UUID) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            for index in tabs.indices where tabs[index].folderId == id {
                tabs[index].folderId = nil
            }
            folders.removeAll(where: { $0.id == id })
        }
    }

    /// Closes every tab in the folder and automatically deletes the empty folder.
    func closeAllTabs(inFolder id: UUID) {
        let memberIds = folderTabs(id).map { $0.id }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            for tabId in memberIds {
                removeTab(id: tabId)
            }
            folders.removeAll(where: { $0.id == id })
        }
    }

    // MARK: - Membership
 
    /// Moves a tab into a folder (or out, when `folderId` is nil), keeping
    /// folder members contiguous in the tabs array. Split partners move
    /// together so split rows stay inside a single folder, and pinned tabs
    /// are unpinned first (folders cannot be pinned).
    func moveTab(_ tabId: UUID, toFolder folderId: UUID?) {
        moveTabs([tabId], toFolder: folderId)
    }

    /// Moves multiple tabs into a folder (or out, when `folderId` is nil), keeping
    /// folder members contiguous in the tabs array. Split partners move
    /// together so split rows stay inside a single folder, and pinned tabs
    /// are unpinned first (folders cannot be pinned).
    func moveTabs(_ tabIds: [UUID], toFolder folderId: UUID?) {
        guard !tabIds.isEmpty else { return }
        if let folderId, folder(for: folderId) == nil { return }

        // A split pair always moves as a unit.
        var allMovedIds: [UUID] = []
        var seenIds = Set<UUID>()
        for tabId in tabIds {
            let pair = splitGroup(containing: tabId) ?? [tabId]
            for id in pair {
                if seenIds.insert(id).inserted && tab(for: id) != nil {
                    allMovedIds.append(id)
                }
            }
        }
        guard !allMovedIds.isEmpty else { return }

        var newTabs = tabs
        var moved: [TabItem] = []
        var originalFirstIndex: Int? = nil

        for id in allMovedIds {
            if let index = newTabs.firstIndex(where: { $0.id == id }) {
                if originalFirstIndex == nil {
                    originalFirstIndex = index
                }
                var movedTab = newTabs.remove(at: index)
                movedTab.folderId = folderId
                movedTab.isPinned = false
                moved.append(movedTab)
            }
        }
        guard !moved.isEmpty else { return }

        if let folderId, let lastMember = newTabs.lastIndex(where: { $0.folderId == folderId }) {
            newTabs.insert(contentsOf: moved, at: lastMember + 1)
        } else if let insertPos = originalFirstIndex, insertPos <= newTabs.count {
            // New folder or moving in place: preserve original location in tabstrip
            newTabs.insert(contentsOf: moved, at: insertPos)
        } else {
            // Empty folder or ungrouping: append to the end of the list.
            newTabs.append(contentsOf: moved)
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            tabs = newTabs
            removeEmptyFolders()
            if let folderId {
                expandFolder(id: folderId)
            }
        }
    }
}
