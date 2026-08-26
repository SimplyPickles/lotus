//
//  Profile.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import SwiftUI

/// A user browsing profile with isolated website data, cookies, tabs, and theme styling.
struct Profile: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var color: FolderColor
    var isDefault: Bool
    var createdAt: Date
    var defaultSearchEngine: String?
    var customUserAgent: String?

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "person.crop.circle",
        color: FolderColor = .blue,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        defaultSearchEngine: String? = nil,
        customUserAgent: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.defaultSearchEngine = defaultSearchEngine
        self.customUserAgent = customUserAgent
    }

    enum CodingKeys: String, CodingKey {
        case id, name, icon, color, isDefault, createdAt, defaultSearchEngine, customUserAgent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "person.crop.circle"
        self.color = try container.decodeIfPresent(FolderColor.self, forKey: .color) ?? .blue
        self.isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.defaultSearchEngine = try container.decodeIfPresent(String.self, forKey: .defaultSearchEngine)
        self.customUserAgent = try container.decodeIfPresent(String.self, forKey: .customUserAgent)
    }

    static let defaultProfileId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    static let defaultProfile = Profile(
        id: defaultProfileId,
        name: "Personal",
        icon: "person.crop.circle",
        color: .blue,
        isDefault: true,
        createdAt: Date.distantPast
    )

    static let presetIcons: [String] = [
        "person.crop.circle",
        "briefcase",
        "graduationcap",
        "gamecontroller",
        "globe",
        "sparkles",
        "star",
        "heart",
        "cart",
        "pencil",
        "building.2",
        "terminal",
        "book",
        "film",
        "music.note",
        "paintpalette"
    ]
}
