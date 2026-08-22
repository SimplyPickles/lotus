//
//  LotusNewTabView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

struct LotusNewTabView: View {
    @ObservedObject var browserState: BrowserState
    @StateObject private var suggestionService = SearchSuggestionService()
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isHovered: Bool = false
    @State private var isHoveringSuggestions: Bool = false
    @State private var selectedIndex: Int? = nil
    @State private var hoveredIndex: Int? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    private var foregroundPlaceholder: Color {
        colorScheme == .dark ? .white.opacity(0.40) : Color(nsColor: .placeholderTextColor)
    }

    private var searchFieldFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }

    private var dropdownFill: Color {
        searchFieldFill
    }

    private var searchFieldStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
    }

    private var pageBackground: Color {
        Color.clear
    }

    private var hasActiveSuggestions: Bool {
        (isSearchFocused || isHoveringSuggestions) && !suggestionService.suggestions.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button {
                browserState.toggleSidebar()
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .regular))
                    .transaction { $0.animation = nil }
            }
            .buttonStyle(BrowserToolbarButtonStyle(isLight: colorScheme == .light, hasCustomTheme: false))
            .padding(.leading, 7)
            .padding(.top, 7)
            .keyboardShortcut("s", modifiers: .command)
            .zIndex(1)
            .focusable(false)

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "camera.macro")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.white, Color.white.opacity(0.5)]
                                : [Color(nsColor: .labelColor), Color(nsColor: .labelColor).opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.bottom, 12)
                    .padding(.top, -24)
                    .transaction { $0.animation = nil }

                // Search Bar Container
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(foregroundSecondary)
                        .padding(.leading, -4)
                        .transaction { $0.animation = nil }

                    TextField(
                        "",
                        text: $searchText,
                        prompt: Text("Search the web or type a URL").foregroundColor(foregroundPlaceholder)
                    )
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(foregroundPrimary)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        if let selected = selectedIndex, suggestionService.suggestions.indices.contains(selected) {
                            submitSearch(with: suggestionService.suggestions[selected].text)
                        } else {
                            submitSearch()
                        }
                    }
                    .onKeyPress(.downArrow) {
                        guard !suggestionService.suggestions.isEmpty else { return .ignored }
                        if let current = selectedIndex {
                            selectedIndex = min(current + 1, suggestionService.suggestions.count - 1)
                        } else {
                            selectedIndex = 0
                        }
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        guard !suggestionService.suggestions.isEmpty else { return .ignored }
                        if let current = selectedIndex {
                            if current == 0 {
                                selectedIndex = nil
                            } else {
                                selectedIndex = current - 1
                            }
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(.rightArrow) {
                        if let current = selectedIndex, suggestionService.suggestions.indices.contains(current) {
                            searchText = suggestionService.suggestions[current].text
                            selectedIndex = nil
                            focusSearchField()
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(.escape) {
                        if hasActiveSuggestions || selectedIndex != nil {
                            suggestionService.clear()
                            selectedIndex = nil
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(.tab) {
                        if let current = selectedIndex, suggestionService.suggestions.indices.contains(current) {
                            searchText = suggestionService.suggestions[current].text
                            selectedIndex = nil
                            focusSearchField()
                            return .handled
                        } else if let first = suggestionService.suggestions.first {
                            searchText = first.text
                            selectedIndex = nil
                            focusSearchField()
                            return .handled
                        }
                        return .ignored
                    }

                    // Return Button - always structurally present to preserve focus and layout stability
                    Button {
                        if let selected = selectedIndex, suggestionService.suggestions.indices.contains(selected) {
                            submitSearch(with: suggestionService.suggestions[selected].text)
                        } else {
                            submitSearch()
                        }
                    } label: {
                        Image(systemName: "return")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .black.opacity(0.75) : .white)
                            .frame(width: 5, height: 5)
                            .padding(9)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white : Color.accentColor)
                            )
                            .padding(.trailing, -6)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .frame(height: 0)
                    .opacity(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
                    .allowsHitTesting(!searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: 520)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(searchFieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(searchFieldStroke, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    focusSearchField()
                }
                .overlay(alignment: .top) {
                    if hasActiveSuggestions {
                        VStack(spacing: 2) {
                            ForEach(Array(suggestionService.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                                suggestionRow(suggestion, index: index)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .frame(maxWidth: 520)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(dropdownFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(searchFieldStroke, lineWidth: 1)
                        )
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.1),
                            radius: 16,
                            x: 0,
                            y: 8
                        )
                        .offset(y: 54)
                        .onHover { hovering in
                            isHoveringSuggestions = hovering
                        }
                    }
                }
                .zIndex(10)
                .onChange(of: searchText) { _, newValue in
                    browserState.newTabSearchText[browserState.selectedTabId] = newValue
                    selectedIndex = nil
                    suggestionService.update(for: newValue)
                }
                .onChange(of: browserState.selectedTabId) { _, newTabId in
                    let saved = browserState.newTabSearchText[newTabId] ?? ""
                    if searchText != saved {
                        searchText = saved
                    }
                    selectedIndex = nil
                    suggestionService.update(for: saved)
                    focusSearchField()
                }
                .onHover { hovering in
                    isHovered = hovering
                }
                .onAppear {
                    let saved = browserState.newTabSearchText[browserState.selectedTabId] ?? ""
                    if searchText != saved {
                        searchText = saved
                    }
                    suggestionService.update(for: saved)
                    focusSearchField()
                }

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                focusSearchField()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageBackground)
        .transaction { $0.animation = nil }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            focusSearchField()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            focusSearchField()
        }
        .background {
            Button("") {
                focusSearchField()
            }
            .keyboardShortcut("l", modifiers: .command)
            .opacity(0)
            .focusable(false)
        }
    }

    private func focusSearchField() {
        if !isSearchFocused {
            isSearchFocused = true
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
    }

    @ViewBuilder
    private func suggestionRow(_ suggestion: SearchSuggestion, index: Int) -> some View {
        let isSelected = selectedIndex == index
        let isRowHovered = hoveredIndex == index

        Button {
            submitSearch(with: suggestion.text)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: suggestion.isURL ? "globe" : "magnifyingglass")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(isSelected ? foregroundPrimary : foregroundSecondary)
                    .frame(width: 16)
                    .transaction { $0.animation = nil }

                Text(suggestion.text)
                    .font(.system(size: 13.5, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? foregroundPrimary : foregroundPrimary.opacity(0.88))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                if suggestion.isURL {
                    Text("Jump to URL")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(foregroundSecondary.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? (colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08))
                            : (isRowHovered ? (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                hoveredIndex = index
            } else if hoveredIndex == index {
                hoveredIndex = nil
            }
        }
    }

    private func submitSearch(with text: String? = nil) {
        let trimmed = (text ?? searchText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        suggestionService.clear()
        selectedIndex = nil
        isHoveringSuggestions = false
        browserState.navigateActiveTab(to: trimmed)
    }
}
