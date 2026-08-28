//
//  BangsSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI

struct BangsSettingsSection: View {
    @AppStorage("lotus.browser.bangsEnabled") private var bangsEnabled: Bool = true
    @ObservedObject private var bangsStore = CustomBangsStore.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var isCreatingBang: Bool = false
    @State private var editingBang: CustomBang? = nil
    @State private var bangToDelete: CustomBang? = nil
    @State private var disabledList: [String] = (UserDefaults.standard.stringArray(forKey: "lotus.browser.disabledBangIDs") ?? [])

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    private var allProviders: [SiteSearchProvider] {
        SiteSearchProvider.all
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Master toggle and configured engines card
            SettingsSectionCard(title: "Configured Bangs") {
                VStack(spacing: 0) {
                    // Master enable toggle row
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.orange.gradient)
                                .frame(width: 26, height: 26)

                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Enable Site Search Shortcuts (!bangs)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(foregroundPrimary)

                            Text("Direct site search using triggers like !yt, !gh, !w, !r or custom engines")
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundColor(foregroundSecondary)
                        }

                        Spacer()

                        Toggle("", isOn: $bangsEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)

                    if bangsEnabled {
                        ForEach(Array(allProviders.enumerated()), id: \.element.id) { index, provider in
                            SettingsDivider(leadingInset: 54)
                            providerRow(for: provider)
                        }
                    }
                }
            }

            // Add Custom Bang card
            SettingsSectionCard(title: "Add Custom Bang") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create a Custom Bang")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(foregroundPrimary)

                        Text("Custom search trigger keyword, query URL schema, color and icon")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundColor(foregroundSecondary)
                    }

                    Spacer()

                    Button {
                        isCreatingBang = true
                    } label: {
                        Text("New Bang…")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(!bangsEnabled)
                    .focusable(false)
                    .focusEffectDisabled()
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
            }
        }
        .sheet(isPresented: $isCreatingBang) {
            CustomBangModalView(
                mode: .create,
                onSave: { newBang in
                    bangsStore.addBang(
                        trigger: newBang.cleanTrigger,
                        name: newBang.name,
                        searchURLTemplate: newBang.searchURLTemplate,
                        accentColorHex: newBang.accentColorHex,
                        iconName: newBang.iconName
                    )
                    isCreatingBang = false
                },
                onCancel: {
                    isCreatingBang = false
                }
            )
        }
        .sheet(item: $editingBang) { bang in
            let isCustom = bangsStore.customBangs.contains(where: { $0.id == bang.id })
            CustomBangModalView(
                mode: .edit(bang),
                onSave: { updatedBang in
                    bangsStore.updateBang(updatedBang)
                    editingBang = nil
                },
                onDelete: isCustom ? { toDelete in
                    editingBang = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        bangToDelete = toDelete
                    }
                } : nil,
                onCancel: {
                    editingBang = nil
                }
            )
        }
        .overlay {
            if let bang = bangToDelete {
                DeleteBangConfirmationView(
                    bang: bang,
                    onConfirm: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            bangsStore.removeBang(id: bang.id)
                            bangToDelete = nil
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            bangToDelete = nil
                        }
                    }
                )
                .transition(.opacity)
            }
        }
    }

    // MARK: - Provider Row

    @ViewBuilder
    private func providerRow(for provider: SiteSearchProvider) -> some View {
        let isProviderEnabled = !disabledList.contains(provider.id)
        let customBang = bangsStore.customBangs.first(where: { $0.id.uuidString == provider.id })
        let isCustom = customBang != nil

        HStack(spacing: 12) {
            // Squircle icon badge matching macOS settings style
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(provider.accentColor.gradient)
                    .frame(width: 26, height: 26)

                Image(systemName: provider.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(provider.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(foregroundPrimary)

                    if isCustom {
                        Text("Custom")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(provider.accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(provider.accentColor.opacity(0.14))
                            .clipShape(Capsule())
                    } else {
                        Text("Built-in")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(foregroundSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(provider.triggers.map { "!\($0)" }.joined(separator: ", "))
                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                    .foregroundColor(foregroundSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if let custom = customBang {
                    Button {
                        editingBang = custom
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(foregroundSecondary)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .focusEffectDisabled()
                    .help("Edit Custom Bang")

                    Button {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            bangToDelete = custom
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .focusEffectDisabled()
                    .help("Delete Custom Bang")
                }

                Toggle("", isOn: Binding(
                    get: { isProviderEnabled },
                    set: { enabled in
                        if enabled {
                            disabledList.removeAll(where: { $0 == provider.id })
                        } else {
                            if !disabledList.contains(provider.id) {
                                disabledList.append(provider.id)
                            }
                        }
                        UserDefaults.standard.set(disabledList, forKey: "lotus.browser.disabledBangIDs")
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}
