//
//  ClosedTabRecord.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation

/// Snapshot of a closed tab for reopen support.
struct ClosedTabRecord: Codable, Equatable {
    let title: String
    let url: URL?
    let isPinned: Bool
    let insertionIndex: Int
}
