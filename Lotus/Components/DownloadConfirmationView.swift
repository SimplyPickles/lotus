//
//  DownloadConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI

enum DownloadConfirmationType: Equatable {
    case clearAll(totalCount: Int)
    case deleteSelected(ids: Set<UUID>)
}

struct DownloadConfirmationView: View {
    let confirmation: DownloadConfirmationType
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var title: String {
        switch confirmation {
        case .clearAll(let count):
            return "Clear all \(count) downloads?"
        case .deleteSelected(let ids):
            return "Delete \(ids.count) \(ids.count == 1 ? "download" : "downloads")?"
        }
    }

    private var subtitle: String {
        switch confirmation {
        case .clearAll:
            return "This will remove all download records from Lotus. Downloaded files on your disk will remain untouched."
        case .deleteSelected:
            return "This will remove the selected download records from Lotus. The downloaded files on disk will not be deleted."
        }
    }

    private var confirmButtonTitle: String {
        switch confirmation {
        case .clearAll:
            return "Clear All"
        case .deleteSelected(let ids):
            return "Delete \(ids.count)"
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
