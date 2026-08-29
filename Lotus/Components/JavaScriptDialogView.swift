//
//  JavaScriptDialogView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI

enum JavaScriptDialogKind {
    case alert(message: String, completion: () -> Void)
    case confirm(message: String, completion: (Bool) -> Void)
    case prompt(prompt: String, defaultText: String?, completion: (String?) -> Void)
}

struct JavaScriptDialogRequest: Identifiable {
    let id = UUID()
    let host: String
    let kind: JavaScriptDialogKind
}

struct JavaScriptDialogView: View {
    @ObservedObject var browserState: BrowserState
    let request: JavaScriptDialogRequest
    @Environment(\.colorScheme) private var colorScheme

    @State private var inputText: String = ""
    @State private var isHoveringCancel: Bool = false
    @State private var isHoveringConfirm: Bool = false
    @State private var hasHandled: Bool = false
    @FocusState private var isInputFocused: Bool

    init(browserState: BrowserState, request: JavaScriptDialogRequest) {
        self.browserState = browserState
        self.request = request
        if case .prompt(_, let defaultText, _) = request.kind {
            _inputText = State(initialValue: defaultText ?? "")
        } else {
            _inputText = State(initialValue: "")
        }
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? Color.white.opacity(0.65) : Color(nsColor: .secondaryLabelColor)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.14) : Color(nsColor: .windowBackgroundColor)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    private func secondaryButtonFill(isHovered: Bool) -> Color {
        if colorScheme == .dark {
            return isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.10)
        } else {
            return isHovered ? Color.black.opacity(0.10) : Color.black.opacity(0.06)
        }
    }

    private var displayHost: String {
        request.host.isEmpty ? "This page" : request.host
    }

    private var messageText: String {
        switch request.kind {
        case .alert(let message, _):
            return message
        case .confirm(let message, _):
            return message
        case .prompt(let prompt, _, _):
            return prompt
        }
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(colorScheme == .dark ? 0.45 : 0.28)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    handleCancel()
                }

            // Modal Card
            VStack(alignment: .leading, spacing: 0) {
                // Icon Squircle
                iconSquircle
                    .padding(.bottom, 14)

                // Title
                Text("“\(displayHost)”")
                    .font(.system(size: 18.5, weight: .bold))
                    .foregroundColor(foregroundPrimary)
                    .lineLimit(2)
                    .padding(.bottom, 6)

                // Message Text
                if !messageText.isEmpty {
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(messageText)
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundColor(foregroundSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 140)
                    .padding(.bottom, isPrompt ? 14 : 22)
                } else {
                    Spacer()
                        .frame(height: isPrompt ? 10 : 16)
                }

                // Prompt Input Box
                if isPrompt {
                    TextField("", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(foregroundPrimary)
                        .focused($isInputFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.12), lineWidth: 1)
                        )
                        .onSubmit {
                            handleConfirm()
                        }
                        .padding(.bottom, 22)
                }

                // Buttons row
                HStack(spacing: 8) {
                    Spacer(minLength: 12)

                    if showsCancelButton {
                        // Cancel button
                        Button {
                            handleCancel()
                        } label: {
                            HStack(spacing: 6) {
                                Text("Cancel")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(foregroundPrimary)

                                Text("ESC")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(foregroundSecondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08))
                                    )
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(secondaryButtonFill(isHovered: isHoveringCancel))
                            )
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.escape, modifiers: [])
                        .onHover { isHoveringCancel = $0 }
                    }

                    // Confirm / OK button
                    Button {
                        handleConfirm()
                    } label: {
                        HStack(spacing: 5) {
                            Text("OK")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)

                            Image(systemName: "return")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isHoveringConfirm ? Color(red: 0.18, green: 0.55, blue: 0.98) : Color(red: 0.10, green: 0.45, blue: 0.90))
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
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.18), radius: 30, x: 0, y: 14)
            .offset(y: -45)
            .transition(
                .asymmetric(
                    insertion: .offset(y: -14).combined(with: .opacity),
                    removal: .offset(y: -14).combined(with: .opacity)
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(100)
        .onAppear {
            if isPrompt {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isInputFocused = true
                }
            }
        }
    }

    private var isPrompt: Bool {
        if case .prompt = request.kind {
            return true
        }
        return false
    }

    private var showsCancelButton: Bool {
        switch request.kind {
        case .alert:
            return false
        case .confirm, .prompt:
            return true
        }
    }

    @ViewBuilder
    private var iconSquircle: some View {
        switch request.kind {
        case .alert:
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.72, blue: 0.25),
                                Color(red: 0.95, green: 0.52, blue: 0.10)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 5, y: 2)

                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
            }

        case .confirm:
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.65, blue: 1.0),
                                Color(red: 0.15, green: 0.45, blue: 0.90)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 5, y: 2)

                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
            }

        case .prompt:
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.30, green: 0.78, blue: 0.75),
                                Color(red: 0.12, green: 0.58, blue: 0.62)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 5, y: 2)

                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
    }

    private func handleConfirm() {
        guard !hasHandled else { return }
        hasHandled = true
        switch request.kind {
        case .alert(_, let completion):
            completion()
        case .confirm(_, let completion):
            completion(true)
        case .prompt(_, _, let completion):
            completion(inputText)
        }
        browserState.dismissJavaScriptDialog()
    }

    private func handleCancel() {
        guard !hasHandled else { return }
        hasHandled = true
        switch request.kind {
        case .alert(_, let completion):
            completion()
        case .confirm(_, let completion):
            completion(false)
        case .prompt(_, _, let completion):
            completion(nil)
        }
        browserState.dismissJavaScriptDialog()
    }
}
