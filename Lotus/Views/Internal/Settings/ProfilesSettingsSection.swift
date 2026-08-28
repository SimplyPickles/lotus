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
    @State private var isCreatingProfile: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionCard(
                title: "Configured Profiles",
//                footer: "Each profile maintains separate cookies, logins, history, bookmarks, and open tabs."
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(browserState.profiles.enumerated()), id: \.element.id) { index, profile in
                        if index > 0 {
                            SettingsDivider(leadingInset: 54)
                        }
                        profileRow(for: profile)
                    }
                }
            }

            // Create New Profile Card
            SettingsSectionCard(title: "Add Profile") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create a New Profile")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(foregroundPrimary)

                        Text("Separate workspace for work, personal, or client projects")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundColor(foregroundSecondary)
                    }

                    Spacer()

                    Button {
                        isCreatingProfile = true
                    } label: {
                        Text("New Profile…")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .focusable(false)
                    .focusEffectDisabled()
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
            }
        }
        .sheet(isPresented: $isCreatingProfile) {
            CreateProfileModalView(
                onSave: { newName, newIcon, newColor in
                    let created = browserState.createProfile(
                        name: newName,
                        icon: newIcon,
                        color: newColor
                    )
                    browserState.switchProfile(to: created.id)
                    isCreatingProfile = false
                },
                onCancel: {
                    isCreatingProfile = false
                }
            )
        }
        .sheet(item: $editingProfile) { profile in
            EditProfileModalView(
                profile: profile,
                canDelete: browserState.canDeleteProfile(profile),
                onSave: { updated in
                    browserState.updateProfile(updated)
                    editingProfile = nil
                },
                onDelete: { toDelete in
                    editingProfile = nil
                    browserState.requestDeleteProfile(toDelete)
                },
                onCancel: {
                    editingProfile = nil
                }
            )
        }
    }

    // MARK: - Profile Row

    @ViewBuilder
    private func profileRow(for profile: Profile) -> some View {
        let isActive = profile.id == browserState.currentProfileId
        let tabCount = browserState.tabs.filter { ($0.profileId ?? browserState.defaultProfileId) == profile.id }.count

        HStack(spacing: 12) {
            // Squircle icon badge matching macOS settings
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(profile.color.color.gradient)
                    .frame(width: 26, height: 26)

                Image(systemName: profile.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(foregroundPrimary)

                    if profile.isDefault {
                        Text("Default")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(foregroundSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text("\(tabCount) \(tabCount == 1 ? "tab" : "tabs")")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(foregroundSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if isActive {
                    Text("Active Window")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(foregroundSecondary)
                } else {
                    Button("Switch") {
                        browserState.switchProfile(to: profile.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .focusEffectDisabled()
                }

                Button {
                    editingProfile = profile
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.55) : Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
                .help("Profile Details")

                if browserState.canDeleteProfile(profile) {
                    Button {
                        browserState.requestDeleteProfile(profile)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? Color.red.opacity(0.85) : Color.red)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .focusEffectDisabled()
                    .help("Delete Profile")
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .contextMenu {
            if !isActive {
                Button("Switch to \(profile.name)") {
                    browserState.switchProfile(to: profile.id)
                }
            }
            Button("Edit Profile…") {
                editingProfile = profile
            }
            if browserState.canDeleteProfile(profile) {
                Divider()
                Button("Delete Profile…", role: .destructive) {
                    browserState.requestDeleteProfile(profile)
                }
            }
        }
    }
}

// MARK: - Create Profile Modal View

struct CreateProfileModalView: View {
    let onSave: (String, String, FolderColor) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var selectedIcon: String = "person.crop.circle"
    @State private var selectedColor: FolderColor = .blue
    @FocusState private var isNameFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let profileColors: [FolderColor] = [.grey, .blue, .purple, .pink, .red, .orange, .yellow, .green]

    private var activeColor: Color {
        selectedColor == .grey ? (colorScheme == .dark ? .white : .black) : selectedColor.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Create Profile")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)

                Text("Profiles separate your logins, cookies, passwords, extensions, credit cards, history and chat data.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.65) : Color(nsColor: .secondaryLabelColor))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

                TextField("Profile Name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isNameFocused ? activeColor : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)), lineWidth: isNameFocused ? 1.5 : 1)
                    )
                    .focused($isNameFocused)
                    .animation(.easeInOut(duration: 0.16), value: selectedColor)
                    .animation(.easeInOut(duration: 0.16), value: isNameFocused)
            }

            // Icon
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(Profile.presetIcons, id: \.self) { iconName in
                        let isSelected = selectedIcon == iconName

                        Button {
                            selectedIcon = iconName
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isSelected ? activeColor.opacity(colorScheme == .dark ? 0.25 : 0.18) : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))

                                if isSelected {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(activeColor, lineWidth: 1.5)
                                }

                                Image(systemName: iconName)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? activeColor : (colorScheme == .dark ? Color.white.opacity(0.7) : Color.primary.opacity(0.7)))
                            }
                            .frame(height: 32)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                    }
                }
            }

            // Color
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

                HStack(spacing: 7) {
                    ForEach(profileColors) { color in
                        let isSelected = selectedColor == color
                        let dotColor: Color = (color == .grey ? (colorScheme == .dark ? .white : .black) : color.color)

                        Button {
                            selectedColor = color
                        } label: {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .stroke(dotColor, lineWidth: 2)
                                        .frame(width: 32, height: 32)
                                }

                                Circle()
                                    .fill(dotColor)
                                    .frame(width: 24, height: 24)
                            }
                            .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    HStack(spacing: 6) {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary)

                        Text("ESC")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                            )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .focusable(false)
                .focusEffectDisabled()

                Spacer()

                Button {
                    let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !finalName.isEmpty else { return }
                    onSave(finalName, selectedIcon, selectedColor)
                } label: {
                    HStack(spacing: 6) {
                        Text("Create Profile")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? Color.black : Color.white)

                        Image(systemName: "return")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? Color.black.opacity(0.65) : Color.white.opacity(0.85))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark ? Color(white: 0.92) : Color.black)
                    )
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1.0)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .focusable(false)
                .focusEffectDisabled()
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 400)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.14) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1)
        )
        .focusEffectDisabled()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFocused = true
            }
        }
    }
}

