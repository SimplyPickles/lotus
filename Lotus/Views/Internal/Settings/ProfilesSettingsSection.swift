//
//  ProfilesSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import SwiftUI

struct ProfilesSettingsSection: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil

    @State private var editingProfile: Profile? = nil
    @State private var profileToDelete: Profile? = nil
    @State private var isCreatingProfile: Bool = false
    @State private var newProfileName: String = ""
    @State private var newProfileIcon: String = "briefcase"
    @State private var newProfileColor: FolderColor = .purple
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSectionCard(title: "Configured Profiles", systemImage: "person.2") {
                VStack(spacing: 0) {
                    ForEach(Array(browserState.profiles.enumerated()), id: \.element.id) { index, profile in
                        if index > 0 {
                            SettingsDivider()
                        }
                        profileRow(for: profile)
                    }
                }
            }

            // Create New Profile Card
            SettingsSectionCard(title: "Add New Profile", systemImage: "plus.circle") {
                if isCreatingProfile {
                    createProfileForm
                        .padding(14)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create a Profile")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(foregroundPrimary)

                            Text("Separate cookies, logins, and tabs for work, personal, or projects")
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundColor(foregroundSecondary)
                        }

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                isCreatingProfile = true
                            }
                        } label: {
                            Label("New Profile", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                }
            }
        }
        .sheet(item: $editingProfile) { profile in
            editProfileSheet(for: profile)
        }
        .confirmationDialog(
            "Delete Profile \"\(profileToDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Profile and Clear Data", role: .destructive) {
                if let p = profileToDelete {
                    browserState.deleteProfile(id: p.id)
                    profileToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                profileToDelete = nil
            }
        } message: {
            Text("All open tabs, folders, and isolated website data (cookies, storage, cache) for this profile will be permanently deleted.")
        }
    }

    // MARK: - Profile Row

    @ViewBuilder
    private func profileRow(for profile: Profile) -> some View {
        let isActive = profile.id == browserState.currentProfileId
        let tabCount = browserState.tabs.filter { ($0.profileId ?? browserState.defaultProfileId) == profile.id }.count

        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(profile.color.color.opacity(0.18))
                    .frame(width: 32, height: 32)

                Image(systemName: profile.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(profile.color.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(foregroundPrimary)

                    if profile.isDefault {
                        Text("Default")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    if isActive {
                        Text("Active Window")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(profile.color.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(profile.color.color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text("\(tabCount) \(tabCount == 1 ? "tab" : "tabs")")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(foregroundSecondary)
            }

            Spacer()

            HStack(spacing: 6) {
                if !isActive {
                    Button("Switch") {
                        browserState.switchProfile(to: profile.id)
                    }
                    .controlSize(.small)
                }

                Button("Edit") {
                    editingProfile = profile
                }
                .controlSize(.small)

                if !profile.isDefault && browserState.profiles.count > 1 {
                    Button(role: .destructive) {
                        profileToDelete = profile
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
    }

    // MARK: - Create Profile Form

    private var createProfileForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Profile Details")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Cancel") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isCreatingProfile = false
                        newProfileName = ""
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(foregroundSecondary)
                .font(.system(size: 12))
            }

            TextField("Profile Name (e.g. Work, Client, Personal)", text: $newProfileName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Icon")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(foregroundSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(Profile.presetIcons, id: \.self) { icon in
                        Button {
                            newProfileIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 28, height: 28)
                                .background(newProfileIcon == icon ? newProfileColor.color.opacity(0.2) : Color.clear)
                                .foregroundColor(newProfileIcon == icon ? newProfileColor.color : foregroundPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(newProfileIcon == icon ? newProfileColor.color : Color.clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Theme Color")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(foregroundSecondary)

                HStack(spacing: 8) {
                    ForEach(FolderColor.allCases) { color in
                        Button {
                            newProfileColor = color
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: newProfileColor == color ? 2.5 : 0)
                                )
                                .shadow(radius: newProfileColor == color ? 2 : 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()

                Button("Create Profile") {
                    let created = browserState.createProfile(
                        name: newProfileName,
                        icon: newProfileIcon,
                        color: newProfileColor
                    )
                    browserState.switchProfile(to: created.id)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isCreatingProfile = false
                        newProfileName = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Edit Profile Sheet

    @ViewBuilder
    private func editProfileSheet(for profile: Profile) -> some View {
        EditProfileModalView(
            profile: profile,
            onSave: { updated in
                browserState.updateProfile(updated)
                editingProfile = nil
            },
            onCancel: {
                editingProfile = nil
            }
        )
    }
}

private struct EditProfileModalView: View {
    let profile: Profile
    let onSave: (Profile) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var icon: String = "person.crop.circle"
    @State private var color: FolderColor = .blue

    init(profile: Profile, onSave: @escaping (Profile) -> Void, onCancel: @escaping () -> Void) {
        self.profile = profile
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: profile.name)
        _icon = State(initialValue: profile.icon)
        _color = State(initialValue: profile.color)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Edit Profile")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }

            TextField("Profile Name", text: $name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Icon")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(Profile.presetIcons, id: \.self) { item in
                        Button {
                            icon = item
                        } label: {
                            Image(systemName: item)
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 28, height: 28)
                                .background(icon == item ? color.color.opacity(0.2) : Color.clear)
                                .foregroundColor(icon == item ? color.color : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(icon == item ? color.color : Color.clear, lineWidth: 1.5)
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
                    ForEach(FolderColor.allCases) { item in
                        Button {
                            color = item
                        } label: {
                            Circle()
                                .fill(item.color)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: color == item ? 2 : 0)
                                )
                                .shadow(radius: color == item ? 2 : 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save Changes") {
                    var updated = profile
                    updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? profile.name : name
                    updated.icon = icon
                    updated.color = color
                    onSave(updated)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 380)
    }
}
