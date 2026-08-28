//
//  BrowserState+Folders.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct AutomaticFolderNameInput: Equatable, Sendable {
    let memberIDs: [UUID]
    let titles: [String]
}

extension BrowserState {

    // MARK: - Auto-Archive Inactive Tabs

    static let autoArchiveIntervalKey = "lotus.browser.autoArchiveInterval"

    /// Returns the active auto-archive duration threshold in seconds (or nil if set to "never").
    var autoArchiveIntervalSeconds: TimeInterval? {
        let interval = UserDefaults.standard.string(forKey: Self.autoArchiveIntervalKey) ?? "never"
        switch interval {
        case "6h":
            return 6 * 3600
        case "12h":
            return 12 * 3600
        case "24h":
            return 24 * 3600
        case "7d":
            return 7 * 24 * 3600
        default:
            return nil
        }
    }

    /// Retrieves or lazily creates the persistent Archive folder at the bottom of the tab list.
    @discardableResult
    func getOrCreateArchiveFolder(for profileId: UUID? = nil) -> TabFolder {
        let profId = profileId ?? currentProfileId
        if let existing = folders.first(where: { $0.isArchive && ($0.profileId ?? defaultProfileId) == profId }) {
            return existing
        }
        let archiveFolder = TabFolder(
            name: "Archive",
            isCollapsed: true,
            color: .grey,
            nameOrigin: .manual,
            isArchive: true,
            profileId: profId
        )
        folders.append(archiveFolder)
        return archiveFolder
    }

