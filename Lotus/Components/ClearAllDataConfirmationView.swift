//
//  ClearAllDataConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import SwiftUI

struct ClearAllDataConfirmationView: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isClearing: Bool = false

    var body: some View {
        LotusConfirmationDialog(
            iconStyle: .destructive(),
            title: "Clear all browsing data?",
            subtitle: "This will permanently clear all history, download history, disk & memory caches, cookies, saved logins, and website data. Open tabs will reload.",
            onCancel: {
                if !isClearing {
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
                        browserState.isClearAllDataConfirmationPresented = false
                    }
                }
            }
        ) {
            EmptyView()
        } actions: {
            LotusDialogCancelButton {
                withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
                    browserState.isClearAllDataConfirmationPresented = false
                }
            }
            .disabled(isClearing)

            LotusDialogActionButton(title: "Clear All Data", isDestructive: true) {
                isClearing = true
                browserState.clearAllBrowserData {
                    isClearing = false
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
                        browserState.isClearAllDataConfirmationPresented = false
                    }
                }
            }
            .disabled(isClearing)
        }
    }
}
