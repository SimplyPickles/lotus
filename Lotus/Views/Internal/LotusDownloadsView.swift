//
//  LotusDownloadsView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import AppKit

// MARK: - Models

struct DownloadSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [DownloadItem]
}

enum DownloadConfirmationType: Equatable {
    case clearAll(totalCount: Int)
    case deleteSelected(ids: Set<UUID>)
}

// MARK: - Date Formatting

private enum DownloadDateFormatter {
    private static let dayFormatterSameYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    private static let dayFormatterDifferentYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static func dayLabel(for date: Date, relativeTo referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let currentYear = calendar.component(.year, from: referenceDate)
            let dateYear = calendar.component(.year, from: date)
            if dateYear == currentYear {
                return dayFormatterSameYear.string(from: date)
            } else {
                return dayFormatterDifferentYear.string(from: date)
            }
        }
    }

    static func relativeTime(for date: Date, relativeTo referenceDate: Date = Date()) -> String {
        let interval = referenceDate.timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = max(1, Int(interval / 60))
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = max(1, Int(interval / 3600))
            return "\(hours)h ago"
        } else {
            return timeFormatter.string(from: date)
        }
    }
}

// MARK: - Grouping Helper

private enum DownloadGrouping {
    static func filterAndGroup(
        from entries: [DownloadItem],
        query: String,
        limit: Int
    ) -> (sections: [DownloadSection], totalFilteredCount: Int) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [DownloadItem]
        if trimmed.isEmpty {
            filtered = entries
        } else {
            filtered = entries.filter {
                $0.filename.localizedCaseInsensitiveContains(trimmed) ||
                $0.originalURL.absoluteString.localizedCaseInsensitiveContains(trimmed) ||
                ($0.displayHost?.localizedCaseInsensitiveContains(trimmed) == true)
            }
        }

        let totalCount = filtered.count
        guard totalCount > 0 else {
            return (sections: [], totalFilteredCount: 0)
        }

        let sorted = filtered.sorted { $0.startedAt > $1.startedAt }
        let windowed = Array(sorted.prefix(limit))

        let calendar = Calendar.current
        let now = Date()

        var dayMap: [Date: [DownloadItem]] = [:]
        for item in windowed {
            let day = calendar.startOfDay(for: item.startedAt)
            dayMap[day, default: []].append(item)
        }

        let sortedDays = dayMap.keys.sorted(by: >)
        var sections: [DownloadSection] = []

        for day in sortedDays {
            guard let itemsInDay = dayMap[day], !itemsInDay.isEmpty else { continue }
            let dayTitle = DownloadDateFormatter.dayLabel(for: day, relativeTo: now, calendar: calendar)
            sections.append(DownloadSection(
                id: "\(day.timeIntervalSinceReferenceDate)",
                title: dayTitle,
                items: itemsInDay
            ))
        }

        return (sections: sections, totalFilteredCount: totalCount)
    }
}

// MARK: - Main View

