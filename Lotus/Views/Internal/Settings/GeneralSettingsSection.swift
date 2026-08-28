//
//  GeneralSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct GeneralSettingsSection: View {
    @AppStorage("lotus.browser.startupBehavior") private var startupBehavior: String = "restore"
    @AppStorage("lotus.browser.searchEngine") private var searchEngine: String = "google"
    @AppStorage("lotus.browser.searchSuggestionsEnabled") private var searchSuggestionsEnabled: Bool = true
    @AppStorage("lotus.browser.bangsEnabled") private var bangsEnabled: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            SettingsSectionCard(title: "System & Startup") {
                DefaultBrowserSettingsRow()
                SettingsDivider()
                StartupBehaviorSettingsRow(startupBehavior: $startupBehavior)
                SettingsDivider()
                WarnOnQuitSettingsRow()
            }

            SettingsSectionCard(
                title: "Default Search Engine",
                footer: "Search engine used when entering search queries into the address bar or command palette."
            ) {
                SearchEngineSettingsRow(searchEngine: $searchEngine)
                SettingsDivider()
                SearchSuggestionsSettingsRow(searchSuggestionsEnabled: $searchSuggestionsEnabled)
            }

            SettingsSectionCard(
                title: "Site Search Shortcuts",
//                footer: "Type a prefix like !w, !gh, or !yt followed by your search query to search directly on that website."
            ) {
                BangsSettingsRow(bangsEnabled: $bangsEnabled)
            }
        }
    }
}

// MARK: - Rows

private struct DefaultBrowserSettingsRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDefault: Bool = false

    private func checkDefaultStatus() {
        if let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://apple.com")!) {
            let bundleId = Bundle.main.bundleIdentifier ?? "com.dylanfraser.Lotus"
            let defaultBundleId = Bundle(url: defaultAppURL)?.bundleIdentifier
            isDefault = (defaultBundleId == bundleId)
        } else {
            isDefault = false
        }
    }

    private func setAsDefault() {
        if #available(macOS 12.0, *) {
            let appURL = Bundle.main.bundleURL
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "http") { _ in
                DispatchQueue.main.async { checkDefaultStatus() }
            }
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "https") { _ in
                DispatchQueue.main.async { checkDefaultStatus() }
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.general") {
            NSWorkspace.shared.open(url)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkDefaultStatus()
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Default web browser")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text(isDefault ? "Lotus is currently your default web browser" : "Set Lotus as your default browser for opening web links")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            if isDefault {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Default")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            } else {
                Button("Set as Default…") {
                    setAsDefault()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(width: 140, height: 28, alignment: .trailing)
                .focusable(false)
                .focusEffectDisabled()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .onAppear(perform: checkDefaultStatus)
    }
}

