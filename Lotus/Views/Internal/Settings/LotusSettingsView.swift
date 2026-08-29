//
//  LotusSettingsView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct LotusSettingsView: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    var initialCategory: SettingsCategory = .general
    @ObservedObject private var contentBlocker = ContentBlockerService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory: SettingsCategory
    @AppStorage("lotus.browser.accentColor") private var accentColorKey: String = "white"

    init(browserState: BrowserState, tabId: UUID? = nil, initialCategory: SettingsCategory = .general) {
        self.browserState = browserState
        self.tabId = tabId
        self.initialCategory = initialCategory
        _selectedCategory = State(initialValue: initialCategory)
    }

    private var activeAccentColor: Color {
        if !browserState.isPrivate {
            if browserState.currentProfile.color == .grey {
                return Color(nsColor: .controlAccentColor)
            }
            return browserState.currentProfile.color.color
        }
        let accent = LotusAccentColor(rawValue: accentColorKey) ?? .white
        return accent.color
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left Sidebar Navigation
            VStack(spacing: 0) {
                // Category List
                ScrollView(.vertical, showsIndicators: false) {
                    Spacer()
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(SettingsCategoryGroup.allCases) { group in
                            let categoriesInGroup = SettingsCategory.allCases.filter { $0.group == group }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.38) : Color.black.opacity(0.42))
                                    .padding(.leading, 8)
                                    .padding(.bottom, 2)

                                ForEach(categoriesInGroup) { category in
                                    SettingsSidebarItem(
                                        category: category,
                                        isSelected: selectedCategory == category,
                                        accentColor: activeAccentColor,
                                        onSelect: {
                                            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                                                selectedCategory = category
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 0)
                    .padding(.bottom, 20)
                }

                Spacer(minLength: 0)
            }
            .frame(width: 215)
            .background(
                colorScheme == .dark
                    ? Color.black.opacity(0.20)
                    : Color.black.opacity(0.04)
            )

            // Vertical Divider
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                .frame(width: 0.5)

            // MARK: - Right Detail Content Area
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header for active category
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedCategory.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(foregroundPrimary)

                        Text(selectedCategory.subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(foregroundSecondary)
                    }
                    .padding(.top, 48)
                    .padding(.bottom, 2)

                    // Active Section View
                    switch selectedCategory {
                    case .general:
                        GeneralSettingsSection()
                    case .appearance:
                        AppearanceSettingsSection(browserState: browserState)
                    case .profiles:
                        ProfilesSettingsSection(browserState: browserState, tabId: tabId)
                    case .bangs:
                        BangsSettingsSection(browserState: browserState)
                    case .scripts:
                        ScriptsSettingsSection(browserState: browserState)
                    case .tabs:
                        TabsSettingsSection(browserState: browserState)
                    case .media:
                        MediaSettingsSection(browserState: browserState)
                    case .shields:
                        ShieldsSettingsSection(contentBlocker: contentBlocker)
                    case .privacy:
                        PrivacySettingsSection(browserState: browserState, tabId: tabId, contentBlocker: contentBlocker)
                    case .downloads:
                        DownloadsSettingsSection(browserState: browserState, tabId: tabId)
                    case .shortcuts:
                        ShortcutsSettingsSection(browserState: browserState, tabId: tabId)
                    case .about:
                        AboutSettingsSection(browserState: browserState)
                    }

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, 36)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .tint(activeAccentColor)
        .accentColor(activeAccentColor)
        .background(Color.clear)
        .focusEffectDisabled()
        .transaction { $0.animation = nil }
    }
}
