//
//  FolderCloseConfirmationView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct FolderCloseConfirmationView: View {
    @ObservedObject var browserState: BrowserState
    @State private var isHoveringKeepTabs: Bool = false
    @State private var isHoveringCancel: Bool = false
    @State private var isHoveringClose: Bool = false

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
            ZStack {
                // Dimmed backdrop
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        browserState.cancelCloseFolder()
                    }

                // Modal Card
                VStack(alignment: .leading, spacing: 0) {
                    // Folder Icon Squircle
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(folder.color.color)
                            .frame(width: 38, height: 38)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 4, y: 2)

                        Image(systemName: "folder.fill")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                    }
                    .padding(.bottom, 14)

                    // Title
                    Text("Close \"\(folder.name)\"?")
                        .font(.system(size: 18.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, 6)

                    // Subtitle
                    Text("This will close \(tabCount == 1 ? "the tab" : "all \(tabCount) tabs") inside this folder.")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.65))
                        .padding(.bottom, 22)

                    // Buttons row
                    HStack(spacing: 8) {
                        // Keep tabs (ungroup) button
                        Button {
                            browserState.confirmCloseFolder(id: folderId, keepTabs: true)
                        } label: {
                            Text("Keep tabs")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isHoveringKeepTabs ? Color.white.opacity(0.18) : Color.white.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringKeepTabs = $0 }

                        Spacer(minLength: 12)

                        // Cancel button
                        Button {
                            browserState.cancelCloseFolder()
                        } label: {
                            HStack(spacing: 6) {
                                Text("Cancel")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)

                                Text("ESC")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.55))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.white.opacity(0.08))
                                    )
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isHoveringCancel ? Color.white.opacity(0.18) : Color.white.opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.escape, modifiers: [])
                        .onHover { isHoveringCancel = $0 }

                        // Close Folder button
                        Button {
                            browserState.confirmCloseFolder(id: folderId, keepTabs: false)
                        } label: {
                            HStack(spacing: 5) {
                                Text("Close Folder")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)

                                Image(systemName: "return")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isHoveringClose ? Color(red: 0.98, green: 0.15, blue: 0.15) : Color(red: 0.90, green: 0.05, blue: 0.05))
                            )
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: [])
                        .onHover { isHoveringClose = $0 }
                    }
                }
                .padding(22)
                .frame(width: 440)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.13))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.55), radius: 30, x: 0, y: 14)
                .offset(y: -45)
                .transition(
                    .asymmetric(
                        insertion: .offset(y: -14).combined(with: .opacity),
                        removal: .offset(y: -14).combined(with: .opacity)
                    )
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(100)
        )
    }
}
