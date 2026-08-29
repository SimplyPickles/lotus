//
//  WebsiteDataConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI

enum WebsiteDataConfirmationType: Equatable {
    case clearAll(totalCount: Int)
    case deleteSelected(domains: Set<String>)
}

struct WebsiteDataConfirmationView: View {
    let confirmation: WebsiteDataConfirmationType
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var title: String {
        switch confirmation {
        case .clearAll:
            return "Clear all website data?"
        case .deleteSelected(let domains):
            return domains.count == 1 ? "Delete data for 1 site?" : "Delete data for \(domains.count) sites?"
        }
    }

    private var subtitle: String {
        switch confirmation {
        case .clearAll(let count):
            let siteText = count == 1 ? "site" : "sites"
            return "This will clear cookies, cache, and local storage for all \(count) \(siteText). You may be logged out of active sessions. This action cannot be undone."
        case .deleteSelected(let domains):
            let siteText = domains.count == 1 ? "this site" : "these \(domains.count) sites"
            return "This will clear stored cookies, cache, and local data for \(siteText). This action cannot be undone."
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