struct LotusDownloadsView: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    @State private var searchText: String = ""
    @State private var selectedIds: Set<UUID> = []
    @State private var selectionAnchorId: UUID?
    @State private var sections: [DownloadSection] = []
    @State private var totalFilteredCount: Int = 0
    @State private var displayLimit: Int = 60
    @State private var confirmationType: DownloadConfirmationType? = nil
    @State private var isHoveringCancel: Bool = false
    @State private var isHoveringConfirm: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var activeTabId: UUID {
        tabId ?? browserState.selectedTabId
    }

    private var isSelecting: Bool {
        !selectedIds.isEmpty
    }

    // MARK: - Colors

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    private var foregroundPlaceholder: Color {
        colorScheme == .dark ? .white.opacity(0.40) : Color(nsColor: .placeholderTextColor)
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
    }

    private var separatorColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 26) {
                    headerSection
                        .padding(.top, 40)
                        .padding(.bottom, -4)

                    if sections.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    } else {
                        ForEach(sections) { section in
                            daySection(section)
                        }

                        if totalFilteredCount > displayLimit {
                            Color.clear
                                .frame(height: 32)
                                .onAppear {
                                    displayLimit += 60
                                    refreshSections()
                                }
                        }

                        Spacer(minLength: 40)
                    }
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .focusEffectDisabled()
        .transaction { $0.animation = nil }
        .overlay {
            if let confirmation = confirmationType {
                confirmationOverlay(confirmation)
            }
        }
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: confirmationType != nil)
        .onAppear {
            refreshSections()
        }
        .onChange(of: browserState.downloads) { _, entries in
            let valid = Set(entries.map { $0.id })
            selectedIds = selectedIds.intersection(valid)
            refreshSections()
        }
        .onChange(of: browserState.currentProfileId) { _, _ in
            refreshSections()
        }
        .onChange(of: searchText) { _, _ in
            displayLimit = 60
            refreshSections()
        }
        .onDeleteCommand {
            guard !selectedIds.isEmpty else { return }
            confirmationType = .deleteSelected(ids: selectedIds)
        }
        .background {
            DeleteKeyMonitor {
                guard !selectedIds.isEmpty else { return }
                confirmationType = .deleteSelected(ids: selectedIds)
            }
            .frame(width: 0, height: 0)
        }
    }

    private var activeProfileId: UUID {
        if let tabId = tabId, let tab = browserState.tab(for: tabId) {
            return tab.profileId ?? browserState.defaultProfileId
        }
        return browserState.currentProfileId
    }

    private func refreshSections() {
        let result = DownloadGrouping.filterAndGroup(
            from: browserState.downloads(for: activeProfileId),
            query: searchText,
            limit: displayLimit
        )
        sections = result.sections
        totalFilteredCount = result.totalFilteredCount
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(foregroundPrimary)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Downloads")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(foregroundPrimary)

                    Text("\(browserState.downloads(for: activeProfileId).count) files")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(foregroundSecondary)
                }

                Spacer()

                if isSelecting {
                    DownloadHeaderActionButton(
                        title: "Delete \(selectedIds.count)",
                        systemImage: "trash",
                        isDestructive: true
                    ) {
                        confirmationType = .deleteSelected(ids: selectedIds)
                    }

                    DownloadHeaderActionButton(title: "Cancel", systemImage: nil, isDestructive: false) {
                        selectedIds.removeAll()
                    }
                } else if !browserState.downloads(for: activeProfileId).isEmpty {
                    DownloadHeaderActionButton(title: "Clear All", systemImage: nil, isDestructive: false) {
                        confirmationType = .clearAll(totalCount: browserState.downloads(for: activeProfileId).count)
                    }
                }
            }

            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(foregroundSecondary)

                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search downloads").foregroundColor(foregroundPlaceholder)
                )
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(foregroundPrimary)
                .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(foregroundSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
        }
    }

    // MARK: - Day Section

    private func daySection(_ section: DownloadSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(foregroundSecondary)
                .padding(.leading, 14)

            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    DownloadRowView(
                        item: item,
                        isAlternate: index % 2 == 1,
                        isSelected: selectedIds.contains(item.id),
                        isSelecting: isSelecting,
                        onToggleSelect: { toggleSelection(item.id) },
                        onClick: {
                            if NSEvent.modifierFlags.contains(.shift) {
                                selectRange(to: item.id)
                            } else if isSelecting {
                                toggleSelection(item.id)
                            } else {
                                item.openFile()
                            }
                        },
                        onDelete: {
                            confirmationType = .deleteSelected(ids: [item.id])
                        },
                        onCancel: {
                            browserState.cancelDownload(id: item.id)
                        },
                        onPause: {
                            browserState.pauseDownload(id: item.id)
                        },
                        onResume: {
                            browserState.resumeDownload(id: item.id)
                        },
                        onRetry: {
                            browserState.retryDownload(id: item.id)
                        }
                    )

                    if index < section.items.count - 1 {
                        Rectangle()
                            .fill(separatorColor)
                            .frame(height: 1)
                            .padding(.leading, 46)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Selection

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
        selectionAnchorId = id
    }

    private func selectRange(to id: UUID) {
        let orderedItems = sections.flatMap(\.items)
        guard let targetIndex = orderedItems.firstIndex(where: { $0.id == id }) else { return }

        guard let anchorId = selectionAnchorId,
              let anchorIndex = orderedItems.firstIndex(where: { $0.id == anchorId }) else {
            selectedIds = [id]
            selectionAnchorId = id
            return
        }

        let range = orderedItems[min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)]
        selectedIds = Set(range.map(\.id))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(foregroundSecondary.opacity(0.5))

            if searchText.isEmpty {
                Text("No downloads")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(foregroundSecondary)

                Text("Files you download will appear here")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(foregroundSecondary.opacity(0.7))
            } else {
                Text("No results found")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(foregroundSecondary)

                Text("Try a different search term")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(foregroundSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Confirmation Sheet

    @ViewBuilder
    private func confirmationOverlay(_ confirmation: DownloadConfirmationType) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    confirmationType = nil
                }

            VStack(alignment: .leading, spacing: 0) {
                // Icon squircle
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.45, blue: 0.45),
                                    Color(red: 0.92, green: 0.20, blue: 0.20),
                                    Color(red: 0.85, green: 0.08, blue: 0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 5, y: 2)

                    Image(systemName: "trash.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                }
                .padding(.bottom, 14)

                // Title
                Text(confirmationTitle(for: confirmation))
                    .font(.system(size: 18.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 6)

                // Subtitle
                Text(confirmationSubtitle(for: confirmation))
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.bottom, 22)

                // Buttons row
                HStack(spacing: 8) {
                    Spacer(minLength: 12)

                    // Cancel button
                    Button {
                        confirmationType = nil
                    } label: {
                        HStack(spacing: 6) {
                            Text("Cancel")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)

                            Text("ESC")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.55))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isHoveringCancel ? Color.white.opacity(0.18) : Color.white.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    .onHover { isHoveringCancel = $0 }

                    // Confirm / Delete button
                    Button {
                        switch confirmation {
                        case .clearAll:
                            browserState.clearAllDownloads(for: activeProfileId)
                            selectedIds.removeAll()
                        case .deleteSelected(let ids):
                            browserState.removeDownloads(ids: ids)
                            selectedIds.subtract(ids)
                        }
                        confirmationType = nil
                    } label: {
                        HStack(spacing: 5) {
                            Text(confirmationButtonTitle(for: confirmation))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)

                            Image(systemName: "return")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isHoveringConfirm ? Color(red: 0.98, green: 0.15, blue: 0.15) : Color(red: 0.90, green: 0.05, blue: 0.05))
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                    .onHover { isHoveringConfirm = $0 }
                }
            }
            .padding(22)
            .frame(width: 440)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.13))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 30, x: 0, y: 14)
            .offset(y: -20)
            .transition(
                .asymmetric(
                    insertion: .offset(y: -14).combined(with: .opacity),
                    removal: .offset(y: -14).combined(with: .opacity)
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(100)
    }

    private func confirmationTitle(for confirmation: DownloadConfirmationType) -> String {
        switch confirmation {
        case .clearAll(let count):
            return "Clear all \(count) downloads?"
        case .deleteSelected(let ids):
            return "Delete \(ids.count) \(ids.count == 1 ? "download" : "downloads")?"
        }
    }

    private func confirmationSubtitle(for confirmation: DownloadConfirmationType) -> String {
        switch confirmation {
        case .clearAll:
            return "This will remove all download records from Lotus. Downloaded files on your disk will remain untouched."
        case .deleteSelected:
            return "This will remove the selected download records from Lotus. The downloaded files on disk will not be deleted."
        }
    }

    private func confirmationButtonTitle(for confirmation: DownloadConfirmationType) -> String {
        switch confirmation {
        case .clearAll:
            return "Clear All"
        case .deleteSelected(let ids):
            return "Delete \(ids.count)"
        }
    }
}

