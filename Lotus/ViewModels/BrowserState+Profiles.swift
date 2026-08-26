//
//  BrowserState+Profiles.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import SwiftUI
import WebKit

enum SpaceTransitionDirection {
    case forward
    case backward
}

extension BrowserState {

    // MARK: - Profile Accessors

    var currentProfile: Profile {
        profiles.first(where: { $0.id == currentProfileId }) ?? profiles.first ?? Profile.defaultProfile
    }

    var defaultProfileId: UUID {
        profiles.first(where: { $0.isDefault })?.id ?? Profile.defaultProfileId
    }

    var activeProfileTabs: [TabItem] {
        tabs.filter { ($0.profileId ?? defaultProfileId) == currentProfileId }
    }

    var activeProfileFolders: [TabFolder] {
        folders.filter { ($0.profileId ?? defaultProfileId) == currentProfileId }
    }

    var activeProfileBookmarks: [BookmarkItem] {
        bookmarks(for: currentProfileId)
    }

    func bookmarks(for profileId: UUID) -> [BookmarkItem] {
        bookmarks.filter { ($0.profileId ?? defaultProfileId) == profileId }
    }

    var activeProfileDownloads: [DownloadItem] {
        downloads(for: currentProfileId)
    }

    func downloads(for profileId: UUID) -> [DownloadItem] {
        downloads.filter { ($0.profileId ?? defaultProfileId) == profileId }
    }

    var activeProfileHistoryEntries: [HistoryItem] {
        historyEntries(for: currentProfileId)
    }

    func historyEntries(for profileId: UUID) -> [HistoryItem] {
        historyEntries.filter { ($0.profileId ?? defaultProfileId) == profileId }
    }

    // MARK: - Space Cycling & Directional Switching

    func switchToNextProfile() {
        guard profiles.count > 1 else { return }
        guard let currentIndex = profiles.firstIndex(where: { $0.id == currentProfileId }) else { return }
        guard currentIndex + 1 < profiles.count else { return }
        switchProfile(to: profiles[currentIndex + 1].id, direction: .forward)
    }

    func switchToPreviousProfile() {
        guard profiles.count > 1 else { return }
        guard let currentIndex = profiles.firstIndex(where: { $0.id == currentProfileId }) else { return }
        guard currentIndex > 0 else { return }
        switchProfile(to: profiles[currentIndex - 1].id, direction: .backward)
    }

    func switchToProfile(at index: Int) {
        guard index >= 0, index < profiles.count else { return }
        let targetId = profiles[index].id
        guard targetId != currentProfileId else { return }
        let currentIndex = profiles.firstIndex(where: { $0.id == currentProfileId }) ?? 0
        let direction: SpaceTransitionDirection = index > currentIndex ? .forward : .backward
        switchProfile(to: targetId, direction: direction)
    }