private struct WarnOnQuitSettingsRow: View {
    @AppStorage("lotus.browser.warnOnQuit") private var warnOnQuit: Bool = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Warn before quitting")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Show a confirmation prompt when pressing ⌘Q")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Warn before quitting", isOn: Binding(
                get: { warnOnQuit },
                set: { newValue in
                    warnOnQuit = newValue
                    UserDefaults.standard.set(!newValue, forKey: BrowserState.alwaysQuitKey)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct StartupBehaviorSettingsRow: View {
    @Binding var startupBehavior: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "power")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("On startup")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Choose how Lotus opens when launched")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("On startup", selection: $startupBehavior) {
                Text("Restore Session").tag("restore")
                Text("Command Palette").tag("empty")
                Text("Pinned Only").tag("pinnedOnly")
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 170, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct SearchEngineSettingsRow: View {
    @Binding var searchEngine: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false
    @State private var isAddSheetPresented: Bool = false
    @State private var newEngineName: String = ""
    @State private var newEngineShortcut: String = ""
    @State private var newEngineURLTemplate: String = ""
    @ObservedObject private var engineStore = CustomSearchEnginesStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Search engine")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text("Default search engine for URL bar and command palette")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer()

                Text(engineStore.engineName(for: searchEngine))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                VStack(spacing: 8) {
                    SettingsDivider(leadingInset: 14)

                    HStack {
                        Text("Configured Engines")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            newEngineName = ""
                            newEngineShortcut = ""
                            newEngineURLTemplate = ""
                            isAddSheetPresented = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Add Custom Engine")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    VStack(spacing: 2) {
                        ForEach(engineStore.allEngines) { engine in
                            let isSelected = searchEngine.lowercased() == engine.id.lowercased()
                            HStack(spacing: 10) {
                                Image(systemName: engine.iconName)
                                    .font(.system(size: 12))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .secondary)
                                    .frame(width: 18)

                                Text(engine.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .primary)

                                if let shortcut = engine.shortcut, !shortcut.isEmpty {
                                    Text("(\(shortcut))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.40) : .secondary)
                                }

                                Spacer()

                                Text(engine.displayURL)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.40) : .secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(.trailing, 8)

                                if engine.isCustom, let customId = engine.customId {
                                    Button {
                                        if searchEngine == engine.id {
                                            searchEngine = "google"
                                        }
                                        engineStore.removeEngine(id: customId)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                    .focusable(false)
                                    .focusEffectDisabled()
                                    .padding(.trailing, 4)
                                    .help("Delete Custom Search Engine")
                                }

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundColor(Color.accentColor)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                searchEngine = engine.id
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
        .sheet(isPresented: $isAddSheetPresented) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add Custom Search Engine")
                    .font(.system(size: 16, weight: .semibold))

                Text("Enter a search engine name, optional shortcut (for !bangs), and URL template with {searchTerms} (or %s).")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name (e.g. Perplexity)", text: $newEngineName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Shortcut (optional, e.g. px)", text: $newEngineShortcut)
                        .textFieldStyle(.roundedBorder)

                    TextField("Search URL (e.g. https://www.perplexity.ai/search?q={searchTerms})", text: $newEngineURLTemplate)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button("Cancel") {
                        isAddSheetPresented = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Add Engine") {
                        let cleanName = newEngineName.trimmingCharacters(in: .whitespaces)
                        let cleanShortcut = newEngineShortcut.trimmingCharacters(in: CharacterSet(charactersIn: "!").union(.whitespaces))
                        let cleanURL = newEngineURLTemplate.trimmingCharacters(in: .whitespaces)
                        guard !cleanName.isEmpty, !cleanURL.isEmpty else { return }

                        engineStore.addEngine(
                            name: cleanName,
                            searchURLTemplate: cleanURL,
                            shortcut: cleanShortcut.isEmpty ? nil : cleanShortcut
                        )
                        isAddSheetPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newEngineName.trimmingCharacters(in: .whitespaces).isEmpty || newEngineURLTemplate.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 420)
        }
    }
}

private struct SearchSuggestionsSettingsRow: View {
    @Binding var searchSuggestionsEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Search suggestions")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Show live completions from search engine in command palette")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Search suggestions", isOn: $searchSuggestionsEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct BangsSettingsRow: View {
    @Binding var bangsEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false
    @State private var isAddSheetPresented: Bool = false
    @State private var editingBang: CustomBang? = nil
    @State private var disabledList: [String] = (UserDefaults.standard.stringArray(forKey: "lotus.browser.disabledBangIDs") ?? [])
    @ObservedObject private var bangsStore = CustomBangsStore.shared

    private var allProviders: [SiteSearchProvider] {
        SiteSearchProvider.all
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Site search shortcuts (!bangs)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text("Direct site search using prefixes like !yt, !gh, !w, !r or custom engines")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
                .disabled(!bangsEnabled)
                .opacity(bangsEnabled ? 1.0 : 0.45)
                
                Toggle("Site search shortcuts (!bangs)", isOn: $bangsEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)

            if isExpanded && bangsEnabled {
                VStack(spacing: 8) {
                    SettingsDivider(leadingInset: 14)

                    HStack {
                        Text("Configured Engines")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            isAddSheetPresented = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Add Custom Bang")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    VStack(spacing: 2) {
                        ForEach(allProviders) { provider in
                            let isProviderEnabled = !disabledList.contains(provider.id)
                            let customBang = bangsStore.customBangs.first(where: { $0.id.uuidString == provider.id })
                            let isCustom = customBang != nil
                            HStack(spacing: 10) {
                                Image(systemName: provider.iconName)
                                    .font(.system(size: 12))
                                    .foregroundColor(provider.accentColor)
                                    .frame(width: 18)

                                Text(provider.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .primary)

                                Spacer()

                                Text(provider.triggers.map { "!\($0)" }.joined(separator: ", "))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.40) : .secondary)
                                    .padding(.trailing, isCustom ? 4 : 8)

                                if let custom = customBang {
                                    Button {
                                        editingBang = custom
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                                            .padding(4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .focusable(false)
                                    .focusEffectDisabled()
                                    .help("Edit Custom Bang")

                                    Button {
                                        bangsStore.removeBang(id: custom.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.red.opacity(0.8))
                                            .padding(4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                    .fill(Color.red.opacity(colorScheme == .dark ? 0.15 : 0.08))
                                            )
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
                                .controlSize(.mini)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
        .sheet(isPresented: $isAddSheetPresented) {
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
                    isAddSheetPresented = false
                },
                onCancel: {
                    isAddSheetPresented = false
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
                onDelete: isCustom ? { bangToDelete in
                    bangsStore.removeBang(id: bangToDelete.id)
                    editingBang = nil
                } : nil,
                onCancel: {
                    editingBang = nil
                }
            )
        }
    }
}