// MARK: - Download Row View

private struct DownloadRowView: View {
    let item: DownloadItem
    let isAlternate: Bool
    let isSelected: Bool
    let isSelecting: Bool
    let onToggleSelect: () -> Void
    let onClick: () -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onRetry: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    private var rowHoverFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.035)
    }

    private var alternateRowFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.10) : Color.black.opacity(0.025)
    }

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 12) {
                // Leading: File icon or selection checkbox
                ZStack {
                    if isSelecting || isHovered {
                        DownloadSelectionCheckbox(isSelected: isSelected, action: onToggleSelect)
                    } else {
                        Image(systemName: item.systemIconName)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(item.state == .failed ? Color.red.opacity(0.8) : Color.accentColor)
                    }
                }
                .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.filename)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(foregroundPrimary.opacity(isSelected ? 1.0 : 0.92))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        Text(item.formattedSize)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(foregroundSecondary)

                        if let host = item.displayHost {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(foregroundSecondary.opacity(0.5))

                            Text(host)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(foregroundSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        if item.state == .downloading {
                            if let speed = item.formattedSpeed {
                                Text("• \(speed)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.accentColor)
                            } else {
                                Text("• Downloading...")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.accentColor)
                            }

                            if let eta = item.formattedETA {
                                Text("(\(eta))")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(foregroundSecondary)
                            }
                        } else if item.state == .paused {
                            Text("• Paused")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.orange.opacity(0.9))
                        } else if item.state == .failed {
                            Text("• Failed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.red.opacity(0.85))
                        } else if item.state == .cancelled {
                            Text("• Cancelled")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(foregroundSecondary)
                        }
                    }
                }

                Spacer(minLength: 12)

                if isHovered && !isSelecting {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Color.red.opacity(0.85))
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Delete Download")
                    .transition(.opacity)

                    if item.state == .downloading {
                        Button {
                            onPause()
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(foregroundSecondary)
                                .padding(6)
                                .background(
                                    Circle()
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Pause Download")

                        Button {
                            onCancel()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(foregroundSecondary)
                                .padding(6)
                                .background(
                                    Circle()
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Cancel Download")
                    } else if item.state == .paused {
                        Button {
                            onResume()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(Color.accentColor)
                                .padding(6)
                                .background(
                                    Circle()
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Resume Download")

                        Button {
                            onCancel()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(foregroundSecondary)
                                .padding(6)
                                .background(
                                    Circle()
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Cancel Download")
                    } else if item.state == .failed || item.state == .cancelled {
                        Button {
                            onRetry()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.accentColor)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Retry Download")
                    } else {
                        Button {
                            item.revealInFinder()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(foregroundSecondary)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Show in Finder")
                    }
                }

                Text(DownloadDateFormatter.relativeTime(for: item.startedAt))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(foregroundSecondary.opacity(0.75))
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Rectangle()
                    .fill(isSelected
                        ? Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.10)
                        : (isHovered ? rowHoverFill : (isAlternate ? alternateRowFill : Color.clear)))
            )
            .animation(.easeInOut(duration: 0.14), value: isHovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if isHovered != hovering {
                isHovered = hovering
            }
        }
        .contextMenu {
            if item.state == .downloading {
                Button("Pause Download") {
                    onPause()
                }
                Button("Cancel Download", role: .destructive) {
                    onCancel()
                }
                Divider()
            } else if item.state == .paused {
                Button("Resume Download") {
                    onResume()
                }
                Button("Cancel Download", role: .destructive) {
                    onCancel()
                }
                Divider()
            } else if item.state == .failed || item.state == .cancelled {
                Button("Retry Download") {
                    onRetry()
                }
                Divider()
            }

            Button("Open File") {
                item.openFile()
            }
            .disabled(!item.fileExists)

            Button("Show in Finder") {
                item.revealInFinder()
            }

            Divider()

            Button("Copy Download Link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.originalURL.absoluteString, forType: .string)
            }

            Divider()

            Button("Delete from History", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Download Selection Checkbox

private struct DownloadSelectionCheckbox: View {
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : foregroundSecondary.opacity(0.6), lineWidth: 1.5)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Download Header Action Button

private struct DownloadHeaderActionButton: View {
    let title: String
    let systemImage: String?
    let isDestructive: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var foreground: Color {
        if isDestructive {
            return colorScheme == .dark ? Color(red: 1.0, green: 0.45, blue: 0.42) : Color(red: 0.85, green: 0.15, blue: 0.12)
        }
        if isHovered {
            return colorScheme == .dark ? .white : Color(nsColor: .labelColor)
        }
        return colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    private var hoverFill: Color {
        if isDestructive {
            return colorScheme == .dark ? Color(red: 1.0, green: 0.3, blue: 0.28).opacity(0.15) : Color(red: 0.9, green: 0.2, blue: 0.15).opacity(0.10)
        }
        return colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10.5, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? hoverFill : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
