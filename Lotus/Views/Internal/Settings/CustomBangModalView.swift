//
//  CustomBangModalView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI

struct CustomBangModalView: View {
    enum Mode {
        case create
        case edit(CustomBang)

        var title: String {
            switch self {
            case .create: return "Add Custom Bang"
            case .edit: return "Edit Custom Bang"
            }
        }

        var subtitle: String {
            switch self {
            case .create:
                return "Define a search keyword trigger, engine name, query URL schema, color and icon."
            case .edit:
                return "Customize search keyword trigger, engine name, query URL schema, color and icon."
            }
        }

        var actionButtonTitle: String {
            switch self {
            case .create: return "Add Bang"
            case .edit: return "Save Changes"
            }
        }
    }

    enum Field: Hashable {
        case name
        case trigger
        case urlTemplate
    }

    let mode: Mode
    let onSave: (CustomBang) -> Void
    let onDelete: ((CustomBang) -> Void)?
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var trigger: String = ""
    @State private var urlTemplate: String = ""
    @State private var selectedIcon: String = "magnifyingglass"
    @State private var selectedColor: FolderColor = .blue

    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme

    private let presetColors: [FolderColor] = [.grey, .blue, .purple, .pink, .red, .orange, .yellow, .green]

    private var activeColor: Color {
        selectedColor == .grey ? (colorScheme == .dark ? .white : .black) : selectedColor.color
    }

    init(
        mode: Mode,
        onSave: @escaping (CustomBang) -> Void,
        onDelete: ((CustomBang) -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel

        switch mode {
        case .create:
            _name = State(initialValue: "")
            _trigger = State(initialValue: "")
            _urlTemplate = State(initialValue: "")
            _selectedIcon = State(initialValue: "magnifyingglass")
            _selectedColor = State(initialValue: .blue)
        case .edit(let bang):
            _name = State(initialValue: bang.name)
            _trigger = State(initialValue: bang.cleanTrigger)
            _urlTemplate = State(initialValue: bang.searchURLTemplate)
            _selectedIcon = State(initialValue: bang.iconName)
            _selectedColor = State(initialValue: bang.color)
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !trigger.trimmingCharacters(in: CharacterSet(charactersIn: "!").union(.whitespacesAndNewlines)).isEmpty &&
        !urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(mode.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)

                Text(mode.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.65) : Color(nsColor: .secondaryLabelColor))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Name Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

                TextField("Name (e.g. GitHub, YouTube, Reddit)", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                focusedField == .name ? activeColor : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)),
                                lineWidth: focusedField == .name ? 1.5 : 1
                            )
                    )
                    .focused($focusedField, equals: .name)
                    .animation(.easeInOut(duration: 0.16), value: selectedColor)
                    .animation(.easeInOut(duration: 0.16), value: focusedField)
            }

            // Trigger & Schema in vertical stack
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Trigger Keyword")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

                    Spacer()

                    let clean = trigger.trimmingCharacters(in: CharacterSet(charactersIn: "!").union(.whitespaces))
                    Text("Shortcut: !\(clean.isEmpty ? "keyword" : clean)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(activeColor)
                }

                TextField("Trigger keyword without ! (e.g. gh, yt, r)", text: $trigger)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                focusedField == .trigger ? activeColor : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)),
                                lineWidth: focusedField == .trigger ? 1.5 : 1
                            )
                    )
                    .focused($focusedField, equals: .trigger)
                    .animation(.easeInOut(duration: 0.16), value: selectedColor)
                    .animation(.easeInOut(duration: 0.16), value: focusedField)
            }

            // URL Template Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Search URL Schema")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

                TextField("URL Schema with {searchTerms} (e.g. https://github.com/search?q={searchTerms})", text: $urlTemplate)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                focusedField == .urlTemplate ? activeColor : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)),
                                lineWidth: focusedField == .urlTemplate ? 1.5 : 1
                            )
                    )
                    .focused($focusedField, equals: .urlTemplate)
                    .animation(.easeInOut(duration: 0.16), value: selectedColor)
                    .animation(.easeInOut(duration: 0.16), value: focusedField)
            }

            // Icon Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(CustomBang.presetIcons, id: \.self) { iconName in
                        let isSelected = selectedIcon == iconName

                        Button {
                            selectedIcon = iconName
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isSelected ? activeColor.opacity(colorScheme == .dark ? 0.25 : 0.18) : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))

                                if isSelected {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(activeColor, lineWidth: 1.5)
                                }

                                Image(systemName: iconName)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? activeColor : (colorScheme == .dark ? Color.white.opacity(0.7) : Color.primary.opacity(0.7)))
                            }
                            .frame(height: 32)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                    }
                }
            }

            // Color Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

                HStack(spacing: 7) {
                    ForEach(presetColors) { color in
                        let isSelected = selectedColor == color
                        let dotColor: Color = (color == .grey ? (colorScheme == .dark ? .white : .black) : color.color)

                        Button {
                            selectedColor = color
                        } label: {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .stroke(dotColor, lineWidth: 2)
                                        .frame(width: 32, height: 32)
                                }

                                Circle()
                                    .fill(dotColor)
                                    .frame(width: 24, height: 24)
                            }
                            .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    HStack(spacing: 6) {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary)

                        Text("ESC")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                            )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .focusable(false)
                .focusEffectDisabled()

                if case .edit(let originalBang) = mode, let onDelete = onDelete {
                    Button {
                        onDelete(originalBang)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .medium))
                            Text("Delete")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color.red.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.red.opacity(colorScheme == .dark ? 0.15 : 0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .focusEffectDisabled()
                }

                Spacer()

                Button {
                    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanTrigger = trigger.trimmingCharacters(in: CharacterSet(charactersIn: "!").union(.whitespacesAndNewlines))
                    let cleanURL = urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanName.isEmpty, !cleanTrigger.isEmpty, !cleanURL.isEmpty else { return }

                    var bang: CustomBang
                    if case .edit(let original) = mode {
                        bang = original
                        bang.name = cleanName
                        bang.trigger = cleanTrigger
                        bang.searchURLTemplate = cleanURL
                        bang.iconName = selectedIcon
                        bang.color = selectedColor
                    } else {
                        bang = CustomBang(
                            trigger: cleanTrigger,
                            name: cleanName,
                            searchURLTemplate: cleanURL,
                            iconName: selectedIcon
                        )
                        bang.color = selectedColor
                    }
                    onSave(bang)
                } label: {
                    HStack(spacing: 6) {
                        Text(mode.actionButtonTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? Color.black : Color.white)

                        Image(systemName: "return")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? Color.black.opacity(0.65) : Color.white.opacity(0.85))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark ? Color(white: 0.92) : Color.black)
                    )
                    .opacity(!isFormValid ? 0.35 : 1.0)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
                .focusable(false)
                .focusEffectDisabled()
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 440)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.14) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1)
        )
        .focusEffectDisabled()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .name
            }
        }
    }
}
