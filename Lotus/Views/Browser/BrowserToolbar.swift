//
//  BrowserToolbar.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

struct BrowserToolbar: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme

    @State private var urlInputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isInputHovered: Bool = false

    @State private var backOffset: CGFloat = 0
    @State private var forwardOffset: CGFloat = 0
    /// True for the remainder of the runloop tick in which the selected tab changed.
    /// Focus gains arriving during that window are spurious SwiftUI field-editor
    /// restorations from the view diff, not user clicks, so they get dropped.
    @State private var isSwitchingTabs: Bool = false

    private var theme: BrowserChromeTheme {
        BrowserChromeTheme(browserState: browserState, colorScheme: colorScheme)
    }

    private var currentURL: URL? {
        browserState.activeURL
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                browserState.toggleSidebar()
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .regular))
                    .transaction { $0.animation = nil }
            }
            .buttonStyle(BrowserToolbarButtonStyle(isLight: browserState.isThemeLight, hasCustomTheme: browserState.activeThemeColor != nil))
            .focusable(false)
            .padding(.leading, -1)

            Button {
                backOffset = -2.5
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    backOffset = 0
                }
                browserState.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .offset(x: backOffset)
                    .animation(.spring(response: 0.28, dampingFraction: 0.62), value: backOffset)
            }
            .buttonStyle(BrowserToolbarButtonStyle(isLight: browserState.isThemeLight, hasCustomTheme: browserState.activeThemeColor != nil))
            .disabled(!browserState.canGoBack)
            .opacity(browserState.canGoBack ? 1.0 : 0.35)
            .animation(.easeInOut(duration: 0.2), value: browserState.canGoBack)
            .focusable(false)

            Button {
                forwardOffset = 2.5
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    forwardOffset = 0
                }
                browserState.goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .offset(x: forwardOffset)
                    .animation(.spring(response: 0.28, dampingFraction: 0.62), value: forwardOffset)
            }
            .buttonStyle(BrowserToolbarButtonStyle(isLight: browserState.isThemeLight, hasCustomTheme: browserState.activeThemeColor != nil))
            .disabled(!browserState.canGoForward)
            .opacity(browserState.canGoForward ? 1.0 : 0.35)
            .animation(.easeInOut(duration: 0.2), value: browserState.canGoForward)
            .focusable(false)

            Button {
                browserState.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .regular))
                    .transaction { $0.animation = nil }
            }
            .buttonStyle(BrowserToolbarButtonStyle(isLight: browserState.isThemeLight, hasCustomTheme: browserState.activeThemeColor != nil))
            .focusable(false)

//            Button {
//                browserState.triggerAutoFill()
//            } label: {
//                Image(systemName: "key.fill")
//                    .font(.system(size: 11, weight: .medium))
//            }
//            .buttonStyle(BrowserToolbarButtonStyle(isLight: browserState.isThemeLight, hasCustomTheme: browserState.activeThemeColor != nil))
//            .help("AutoFill Passwords with Apple Password Manager")
//            .focusable(false)

            ZStack(alignment: .leading) {
                if !isEditingOrHovering, let host = prettifiedHost {
                    HStack(spacing: 4) {
                        Text(host)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(theme.foregroundPrimary)

                        if let detail = prettifiedDetail {
                            Text("/")
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(theme.foregroundSecondary.opacity(0.3))

                            Text(detail)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(theme.foregroundSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .allowsHitTesting(false)
                }

                TextField(
                    "",
                    text: $urlInputText,
                    prompt: Text("Search the web or type a URL").foregroundColor(theme.foregroundSecondary)
                )
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(theme.foregroundPrimary)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .focused($isInputFocused)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .opacity((!isEditingOrHovering && prettifiedHost != nil) ? 0 : 1)
                .onKeyPress(.escape) {
                    syncInputText()
                    isInputFocused = false
                    return .handled
                }
            }
            .transaction { $0.animation = nil }
            .background(
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.inputBackground(isFocused: isInputFocused, isHovered: isInputHovered))
                        .animation(.easeInOut(duration: 0.15), value: isInputHovered)
                        .animation(.easeInOut(duration: 0.15), value: isInputFocused)

                    HairlineProgressIndicator(browserState: browserState)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            )
            .onHover { hovering in
                isInputHovered = hovering
            }
            .onSubmit {
                submit(with: urlInputText)
            }
            .onExitCommand {
                syncInputText()
                isInputFocused = false
            }
            .background {
                // ⌘L is intentionally view-local: it needs this field's
                // @FocusState. Recorded in LotusShortcuts.localExceptions.
                Button("") {
                    isInputFocused = true
                }
                .keyboardShortcut("l", modifiers: .command)
                .opacity(0)
                .focusable(false)
            }


            Button {
//                browserState.reload()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .regular))
                    .transaction { $0.animation = nil }
            }
            .buttonStyle(BrowserToolbarButtonStyle(isLight: browserState.isThemeLight, hasCustomTheme: browserState.activeThemeColor != nil))
            .focusable(false)
            .padding(.trailing, -9)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(theme.backgroundColor)
        .onAppear {
            syncInputText()
            isInputFocused = false
        }
        .onChange(of: browserState.selectedTabId) {
            handleTabSwitch()
        }
        .onChange(of: browserState.activeURL) {
            syncInputText()
        }
        .onChange(of: isInputFocused) { isFocused in
            if isFocused {
                if isSwitchingTabs {
                    // Spurious re-focus while the tab switch is still settling.
                    isInputFocused = false
                    return
                }
                syncInputText()
                DispatchQueue.main.async {
                    // Re-verify before selecting: focus may already have been
                    // lost again during this runloop tick.
                    guard isInputFocused, !isSwitchingTabs else { return }
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
            } else {
                syncInputText()
            }
        }
    }

    private var isEditingOrHovering: Bool {
        isInputFocused || isInputHovered
    }

    private var prettifiedHost: String? {
        guard let host = currentURL?.host, !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var prettifiedDetail: String? {
        if let title = browserState.activeTab?.title, !title.isEmpty, title != prettifiedHost, title != currentURL?.absoluteString {
            return title
        }
        if let path = currentURL?.path, !path.isEmpty && path != "/" {
            return path
        }
        return nil
    }

    /// Ends address-bar editing synchronously and arms the spurious-focus guard
    /// for the rest of the current runloop tick.
    ///
    /// Deferring the resign to SwiftUI's own update cycle left a stale field
    /// editor installed on the URL field across tab switches, which both made
    /// the bar look selected and caused WebTabHostNSView's deferred
    /// first-responder pass to bail out. Ending the edit here is deterministic.
    private func handleTabSwitch() {
        isSwitchingTabs = true
        if isInputFocused {
            NSApp.keyWindow?.makeFirstResponder(nil)
            isInputFocused = false
        }
        syncInputText()
        DispatchQueue.main.async {
            isSwitchingTabs = false
        }
    }

    private func syncInputText() {
        if let abs = currentURL?.absoluteString, !abs.isEmpty {
            urlInputText = abs
        } else {
            urlInputText = browserState.activeTab?.title ?? ""
        }
    }

    private func submit(with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isInputFocused = false
        browserState.navigateActiveTab(to: trimmed)
    }
}
