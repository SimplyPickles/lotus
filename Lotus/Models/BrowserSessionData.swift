//
//  BrowserSessionData.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation

/// Serializable snapshot of the user's browser session across app launches.
struct BrowserSessionData: Codable {
    var tabs: [TabItem]
    var selectedTabId: UUID
    var currentTabIds: [UUID]?
    var splitGroups: [[UUID]]?
    var splitRatios: [String: CGFloat]?
    var folders: [TabFolder]?
    var recentlyClosed: [ClosedTabRecord]
    var isSidebarVisible: Bool
    var sidebarWidth: CGFloat
    var tabZoomLevels: [String: CGFloat]?
    var currentProfileId: UUID?
    var lastSelectedTabPerProfile: [String: UUID]?
    var lastCurrentTabsPerProfile: [String: [UUID]]?
}
