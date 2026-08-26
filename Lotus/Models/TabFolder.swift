//
//  TabFolder.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

/// Chromium-style preset colors for tab folders / groups.
enum FolderColor: String, Codable, CaseIterable, Identifiable {
    case blue
    case purple
    case pink
    case red
    case orange
    case green
    case yellow
    case grey

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .blue: return "Blue"
            case .purple: return "Purple"
            case .pink: return "Pink"
            case .red: return "Red"
            case .orange: return "Orange"
            case .yellow: return "Yellow"
            case .green: return "Green"
            case .grey: return "Grey"
        }
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    var nsColor: NSColor {
        switch self {
            case .blue:
                return NSColor(srgbRed: 0.18, green: 0.53, blue: 0.98, alpha: 1.0)
            case .purple:
                return NSColor(srgbRed: 0.63, green: 0.31, blue: 0.90, alpha: 1.0)
            case .pink:
                return NSColor(srgbRed: 0.91, green: 0.30, blue: 0.58, alpha: 1.0)
            case .red:
                return NSColor(srgbRed: 0.92, green: 0.26, blue: 0.21, alpha: 1.0)
            case .orange:
                return NSColor(srgbRed: 0.98, green: 0.55, blue: 0.15, alpha: 1.0)
            case .yellow:
                return NSColor(srgbRed: 0.96, green: 0.72, blue: 0.15, alpha: 1.0)
            case .green:
                return NSColor(srgbRed: 0.13, green: 0.69, blue: 0.30, alpha: 1.0)
            case .grey:
                return NSColor(srgbRed: 0.60, green: 0.62, blue: 0.65, alpha: 1.0)
        }
    }

    func swatchImage(isSelected: Bool = false) -> NSImage {
        let dimension: CGFloat = 14
        let image = NSImage(size: NSSize(width: dimension, height: dimension), flipped: false) { rect in
            let circleRect = rect.insetBy(dx: 1, dy: 1)
            let path = NSBezierPath(ovalIn: circleRect)
            self.nsColor.setFill()
            path.fill()

            if isSelected {
                let dotRect = rect.insetBy(dx: 4.5, dy: 4.5)
                let dot = NSBezierPath(ovalIn: dotRect)
                NSColor.white.setFill()
                dot.fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}

/// Records whether a folder label is maintained by the on-device name
/// generator or was explicitly chosen by the person using Lotus.
enum FolderNameOrigin: String, Codable, Hashable {
    case automatic
    case manual
}

/// A collapsible group of unpinned tabs in the sidebar (Arc/Zen-style).
///
/// Membership is stored on the tabs themselves (`TabItem.folderId`); the
/// folder only carries display metadata. Members are kept contiguous in
/// `BrowserState.tabs`, and the folder renders at its first member's position.
struct TabFolder: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var isCollapsed: Bool
    var color: FolderColor
    var nameOrigin: FolderNameOrigin
    var isArchive: Bool
    var profileId: UUID?

    init(
        id: UUID = UUID(),
        name: String = "New Folder",
        isCollapsed: Bool = false,
        color: FolderColor = .blue,
        nameOrigin: FolderNameOrigin = .automatic,
        isArchive: Bool = false,
        profileId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.isCollapsed = isCollapsed
        self.color = color
        self.nameOrigin = nameOrigin
        self.isArchive = isArchive
        self.profileId = profileId
    }

    enum CodingKeys: String, CodingKey {
        case id, name, isCollapsed, color, nameOrigin, isArchive, profileId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        self.color = try container.decodeIfPresent(FolderColor.self, forKey: .color) ?? .blue
        self.nameOrigin = try container.decodeIfPresent(FolderNameOrigin.self, forKey: .nameOrigin) ?? .manual
        self.isArchive = try container.decodeIfPresent(Bool.self, forKey: .isArchive) ?? false
        self.profileId = try container.decodeIfPresent(UUID.self, forKey: .profileId)
    }
}
