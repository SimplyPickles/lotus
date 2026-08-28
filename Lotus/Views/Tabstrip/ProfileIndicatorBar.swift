//
//  ProfileIndicatorBar.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import SwiftUI
import AppKit

struct ProfileIndicatorBar: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredProfileId: UUID? = nil
    @State private var isCreateProfileSheetPresented: Bool = false
    @State private var profileToEdit: Profile? = nil

    var body: some View {
        if browserState.profiles.count > 1 {
            HStack(spacing: 10) {
                ForEach(Array(browserState.profiles.enumerated()), id: \.element.id) { index, profile in
                    let isActive = profile.id == browserState.currentProfileId
                    let isHovered = hoveredProfileId == profile.id

                    Button {
                        browserState.switchToProfile(at: index)
                    } label: {
                        ZStack {
                            if isActive {
                                SpaceIconView(icon: profile.icon, size: 12)
                                    .foregroundColor(
                                        colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.85)
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Circle()
                                    .fill(
                                        colorScheme == .dark
                                            ? Color.white.opacity(isHovered ? 0.75 : 0.28)
                                            : Color.black.opacity(isHovered ? 0.65 : 0.22)
                                    )
                                    .frame(width: isHovered ? 6 : 5, height: isHovered ? 6 : 5)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isActive)
                        .animation(.easeInOut(duration: 0.12), value: isHovered)
                    }
                    .buttonStyle(.plain)
                    .help(profile.name)
                    .onHover { hovering in
                        hoveredProfileId = hovering ? profile.id : nil
                    }
                    .contextMenu {
                        Button("Switch to \(profile.name)") {
                            browserState.switchProfile(to: profile.id)
                        }
                        Divider()
                        Button("New Space…") {
                            isCreateProfileSheetPresented = true
                        }
                        Button("Edit Space…") {
                            profileToEdit = profile
                        }
                        Button("Manage Profiles…") {
                            browserState.openSettingsPage()
                        }
                        if browserState.canDeleteProfile(profile) {
                            Divider()
                            Button("Delete Space", role: .destructive) {
                                browserState.requestDeleteProfile(profile)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 26)
            .padding(.bottom, 6)
            .sheet(isPresented: $isCreateProfileSheetPresented) {
                CreateProfileModalView(
                    onSave: { newName, newIcon, newColor in
                        let created = browserState.createProfile(name: newName, icon: newIcon, color: newColor)
                        browserState.switchProfile(to: created.id, direction: .forward)
                        isCreateProfileSheetPresented = false
                    },
                    onCancel: {
                        isCreateProfileSheetPresented = false
                    }
                )
            }
            .sheet(item: $profileToEdit) { profile in
                EditProfileModalView(
                    profile: profile,
                    canDelete: browserState.canDeleteProfile(profile),
                    onSave: { updated in
                        browserState.updateProfile(updated)
                        profileToEdit = nil
                    },
                    onDelete: { toDelete in
                        profileToEdit = nil
                        browserState.requestDeleteProfile(toDelete)
                    },
                    onCancel: {
                        profileToEdit = nil
                    }
                )
            }
        }
    }
}

// MARK: - Space Icon View

struct SpaceIconView: View {
    let icon: String
    var size: CGFloat = 18

    private var isSFImage: Bool {
        NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil
    }

    var body: some View {
        if isSFImage {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
        } else {
            Text(icon)
                .font(.system(size: size + 2))
        }
    }
}
