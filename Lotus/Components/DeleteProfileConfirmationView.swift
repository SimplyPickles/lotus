//
//  DeleteProfileConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import SwiftUI

struct DeleteProfileConfirmationView: View {
    @ObservedObject var browserState: BrowserState
    let profile: Profile

    var body: some View {
        LotusConfirmationDialog(
            iconStyle: .destructive(),
            title: "Delete Profile \"\(profile.name)\"?",
            subtitle: "All open tabs, folders, and isolated website data (cookies, storage, cache) for this profile will be permanently deleted.",
            cardWidth: 460,
            onCancel: { browserState.cancelDeleteProfile() }
        ) {
            EmptyView()
        } actions: {
            LotusDialogCancelButton(action: { browserState.cancelDeleteProfile() })
            LotusDialogActionButton(title: "Delete Profile and Clear Data", isDestructive: true, action: { browserState.confirmDeleteProfile() })
        }
    }
}
