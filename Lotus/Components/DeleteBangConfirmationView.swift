//
//  DeleteBangConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI

struct DeleteBangConfirmationView: View {
    let bang: CustomBang
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        LotusConfirmationDialog(
            iconStyle: .destructive(),
            title: "Delete Bang “\(bang.name)”?",
            subtitle: "Are you sure you want to delete the search shortcut “!\(bang.cleanTrigger)”? You won’t be able to use this shortcut to search until you create it again.",
            onCancel: onCancel
        ) {
            EmptyView()
        } actions: {
            LotusDialogCancelButton(action: onCancel)
            LotusDialogActionButton(title: "Delete Bang", isDestructive: true, action: onConfirm)
        }
    }
}