// MARK: - Edit Profile Modal View

struct EditProfileModalView: View {
    let profile: Profile
    let canDelete: Bool
    let onSave: (Profile) -> Void
    let onDelete: (Profile) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var selectedIcon: String = "person.crop.circle"
    @State private var selectedColor: FolderColor = .blue
    @FocusState private var isNameFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let profileColors: [FolderColor] = [.grey, .blue, .purple, .pink, .red, .orange, .yellow, .green]

    private var activeColor: Color {
        selectedColor == .grey ? (colorScheme == .dark ? .white : .black) : selectedColor.color
    }

    init(profile: Profile, canDelete: Bool, onSave: @escaping (Profile) -> Void, onDelete: @escaping (Profile) -> Void, onCancel: @escaping () -> Void) {
        self.profile = profile
        self.canDelete = canDelete
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _name = State(initialValue: profile.name)
        _selectedIcon = State(initialValue: profile.icon)
        _selectedColor = State(initialValue: profile.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Profile")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Customize profile name, icon, and theme color.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.65) : Color(nsColor: .secondaryLabelColor))
                }
            }

            // Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

                TextField("Profile Name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isNameFocused ? activeColor : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)), lineWidth: isNameFocused ? 1.5 : 1)
                    )
                    .focused($isNameFocused)
                    .animation(.easeInOut(duration: 0.16), value: selectedColor)
                    .animation(.easeInOut(duration: 0.16), value: isNameFocused)
            }

            // Icon
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(Profile.presetIcons, id: \.self) { iconName in
                        let isSelected = selectedIcon == iconName

                        Button {
                            selectedIcon = iconName
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isSelected ? activeColor.opacity(colorScheme == .dark ? 0.25 : 0.18) : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))

                                if isSelected {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(activeColor, lineWidth: 1.5)
                                }

                                Image(systemName: iconName)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? activeColor : (colorScheme == .dark ? Color.white.opacity(0.7) : Color.primary.opacity(0.7)))
                            }
                            .frame(height: 32)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                    }
                }
            }

            // Color
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

                HStack(spacing: 7) {
                    ForEach(profileColors) { color in
                        let isSelected = selectedColor == color
                        let dotColor: Color = (color == .grey ? (colorScheme == .dark ? .white : .black) : color.color)

                        Button {
                            selectedColor = color
                        } label: {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .stroke(dotColor, lineWidth: 2)
                                        .frame(width: 32, height: 32)
                                }

                                Circle()
                                    .fill(dotColor)
                                    .frame(width: 24, height: 24)
                            }
                            .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    HStack(spacing: 6) {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary)

                        Text("ESC")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                            )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .focusable(false)
                .focusEffectDisabled()

                Spacer()

                Button {
                    var updated = profile
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.name = trimmed.isEmpty ? profile.name : trimmed
                    updated.icon = selectedIcon
                    updated.color = selectedColor
                    onSave(updated)
                } label: {
                    HStack(spacing: 6) {
                        Text("Save Changes")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? Color.black : Color.white)

                        Image(systemName: "return")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? Color.black.opacity(0.65) : Color.white.opacity(0.85))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark ? Color(white: 0.92) : Color.black)
                    )
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1.0)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .focusable(false)
                .focusEffectDisabled()
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 400)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.14) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1)
        )
        .focusEffectDisabled()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFocused = true
            }
        }
    }
}
