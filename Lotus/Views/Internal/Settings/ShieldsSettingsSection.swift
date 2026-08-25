//
//  ShieldsSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct ShieldsSettingsSection: View {
    @ObservedObject var contentBlocker: ContentBlockerService

    var body: some View {
        SettingsSectionCard(title: SettingsCategory.shields.rawValue, systemImage: SettingsCategory.shields.systemImage) {
            ShieldsMasterSettingsRow(contentBlocker: contentBlocker)
            SettingsDivider()
            ShieldsTrackingSettingsRow(contentBlocker: contentBlocker)
            SettingsDivider()
            ShieldsFingerprintSettingsRow(contentBlocker: contentBlocker)
            SettingsDivider()
            ShieldsStrictCanvasBlockSettingsRow(contentBlocker: contentBlocker)
            SettingsDivider()
            ShieldsCosmeticSettingsRow(contentBlocker: contentBlocker)
            SettingsDivider()
            ShieldsStrictPopupBlockedSettingsRow(contentBlocker: contentBlocker)
            SettingsDivider()
            ShieldsAllowlistSettingsRow(contentBlocker: contentBlocker)
        }
    }
}

// MARK: - Rows

private struct ShieldsMasterSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Block ads & trackers")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Automatically blocks ads, analytics, and telemetry")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Block ads & trackers", isOn: $contentBlocker.isAdBlockingEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct ShieldsTrackingSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Block third-party tracking scripts")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Toggle("Block third-party tracking scripts", isOn: $contentBlocker.blockTrackersEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .disabled(!contentBlocker.isAdBlockingEnabled)
        .opacity(contentBlocker.isAdBlockingEnabled ? 1.0 : 0.45)
    }
}

private struct ShieldsCosmeticSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            Text("Hide cosmetic ad placeholders")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

            Spacer()

            Toggle("Hide cosmetic ad placeholders", isOn: $contentBlocker.blockCosmeticElementsEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .disabled(!contentBlocker.isAdBlockingEnabled)
        .opacity(contentBlocker.isAdBlockingEnabled ? 1.0 : 0.45)
    }
}

private struct ShieldsFingerprintSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "theatermasks")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Advanced fingerprint protection")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Masks device metrics, Canvas, WebGL, and WebAudio")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Advanced fingerprint protection", isOn: $contentBlocker.fingerprintProtectionEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .disabled(!contentBlocker.isAdBlockingEnabled)
        .opacity(contentBlocker.isAdBlockingEnabled ? 1.0 : 0.45)
    }
}

private struct ShieldsStrictCanvasBlockSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.fill.and.line.vertical.and.square.fill")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Canvas extraction defense mode")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text(contentBlocker.strictCanvasBlockEnabled ? "Strictly blocks HTMLCanvasElement.toDataURL() readout" : "Injects random noise jitter into Canvas extraction (Recommended)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("Canvas extraction defense mode", selection: $contentBlocker.strictCanvasBlockEnabled) {
                Text("Random Noise Jitter").tag(false)
                Text("Strict Complete Block").tag(true)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 180, alignment: .trailing)
            .disabled(!contentBlocker.fingerprintProtectionEnabled || !contentBlocker.isAdBlockingEnabled)
            .opacity((contentBlocker.fingerprintProtectionEnabled && contentBlocker.isAdBlockingEnabled) ? 1.0 : 0.45)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct ShieldsStrictPopupBlockedSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false
    @State private var newDomainInput: String = ""

    private var blockedList: [String] {
        contentBlocker.strictPopupBlockedDomains.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Strict popup & link blocklist")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text(blockedList.isEmpty ? "No sites strictly blocked" : "\(blockedList.count) site\(blockedList.count == 1 ? "" : "s") blocking all popups/links")
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
            }
            .padding(.horizontal, 14)
            .frame(height: 46)

            if isExpanded {
                VStack(spacing: 8) {
                    Divider()
                        .overlay(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                        .padding(.horizontal, 14)

                    // Add new domain input
                    HStack(spacing: 8) {
                        TextField("Add website domain (e.g. example.com)", text: $newDomainInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                addDomain()
                            }

                        Button("Add") {
                            addDomain()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    // Blocklist items
                    if blockedList.isEmpty {
                        Text("No websites are currently blocking all popups/links.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(blockedList, id: \.self) { domain in
                                HStack {
                                    Text(domain)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .primary)

                                    Spacer()

                                    Button {
                                        contentBlocker.setStrictPopupBlocking(for: domain, enabled: false)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundColor(Color.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove strict popup block")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
            }
        }
    }

    private func addDomain() {
        let clean = newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        contentBlocker.setStrictPopupBlocking(for: clean, enabled: true)
        newDomainInput = ""
    }
}

private struct ShieldsAllowlistSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false
    @State private var newDomainInput: String = ""

    private var allowlist: [String] {
        contentBlocker.allowlistedDomains.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Whitelisted websites")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text(allowlist.isEmpty ? "No sites whitelisted" : "\(allowlist.count) site\(allowlist.count == 1 ? "" : "s") allowed")
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
            }
            .padding(.horizontal, 14)
            .frame(height: 46)

            if isExpanded {
                VStack(spacing: 8) {
                    Divider()
                        .overlay(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                        .padding(.horizontal, 14)

                    // Add new domain input
                    HStack(spacing: 8) {
                        TextField("Add website domain (e.g. example.com)", text: $newDomainInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                addDomain()
                            }

                        Button("Add") {
                            addDomain()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    // Allowlist items
                    if allowlist.isEmpty {
                        Text("No websites have shields disabled.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(allowlist, id: \.self) { domain in
                                HStack {
                                    Text(domain)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .primary)

                                    Spacer()

                                    Button {
                                        contentBlocker.removeAllowlistDomain(domain)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundColor(Color.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove from whitelist")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
            }
        }
    }

    private func addDomain() {
        let clean = newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        contentBlocker.addAllowlistDomain(clean)
        newDomainInput = ""
    }
}
