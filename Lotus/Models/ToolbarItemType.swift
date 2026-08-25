//
//  ToolbarItemType.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import SwiftUI

/// Identifiers for customizable toolbar items that can be arranged and reordered.
enum ToolbarItemType: String, CaseIterable, Identifiable, Codable {
    case sidebarToggle = "sidebarToggle"
    case back = "back"
    case forward = "forward"
    case reload = "reload"
    case addressBar = "addressBar"
    case splitView = "splitView"
    case downloads = "downloads"
    case shields = "shields"
    case media = "media"
    case moreMenu = "moreMenu"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sidebarToggle: return "Sidebar"
        case .back: return "Back"
        case .forward: return "Forward"
        case .reload: return "Reload"
        case .addressBar: return "Address Bar"
        case .splitView: return "Split View"
        case .downloads: return "Downloads"
        case .shields: return "Shields"
        case .media: return "Media"
        case .moreMenu: return "More Options"
        }
    }

    var subtitle: String {
        switch self {
        case .sidebarToggle: return "Toggle sidebar visibility"
        case .back: return "Navigate to previous page"
        case .forward: return "Navigate to next page"
        case .reload: return "Reload or stop page loading"
        case .addressBar: return "Search & address bar"
        case .splitView: return "Split screen with another tab"
        case .downloads: return "Active & recent downloads"
        case .shields: return "Content protection & Zap tool"
        case .media: return "Global audio & video controls"
        case .moreMenu: return "Browser menu & actions"
        }
    }

    var iconName: String {
        switch self {
        case .sidebarToggle: return "sidebar.left"
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        case .reload: return "arrow.clockwise"
        case .addressBar: return "magnifyingglass"
        case .splitView: return "rectangle.split.2x1"
        case .downloads: return "arrow.down.circle"
        case .shields: return "shield.fill"
        case .media: return "play.tv"
        case .moreMenu: return "ellipsis"
        }
    }

    static let defaultOrder: [ToolbarItemType] = [
        .sidebarToggle,
        .back,
        .forward,
        .reload,
        .addressBar,
        .splitView,
        .downloads,
        .shields,
        .media,
        .moreMenu
    ]

    static func parseLayout(from raw: String) -> [ToolbarItemType] {
        if raw.isEmpty { return defaultOrder }
        if raw == "none" { return [] }
        let parsed = raw.split(separator: ",").compactMap { ToolbarItemType(rawValue: String($0)) }
        var result: [ToolbarItemType] = []
        for item in parsed {
            if !result.contains(item) {
                result.append(item)
            }
        }
        return result
    }

    static func serializeLayout(_ items: [ToolbarItemType]) -> String {
        if items.isEmpty { return "none" }
        return items.map(\.rawValue).joined(separator: ",")
    }

    static func availableItems(for activeItems: [ToolbarItemType]) -> [ToolbarItemType] {
        allCases.filter { !activeItems.contains($0) }
    }
}
