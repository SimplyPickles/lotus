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
        SettingsSectionCard(title: SettingsCategory.general.rawValue, systemImage: SettingsCategory.general.systemImage) {
            StartupBehaviorSettingsRow(startupBehavior: $startupBehavior)
            SettingsDivider()
            WarnOnQuitSettingsRow()
            SettingsDivider()
            SearchEngineSettingsRow(searchEngine: $searchEngine)
            SettingsDivider()
            SearchSuggestionsSettingsRow(searchSuggestionsEnabled: $searchSuggestionsEnabled)
            SettingsDivider()
            BangsSettingsRow(bangsEnabled: $bangsEnabled)
        }
    }
}

// MARK: - Rows

private struct WarnOnQuitSettingsRow: View {
    @AppStorage("lotus.browser.warnOnQuit") private var warnOnQuit: Bool = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Warn before quitting")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Prompt for confirmation when closing Lotus (⌘Q)")
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
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("On startup", selection: $startupBehavior) {
                Text("Restore previous session").tag("restore")
                Text("Open command palette").tag("empty")
                Text("Open pinned tabs only").tag("pinnedOnly")
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 190, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct SearchEngineSettingsRow: View {
    @Binding var searchEngine: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Search engine")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Picker("Search engine", selection: $searchEngine) {
                ForEach(URLInputResolver.SearchEngine.allCases, id: \.rawValue) { engine in
                    Text(engine.displayName).tag(engine.rawValue)
                }
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
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
    @State private var newBangName: String = ""
    @State private var newBangTrigger: String = ""
    @State private var newBangURLTemplate: String = ""
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
                    Divider()
                        .overlay(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                        .padding(.horizontal, 14)

                    HStack {
                        Text("Configured Engines")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            newBangName = ""
                            newBangTrigger = ""
                            newBangURLTemplate = ""
                            isAddSheetPresented = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Add Custom Bang")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    VStack(spacing: 2) {
                        ForEach(allProviders) { provider in
                            let isProviderEnabled = !disabledList.contains(provider.id)
                            let isCustom = bangsStore.customBangs.contains(where: { $0.id.uuidString == provider.id })
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
                                    .padding(.trailing, 8)

                                if isCustom {
                                    Button {
                                        if let customBang = bangsStore.customBangs.first(where: { $0.id.uuidString == provider.id }) {
                                            bangsStore.removeBang(id: customBang.id)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 4)
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
            VStack(alignment: .leading, spacing: 16) {
                Text("Add Custom Search Bang")
                    .font(.system(size: 16, weight: .semibold))

                Text("Enter a search engine name, trigger keyword (without !), and URL template with {searchTerms}.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name (e.g. GitHub)", text: $newBangName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Trigger (e.g. gh)", text: $newBangTrigger)
                        .textFieldStyle(.roundedBorder)

                    TextField("Search URL (e.g. https://github.com/search?q={searchTerms})", text: $newBangURLTemplate)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button("Cancel") {
                        isAddSheetPresented = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Add Bang") {
                        let cleanName = newBangName.trimmingCharacters(in: .whitespaces)
                        let cleanTrigger = newBangTrigger.trimmingCharacters(in: CharacterSet(charactersIn: "!").union(.whitespaces))
                        let cleanURL = newBangURLTemplate.trimmingCharacters(in: .whitespaces)
                        guard !cleanName.isEmpty, !cleanTrigger.isEmpty, !cleanURL.isEmpty else { return }

                        bangsStore.addBang(trigger: cleanTrigger, name: cleanName, searchURLTemplate: cleanURL)
                        isAddSheetPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newBangName.isEmpty || newBangTrigger.isEmpty || newBangURLTemplate.isEmpty)
                }
            }
            .padding(20)
            .frame(width: 420)
        }
    }
}