    func switchProfile(to profileId: UUID, direction: SpaceTransitionDirection? = nil) {
        guard currentProfileId != profileId else { return }
        guard let targetProfile = profiles.first(where: { $0.id == profileId }) else { return }

        if let dir = direction {
            self.spaceTransitionDirection = dir
        } else if let currIndex = profiles.firstIndex(where: { $0.id == currentProfileId }),
                  let targetIndex = profiles.firstIndex(where: { $0.id == profileId }) {
            self.spaceTransitionDirection = targetIndex > currIndex ? .forward : .backward
        }

        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            // Save outgoing space's active tab state
            if let currentTab = tab(for: selectedTabId) {
                let outProfId = currentTab.profileId ?? defaultProfileId
                lastSelectedTabPerProfile[outProfId] = selectedTabId
                lastCurrentTabsPerProfile[outProfId] = currentTabIds
            }

            currentProfileId = profileId
            spaceSwipeOffset = 0
            UserDefaults.standard.set(targetProfile.color.accentColorEquivalent.rawValue, forKey: "lotus.browser.accentColor")
            clearSidebarSelection()

            let profileTabs = activeProfileTabs

            // Check if there is a remembered active tab for this profile
            if let savedSelectedId = lastSelectedTabPerProfile[profileId],
               let savedTab = profileTabs.first(where: { $0.id == savedSelectedId }) {
                if let savedCurrents = lastCurrentTabsPerProfile[profileId],
                   !savedCurrents.isEmpty,
                   savedCurrents.allSatisfy({ id in profileTabs.contains(where: { $0.id == id }) }) {
                    currentTabIds = savedCurrents
                    selectedTabId = savedTab.id
                } else if let group = splitGroup(containing: savedTab.id) {
                    currentTabIds = group
                    selectedTabId = savedTab.id
                } else {
                    currentTabIds = [savedTab.id]
                    selectedTabId = savedTab.id
                }
                isCommandPaletteOpen = false
            } else if let first = profileTabs.first {
                if let group = splitGroup(containing: first.id) {
                    currentTabIds = group
                    selectedTabId = first.id
                } else {
                    currentTabIds = [first.id]
                    selectedTabId = first.id
                }
                isCommandPaletteOpen = false
            } else {
                currentTabIds = []
                selectedTabId = UUID()
                isCommandPaletteOpen = true
            }

            updateNavigationState()
            saveSession()
        }
    }

    // MARK: - Profile CRUD

    @discardableResult
    func createProfile(
        name: String,
        icon: String = "person.crop.circle",
        color: FolderColor = .blue,
        defaultSearchEngine: String? = nil,
        customUserAgent: String? = nil
    ) -> Profile {
        let newProfile = Profile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Profile" : name,
            icon: icon,
            color: color,
            isDefault: false,
            createdAt: Date(),
            defaultSearchEngine: defaultSearchEngine,
            customUserAgent: customUserAgent
        )
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            profiles.append(newProfile)
            profileStore.saveAsync(profiles)
        }
        return newProfile
    }

    func updateProfile(_ profile: Profile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            profiles[index] = profile
            if profile.id == currentProfileId {
                UserDefaults.standard.set(profile.color.accentColorEquivalent.rawValue, forKey: "lotus.browser.accentColor")
            }
            profileStore.saveAsync(profiles)
        }
    }

    func requestDeleteProfile(_ profile: Profile) {
        guard profiles.count > 1, !profile.isDefault else { return }
        withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
            profileToDeleteConfirmation = profile
        }
    }

    func confirmDeleteProfile() {
        guard let p = profileToDeleteConfirmation else { return }
        withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
            profileToDeleteConfirmation = nil
        }
        deleteProfile(id: p.id)
    }

    func cancelDeleteProfile() {
        withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
            profileToDeleteConfirmation = nil
        }
    }

    func deleteProfile(id: UUID) {
        guard profiles.count > 1 else { return }
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let deletingProfile = profiles[index]
        guard !deletingProfile.isDefault else { return }

        // 1. Remove all tabs associated with this profile
        let tabsToRemove = tabs.filter { ($0.profileId ?? defaultProfileId) == id }.map(\.id)
        for tabId in tabsToRemove {
            removeTab(id: tabId)
        }

        // 2. Remove all folders associated with this profile
        folders.removeAll(where: { ($0.profileId ?? defaultProfileId) == id })

        // 3. If currently in this profile, switch to default
        if currentProfileId == id {
            switchProfile(to: defaultProfileId)
        }

        // 4. Remove profile from list
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            profiles.remove(at: index)
            profileStore.saveAsync(profiles)
        }

        // 5. Clean up bookmarks, downloads, and history for this profile
        bookmarks.removeAll(where: { $0.profileId == id })
        bookmarkStore.save(bookmarks)
        let deletedDownloadIds = Set(downloads.filter { $0.profileId == id }.map(\.id))
        if !deletedDownloadIds.isEmpty {
            downloadStore.removeEntries(ids: deletedDownloadIds, from: &downloads)
        }
        let deletedHistoryIds = Set(historyEntries.filter { $0.profileId == id }.map(\.id))
        if !deletedHistoryIds.isEmpty {
            historyStore.removeEntries(ids: deletedHistoryIds, from: &historyEntries)
        }

        // 6. Clean up WebKit persistent data store
        profileStore.deleteDataStore(for: id)
    }

    // MARK: - Tab & Folder Profile Relocation

    func moveTab(_ tabId: UUID, toProfile profileId: UUID) {
        moveTabs([tabId], toProfile: profileId)
    }

    func moveTabs(_ tabIds: [UUID], toProfile profileId: UUID) {
        guard profiles.contains(where: { $0.id == profileId }) else { return }
        guard !tabIds.isEmpty else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            for id in tabIds {
                if let index = tabs.firstIndex(where: { $0.id == id }) {
                    tabs[index].profileId = profileId
                    // Folders are profile-scoped; strip folder ID if moving across profiles
                    tabs[index].folderId = nil
                    // Discard cached WKWebView so it will re-instantiate in target profile's data store
                    if let webView = webViewStore.removeValue(forKey: id) {
                        webView.stopLoading()
                        webView.navigationDelegate = nil
                        webView.uiDelegate = nil
                        observers[id]?.forEach { $0.invalidate() }
                        observers.removeValue(forKey: id)
                    }
                }
            }

            // If moving the currently selected tab out of the current profile, update selection
            if tabIds.contains(selectedTabId) && profileId != currentProfileId {
                let remaining = activeProfileTabs
                if let next = remaining.first {
                    selectTab(next.id)
                } else {
                    currentTabIds = []
                    selectedTabId = UUID()
                    openCommandPalette()
                }
            }

            saveSession()
        }
    }

    func moveFolder(_ folderId: UUID, toProfile profileId: UUID) {
        guard profiles.contains(where: { $0.id == profileId }) else { return }
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderId }) else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            folders[folderIndex].profileId = profileId
            let memberIds = tabs.filter { $0.folderId == folderId }.map(\.id)
            for id in memberIds {
                if let index = tabs.firstIndex(where: { $0.id == id }) {
                    tabs[index].profileId = profileId
                    if let webView = webViewStore.removeValue(forKey: id) {
                        webView.stopLoading()
                        webView.navigationDelegate = nil
                        webView.uiDelegate = nil
                        observers[id]?.forEach { $0.invalidate() }
                        observers.removeValue(forKey: id)
                    }
                }
            }

            if memberIds.contains(selectedTabId) && profileId != currentProfileId {
                let remaining = activeProfileTabs
                if let next = remaining.first {
                    selectTab(next.id)
                } else {
                    currentTabIds = []
                    selectedTabId = UUID()
                    openCommandPalette()
                }
            }

            saveSession()
        }
    }
}