    /// Moves a single tab into the persistent Archive folder for its profile.
    func archiveTab(id: UUID) {
        guard let targetTab = tab(for: id), !targetTab.isPinned else { return }
        let targetProfileId = targetTab.profileId ?? defaultProfileId
        let archive = getOrCreateArchiveFolder(for: targetProfileId)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            moveTabs([id], toFolder: archive.id)
        }
    }

    /// Moves multiple tabs into the persistent Archive folder for their respective profile(s).
    func archiveTabs(_ ids: [UUID]) {
        let unpinnedIds = ids.filter { tab(for: $0)?.isPinned == false }
        guard !unpinnedIds.isEmpty else { return }

        let groups = Dictionary(grouping: unpinnedIds) { tab(for: $0)?.profileId ?? defaultProfileId }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            for (profId, tabIds) in groups {
                let archive = getOrCreateArchiveFolder(for: profId)
                moveTabs(tabIds, toFolder: archive.id)
            }
        }
    }

    /// Evaluates unpinned, unarchived tabs and moves inactive tabs into the Archive folder.
    func archiveInactiveTabsIfNeeded() {
        guard let threshold = autoArchiveIntervalSeconds else { return }
        let cutoffDate = Date().addingTimeInterval(-threshold)
        let archiveId = folders.first(where: { $0.isArchive && ($0.profileId ?? defaultProfileId) == currentProfileId })?.id

        var tabsToArchive: [UUID] = []
        for tab in activeProfileTabs {
            // Do not archive pinned tabs, active/split visible tabs, or tabs already in the Archive folder
            guard !tab.isPinned,
                  archiveId == nil || tab.folderId != archiveId,
                  !currentTabIds.contains(tab.id) else {
                continue
            }

            let lastViewed = tab.lastViewedAt ?? Date()
            if lastViewed < cutoffDate {
                tabsToArchive.append(tab.id)
            }
        }

        guard !tabsToArchive.isEmpty else { return }
        let archive = getOrCreateArchiveFolder()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            moveTabs(tabsToArchive, toFolder: archive.id)
        }
    }

    /// Archives all unpinned tabs (excluding tabs already in the Archive folder).
    func archiveAllTabs() {
        let archiveId = folders.first(where: { $0.isArchive && ($0.profileId ?? defaultProfileId) == currentProfileId })?.id
        let tabsToArchive = activeProfileTabs.filter {
            !$0.isPinned && (archiveId == nil || $0.folderId != archiveId)
        }.map(\.id)

        guard !tabsToArchive.isEmpty else { return }
        let archive = getOrCreateArchiveFolder()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            moveTabs(tabsToArchive, toFolder: archive.id)
        }
    }

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
        let index = activeProfileFolders.count % palette.count
        return palette[index]
    }

    /// Creates a folder containing the given tabs (and their split partners, if
    /// any). New folders begin with a local title-derived fallback and are then
    /// refined by the on-device name generator when available.
    @discardableResult
    func createFolder(
        named name: String = "New Folder",
        with tabIds: [UUID],
        color: FolderColor? = nil,
        nameOrigin: FolderNameOrigin = .automatic
    ) -> TabFolder {
        let assignedColor = color ?? nextFolderColor()
        let effectiveOrigin: FolderNameOrigin = (nameOrigin == .automatic && !isAutoFolderNamesEnabled) ? .manual : nameOrigin
        let newFolder = TabFolder(
            name: initialFolderName(name, tabIds: tabIds, origin: effectiveOrigin),
            color: assignedColor,
            nameOrigin: effectiveOrigin,
            profileId: currentProfileId
        )
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            folders.append(newFolder)
            moveTabs(tabIds, toFolder: newFolder.id)
        }
        return newFolder
    }

    @discardableResult
    func createFolder(
        named name: String = "New Folder",
        with tabId: UUID,
        color: FolderColor? = nil,
        nameOrigin: FolderNameOrigin = .automatic
    ) -> TabFolder {
        createFolder(named: name, with: [tabId], color: color, nameOrigin: nameOrigin)
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
        clearAutomaticFolderNameState(for: id)
        folders[index].nameOrigin = .manual
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
        let emptyFolderIDs = folders
            .filter { !memberFolderIds.contains($0.id) }
            .map(\.id)
        emptyFolderIDs.forEach { clearAutomaticFolderNameState(for: $0) }
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
        clearAutomaticFolderNameState(for: id)
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
        clearAutomaticFolderNameState(for: id)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            for tabId in memberIds {
                removeTab(id: tabId)
            }
            folders.removeAll(where: { $0.id == id })
        }
    }

    // MARK: - Automatic Naming

    private static let automaticFolderNameDebounceNanoseconds: UInt64 = 2_500_000_000

    /// Debounces names for auto-managed folders affected by tab-title or
    /// membership changes. A manual name is never sent to or overwritten by
    /// the model.
    func scheduleAutomaticFolderNames(affectedBy previousTabs: [TabItem]) {
        guard isAutoFolderNamesEnabled else { return }

        let previousByID = Dictionary(uniqueKeysWithValues: previousTabs.map { ($0.id, $0) })
        let currentByID = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0) })
        let allIDs = Set(previousByID.keys).union(currentByID.keys)

        var affectedFolderIDs = Set<UUID>()
        for tabID in allIDs {
            let previous = previousByID[tabID]
            let current = currentByID[tabID]
            guard previous?.title != current?.title || previous?.folderId != current?.folderId else {
                continue
            }
            if let previousFolderID = previous?.folderId {
                affectedFolderIDs.insert(previousFolderID)
            }
            if let currentFolderID = current?.folderId {
                affectedFolderIDs.insert(currentFolderID)
            }
        }

        affectedFolderIDs.forEach { scheduleAutomaticFolderName(for: $0) }
    }

    func cancelAutomaticFolderNameGeneration(for folderId: UUID) {
        automaticFolderNameTasks[folderId]?.cancel()
        automaticFolderNameTasks[folderId] = nil
        automaticFolderNameGenerationIDs[folderId] = nil
    }

    func clearAutomaticFolderNameState(for folderId: UUID) {
        cancelAutomaticFolderNameGeneration(for: folderId)
        automaticFolderNameLastGeneratedInputs[folderId] = nil
    }

    private func scheduleAutomaticFolderName(for folderId: UUID) {
        guard isAutoFolderNamesEnabled,
              folder(for: folderId)?.nameOrigin == .automatic,
              let input = automaticFolderNameInput(for: folderId) else {
            cancelAutomaticFolderNameGeneration(for: folderId)
            return
        }

        // Avoid re-running on-device generation if the input matches what was already generated
        guard automaticFolderNameLastGeneratedInputs[folderId] != input else {
            return
        }

        cancelAutomaticFolderNameGeneration(for: folderId)
        let generationID = UUID()
        automaticFolderNameGenerationIDs[folderId] = generationID

        automaticFolderNameTasks[folderId] = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.automaticFolderNameDebounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            let name = await FolderNameGenerator.suggestedName(for: input.titles)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.finishAutomaticFolderNameGeneration(
                    for: folderId,
                    generationID: generationID,
                    input: input,
                    name: name
                )
            }
        }
    }

    private func finishAutomaticFolderNameGeneration(
        for folderId: UUID,
        generationID: UUID,
        input: AutomaticFolderNameInput,
        name: String?
    ) {
        guard automaticFolderNameGenerationIDs[folderId] == generationID else { return }
        automaticFolderNameTasks[folderId] = nil
        automaticFolderNameGenerationIDs[folderId] = nil

        guard let name,
              let index = folders.firstIndex(where: { $0.id == folderId }),
              folders[index].nameOrigin == .automatic,
              automaticFolderNameInput(for: folderId) == input else {
            return
        }
        automaticFolderNameLastGeneratedInputs[folderId] = input
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            folders[index].name = name
        }
    }

    private func initialFolderName(_ requestedName: String, tabIds: [UUID], origin: FolderNameOrigin) -> String {
        let trimmed = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard origin == .automatic, trimmed == "New Folder" else {
            return trimmed.isEmpty ? "New Folder" : trimmed
        }

        let titles = tabIds.compactMap { tab(for: $0).flatMap(folderNameInputTitle) }
        return FolderNameGenerator.fallbackName(for: titles) ?? "New Folder"
    }

    private func automaticFolderNameInput(for folderId: UUID) -> AutomaticFolderNameInput? {
        // Folder names summarize membership rather than sidebar order. A
        // stable order keeps an in-flight response valid when a person merely
        // rearranges tabs within the same folder.
        let members = folderTabs(folderId).sorted { $0.id.uuidString < $1.id.uuidString }
        let titles = members.prefix(12).compactMap(folderNameInputTitle)
        guard !titles.isEmpty else { return nil }
        return AutomaticFolderNameInput(memberIDs: members.map(\.id), titles: titles)
    }

    private func folderNameInputTitle(for tab: TabItem) -> String? {
        let trimmedTitle = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawTitle: String
        if !trimmedTitle.isEmpty, trimmedTitle != "New Tab", trimmedTitle != "Lotus" {
            rawTitle = trimmedTitle
        } else if let host = tab.url?.host, !host.isEmpty {
            rawTitle = host
        } else {
            return nil
        }

        let compactTitle = rawTitle
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !compactTitle.isEmpty else { return nil }
        return String(compactTitle.prefix(120))
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
        } else {
            let minUnpinnedIndex = newTabs.lastIndex(where: \.isPinned).map { $0 + 1 } ?? 0
            var insertPos = max(originalFirstIndex ?? minUnpinnedIndex, minUnpinnedIndex)
            insertPos = min(insertPos, newTabs.count)

            // If insertPos falls inside an existing folder, advance past its last member
            // to preserve that folder's contiguity.
            if insertPos > 0 {
                let prevFolderId = newTabs[insertPos - 1].folderId
                if let prevFolderId,
                   let lastMember = newTabs.lastIndex(where: { $0.folderId == prevFolderId }),
                   lastMember >= insertPos {
                    insertPos = lastMember + 1
                }
            }

            if insertPos <= newTabs.count {
                newTabs.insert(contentsOf: moved, at: insertPos)
            } else {
                newTabs.append(contentsOf: moved)
            }
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            tabs = newTabs
            removeEmptyFolders()
            if let folderId, let destFolder = folder(for: folderId), !destFolder.isArchive {
                expandFolder(id: folderId)
            }
        }
    }
}
