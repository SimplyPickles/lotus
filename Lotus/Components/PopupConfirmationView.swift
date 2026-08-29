//
//  PopupConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import SwiftUI

struct PopupConfirmationRequest: Identifiable {
    let id = UUID()
    let sourceTabId: UUID
    let sourceHost: String
    let targetURL: URL?
    let targetHost: String
}

struct PopupConfirmationView: View {
    @ObservedObject var browserState: BrowserState

    private var request: PopupConfirmationRequest? {
        browserState.pendingPopupRequest
    }

    var body: some View {
        guard let request = request else {
            return AnyView(EmptyView())
        }

        return AnyView(
            LotusConfirmationDialog(
                iconStyle: .custom(
                    gradient: LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.55, blue: 0.95),
                            Color(red: 0.10, green: 0.40, blue: 0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    systemImage: "plus.rectangle.on.rectangle.fill"
                ),
                title: "Open tab to \(request.targetHost)?",
                subtitle: "The website at \(request.sourceHost) is attempting to open a new tab.",
                onCancel: { browserState.cancelOpenPopup() }
            ) {
                EmptyView()
            } actions: {
                LotusDialogCancelButton(title: "Don't Open") {
                    browserState.cancelOpenPopup()
                }

                LotusDialogActionButton(title: "Open Tab", isDestructive: false) {
                    browserState.confirmOpenPopup()
                }
            }
        )
    }
}
