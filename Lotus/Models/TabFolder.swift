//
//  TabFolder.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

/// Chromium-style preset colors for tab folders / groups.
enum FolderColor: String, Codable, CaseIterable, Identifiable {
    case grey
    case green
    case blue
    case purple
    case yellow
    case pink
    case red
    case orange
    case cyan

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grey: return "Grey"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .yellow: return "Yellow"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .cyan: return "Cyan"
        }
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    var nsColor: NSColor {
        switch self {
        case .blue:
            return NSColor(srgbRed: 0.18, green: 0.53, blue: 0.98, alpha: 1.0)
        case .red:
            return NSColor(srgbRed: 0.92, green: 0.26, blue: 0.21, alpha: 1.0)
        case .yellow:
            return NSColor(srgbRed: 0.96, green: 0.72, blue: 0.15, alpha: 1.0)
        case .green:
            return NSColor(srgbRed: 0.13, green: 0.69, blue: 0.30, alpha: 1.0)
        case .pink:
            return NSColor(srgbRed: 0.91, green: 0.30, blue: 0.58, alpha: 1.0)
        case .purple:
            return NSColor(srgbRed: 0.63, green: 0.31, blue: 0.90, alpha: 1.0)
        case .cyan:
            return NSColor(srgbRed: 0.00, green: 0.73, blue: 0.83, alpha: 1.0)
        case .orange:
            return NSColor(srgbRed: 0.98, green: 0.55, blue: 0.15, alpha: 1.0)
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

    init(id: UUID = UUID(), name: String = "New Folder", isCollapsed: Bool = false, color: FolderColor = .blue) {
        self.id = id
        self.name = name
        self.isCollapsed = isCollapsed
        self.color = color
    }

    enum CodingKeys: String, CodingKey {
        case id, name, isCollapsed, color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        self.color = try container.decodeIfPresent(FolderColor.self, forKey: .color) ?? .blue
    }
}
