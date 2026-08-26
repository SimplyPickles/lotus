//
//  ProfileSwitcherView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import SwiftUI
import AppKit

struct ProfileSwitcherView: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false
    @State private var isCreateProfileSheetPresented: Bool = false
    @State private var newProfileName: String = ""
    @State private var selectedIcon: String = "person.crop.circle"
    @State private var selectedColor: FolderColor = .blue

    private var profile: Profile {
        browserState.currentProfile
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.55) : Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        Menu {
            // Profile list
            Section("Switch Profile") {
                ForEach(browserState.profiles) { p in
                    Button {
                        browserState.switchProfile(to: p.id)
                    } label: {
                        HStack {
                            Text(p.name)
                            if p.id == browserState.currentProfileId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Button {
                isCreateProfileSheetPresented = true
            } label: {
                Label("New Profile…", systemImage: "plus")
            }

            Button {
                browserState.openSettingsPage()
            } label: {
                Label("Manage Profiles…", systemImage: "gearshape")
            }
        } label: {
            HStack(spacing: 4) {
                Text(profile.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(foregroundPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isHovered {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(foregroundSecondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? (colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .focusable(false)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .sheet(isPresented: $isCreateProfileSheetPresented) {
            createProfileSheet
        }
    }

    // MARK: - Create Profile Sheet

    private var createProfileSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Create New Profile")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }

            TextField("Profile Name (e.g. Work, School)", text: $newProfileName)
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
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .medium))
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
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                                )
                                .shadow(radius: selectedColor == color ? 2 : 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    isCreateProfileSheetPresented = false
                    newProfileName = ""
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Profile") {
                    let created = browserState.createProfile(
                        name: newProfileName,
                        icon: selectedIcon,
                        color: selectedColor
                    )
                    browserState.switchProfile(to: created.id)
                    isCreateProfileSheetPresented = false
                    newProfileName = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 380)
    }
}
