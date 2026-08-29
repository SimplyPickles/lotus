//
//  HistoryConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

enum HistoryConfirmationType: Equatable {
    case clearAll(totalCount: Int)
    case deleteSelected(ids: Set<UUID>)
}

struct HistoryConfirmationView: View {
    let confirmation: HistoryConfirmationType
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var title: String {
        switch confirmation {
        case .clearAll:
            return "Clear browsing history?"
        case .deleteSelected(let ids):
            return ids.count == 1 ? "Delete 1 history item?" : "Delete \(ids.count) history items?"
        }
    }

    private var subtitle: String {
        switch confirmation {
        case .clearAll(let count):
            let itemText = count == 1 ? "page" : "pages"
            return "This will remove all \(count) \(itemText) from your browsing history. This action cannot be undone."
        case .deleteSelected(let ids):
            let itemText = ids.count == 1 ? "this page" : "these \(ids.count) pages"
            return "This will remove \(itemText) from your browsing history. This action cannot be undone."
        }
    }

    private var confirmButtonTitle: String {
        switch confirmation {
        case .clearAll:
            return "Clear All"
        case .deleteSelected:
            return "Delete"
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
            LotusDialogActionButton(title: confirmButtonTitle, isDestructive: true, action: onConfirm)
        }
    }
}
