//
//  MediaSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct MediaSettingsSection: View {
    @ObservedObject var browserState: BrowserState
    @AppStorage("lotus.browser.autoplayPolicy") private var autoplayPolicy: String = "audio"
    @AppStorage("lotus.browser.autoPiPEnabled") private var autoPiPEnabled: Bool = true
    @AppStorage("lotus.browser.lowPowerModeShimmerDisabled") private var lowPowerModeShimmerDisabled: Bool = false
    @AppStorage("lotus.browser.tabSnoozeInterval") private var tabSnoozeInterval: String = "never"

    var body: some View {
        SettingsSectionCard(title: SettingsCategory.media.rawValue, systemImage: SettingsCategory.media.systemImage) {
            AutoplayPolicySettingsRow(autoplayPolicy: $autoplayPolicy)
            SettingsDivider()
            AutoPiPSettingsRow(autoPiPEnabled: $autoPiPEnabled)
            SettingsDivider()
            LowPowerPerformanceSettingsRow(lowPowerModeShimmerDisabled: $lowPowerModeShimmerDisabled)
            SettingsDivider()
            TabSnoozeSettingsRow(tabSnoozeInterval: $tabSnoozeInterval, browserState: browserState)
        }
    }
}

// MARK: - Rows

private struct AutoplayPolicySettingsRow: View {
    @Binding var autoplayPolicy: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.slash")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Autoplay policy")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Control automatic playback of videos and audio")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("Autoplay policy", selection: $autoplayPolicy) {
                Text("Block Audio Media").tag("audio")
                Text("Block All Autoplay").tag("blockAll")
                Text("Allow All").tag("allowAll")
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 170, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct AutoPiPSettingsRow: View {
    @Binding var autoPiPEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pip.enter")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Automatic Picture in Picture")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Pops playing videos into floating PiP when switching tabs")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Automatic Picture in Picture", isOn: $autoPiPEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct LowPowerPerformanceSettingsRow: View {
    @Binding var lowPowerModeShimmerDisabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.badge.automatic")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Optimize for battery & low power")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Suppresses animations and page shimmers during Low Power Mode")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Toggle("Optimize for battery & low power", isOn: $lowPowerModeShimmerDisabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

private struct TabSnoozeSettingsRow: View {
    @Binding var tabSnoozeInterval: String
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Tab snoozing (memory saver)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Frees RAM by suspending background tabs until you switch to them")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            Picker("Tab snoozing", selection: $tabSnoozeInterval) {
                Text("Never").tag("never")
                Text("After 15 minutes").tag("15m")
                Text("After 30 minutes").tag("30m")
                Text("After 1 hour").tag("1h")
                Text("After 2 hours").tag("2h")
            }
            .labelsHidden()
            .untintedDropdown()
            .frame(width: 170, alignment: .trailing)
            .onChange(of: tabSnoozeInterval) { _, _ in
                browserState.snoozeInactiveTabsIfNeeded()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}
