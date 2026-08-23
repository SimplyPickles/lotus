//
//  ClosedTabRecord.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation

/// Snapshot of a closed tab for reopen support.
struct ClosedTabRecord: Codable, Equatable {
    var id: UUID
    var title: String
    var url: URL?
    var isPinned: Bool
    var insertionIndex: Int
    var folderId: UUID?
    var folderName: String?
    var folderColor: FolderColor?
    var splitPartnerId: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        url: URL? = nil,
        isPinned: Bool = false,
        insertionIndex: Int,
        folderId: UUID? = nil,
        folderName: String? = nil,
        folderColor: FolderColor? = nil,
        splitPartnerId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.isPinned = isPinned
        self.insertionIndex = insertionIndex
        self.folderId = folderId
        self.folderName = folderName
        self.folderColor = folderColor
        self.splitPartnerId = splitPartnerId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decodeIfPresent(URL.self, forKey: .url)
        self.isPinned = try container.decode(Bool.self, forKey: .isPinned)
        self.insertionIndex = try container.decode(Int.self, forKey: .insertionIndex)
        self.folderId = try container.decodeIfPresent(UUID.self, forKey: .folderId)
        self.folderName = try container.decodeIfPresent(String.self, forKey: .folderName)
        self.folderColor = try container.decodeIfPresent(FolderColor.self, forKey: .folderColor)
        self.splitPartnerId = try container.decodeIfPresent(UUID.self, forKey: .splitPartnerId)
    }
}
