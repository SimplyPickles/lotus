//
//  FolderCloseConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct FolderCloseConfirmationView: View {
    @ObservedObject var browserState: BrowserState

    private var folder: TabFolder? {
        guard let id = browserState.folderToCloseConfirmation else { return nil }
        return browserState.folder(for: id)
    }

    private var tabCount: Int {
        guard let id = browserState.folderToCloseConfirmation else { return 0 }
        return browserState.folderTabs(id).count
    }

    var body: some View {
        guard let folder = folder, let folderId = browserState.folderToCloseConfirmation else {
            return AnyView(EmptyView())
        }

        return AnyView(
            LotusConfirmationDialog(
                iconStyle: .custom(
                    gradient: LinearGradient(colors: [folder.color.color.opacity(0.9), folder.color.color], startPoint: .top, endPoint: .bottom),
                    systemImage: "folder.fill"
                ),
                title: "Close \"\(folder.name)\"?",
                subtitle: "This will close \(tabCount == 1 ? "the tab" : "all \(tabCount) tabs") inside this folder.",
                onCancel: { browserState.cancelCloseFolder() }
            ) {
                EmptyView()
            } actions: {
                LotusDialogSecondaryButton(title: "Keep tabs") {
                    browserState.confirmCloseFolder(id: folderId, keepTabs: true)
                }

                LotusDialogCancelButton {
                    browserState.cancelCloseFolder()
                }

                LotusDialogActionButton(title: "Close Folder", isDestructive: true) {
                    browserState.confirmCloseFolder(id: folderId, keepTabs: false)
                }
            }
        )
    }
}
