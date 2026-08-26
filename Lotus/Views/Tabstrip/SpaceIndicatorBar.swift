//
//  SpaceIndicatorBar.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import SwiftUI

struct SpaceIndicatorBar: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme

    @State private var hoveredProfileId: UUID? = nil
    @State private var isCreateProfileSheetPresented: Bool = false
    @State private var isEditProfileSheetPresented: Bool = false
    @State private var profileToEdit: Profile? = nil
    @State private var newProfileName: String = ""
    @State private var selectedIcon: String = "💪"
    @State private var selectedColor: FolderColor = .blue

    var body: some View {
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
                        newProfileName = ""
                        selectedIcon = "✨"
                        selectedColor = .blue
                        isCreateProfileSheetPresented = true
                    }
                    Button("Edit Space…") {
                        profileToEdit = profile
                        newProfileName = profile.name
                        selectedIcon = profile.icon
                        selectedColor = profile.color
                        isEditProfileSheetPresented = true
                    }
                    Button("Manage Profiles…") {
                        browserState.openSettingsPage()
                    }
                    if browserState.profiles.count > 1 && !profile.isDefault {
                        Divider()
                        Button("Delete Space", role: .destructive) {
                            browserState.deleteProfile(id: profile.id)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 26)
        .padding(.bottom, 6)
        .sheet(isPresented: $isCreateProfileSheetPresented) {
            createSpaceSheet
        }
        .sheet(isPresented: $isEditProfileSheetPresented) {
            editSpaceSheet
        }
    }

    // MARK: - Create Space Sheet

    private var createSpaceSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Create New Space")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }

            TextField("Space Name (e.g. Work, Research, Personal)", text: $newProfileName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Icon")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(Profile.presetIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            SpaceIconView(icon: icon, size: 14)
                                .frame(width: 28, height: 28)
                                .background(selectedIcon == icon ? selectedColor.color.opacity(0.2) : Color.clear)
                                .foregroundColor(selectedIcon == icon ? selectedColor.color : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(selectedIcon == icon ? selectedColor.color : Color.clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Theme Color")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(FolderColor.allCases) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: selectedColor == color ? 2.5 : 0)
                                )
                                .shadow(
                                    color: selectedColor == color ? color.color.opacity(0.45) : Color.clear,
                                    radius: 3,
                                    x: 0,
                                    y: 1
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    isCreateProfileSheetPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Space") {
                    let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Space" : newProfileName
                    let created = browserState.createProfile(name: name, icon: selectedIcon, color: selectedColor)
                    browserState.switchProfile(to: created.id, direction: .forward)
                    isCreateProfileSheetPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 380)
    }

    // MARK: - Edit Space Sheet

    private var editSpaceSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Edit Space")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }

            TextField("Space Name", text: $newProfileName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Icon")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(Profile.presetIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            SpaceIconView(icon: icon, size: 14)
                                .frame(width: 28, height: 28)
                                .background(selectedIcon == icon ? selectedColor.color.opacity(0.2) : Color.clear)
                                .foregroundColor(selectedIcon == icon ? selectedColor.color : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(selectedIcon == icon ? selectedColor.color : Color.clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Theme Color")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(FolderColor.allCases) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: selectedColor == color ? 2.5 : 0)
                                )
                                .shadow(
                                    color: selectedColor == color ? color.color.opacity(0.45) : Color.clear,
                                    radius: 3,
                                    x: 0,
                                    y: 1
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    isEditProfileSheetPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    if var profile = profileToEdit {
                        let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? profile.name : newProfileName
                        profile.name = name
                        profile.icon = selectedIcon
                        profile.color = selectedColor
                        browserState.updateProfile(profile)
                    }
                    isEditProfileSheetPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 380)
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
