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
    @ObservedObject private var contentBlocker = ContentBlockerService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory: SettingsCategory = .general

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 28) {
                headerSection
                    .padding(.top, 40)
                    .padding(.bottom, -4)

                switch selectedCategory {
                case .general:
                    GeneralSettingsSection()
                case .appearance:
                    AppearanceSettingsSection()
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
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Color.clear)
        .transaction { $0.animation = nil }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "gearshape")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(foregroundPrimary)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Settings")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(foregroundPrimary)

                    Text("Customize Lotus preferences & behaviors")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(foregroundSecondary)
                }

                Spacer()
            }

            // Category Filter Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SettingsCategory.allCases) { category in
                        SettingsCategoryPill(
                            category: category,
                            isSelected: selectedCategory == category,
                            action: {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                                    selectedCategory = category
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
