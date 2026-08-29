//
//  BookmarkConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI

enum BookmarkConfirmationType: Equatable {
    case deleteSingle(bookmark: BookmarkItem)
    case deleteSelected(count: Int, ids: Set<UUID>)
}

struct BookmarkConfirmationView: View {
    let confirmation: BookmarkConfirmationType
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var title: String {
        switch confirmation {
        case .deleteSingle(let bookmark):
            return "Delete Bookmark “\(bookmark.title)”?"
        case .deleteSelected(let count, _):
            return count == 1 ? "Delete 1 Bookmark?" : "Delete \(count) Bookmarks?"
        }
    }

    private var subtitle: String {
        switch confirmation {
        case .deleteSingle:
            return "Are you sure you want to delete this bookmark? This action cannot be undone."
        case .deleteSelected(let count, _):
            let itemText = count == 1 ? "bookmark" : "bookmarks"
            return "This will remove \(count) \(itemText) from your saved bookmarks. This action cannot be undone."
        }
    }

    var body: some View {
        LotusConfirmationDialog(
            iconStyle: .destructive(),
            title: title,
            subtitle: subtitle,
            onCancel: onCancel
        ) {
            EmptyView()
        } actions: {
            LotusDialogCancelButton(action: onCancel)
            LotusDialogActionButton(title: "Delete", isDestructive: true, action: onConfirm)
        }
    }
}
