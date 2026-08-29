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
        VStack(spacing: 16) {
            SettingsSectionCard(title: "Media Playback") {
                SettingsPickerRow(
                    systemImage: "play.slash",
                    title: "Autoplay policy",
                    subtitle: "Control automatic playback of videos and audio",
                    selection: $autoplayPolicy,
                    options: [
                        ("audio", "Block Audio"),
                        ("blockAll", "Block All Autoplay"),
                        ("allowAll", "Allow All")
                    ],
                    pickerWidth: 170
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "pip.enter",
                    title: "Automatic Picture in Picture",
                    subtitle: "Pops playing videos into floating PiP when switching tabs",
                    isOn: $autoPiPEnabled
                )
            }
            
            SettingsSectionCard(
                title: "Performance & Memory"
            ) {
                SettingsPickerRow(
                    systemImage: "moon.zzz",
                    title: "Tab snoozing (memory saver)",
                    subtitle: "Frees RAM by suspending background tabs until you switch to them",
                    selection: $tabSnoozeInterval,
                    options: [
                        ("never", "Never"),
                        ("15m", "After 15 minutes"),
                        ("30m", "After 30 minutes"),
                        ("1h", "After 1 hour"),
                        ("2h", "After 2 hours")
                    ],
                    pickerWidth: 170
                ) { _ in
                    browserState.snoozeInactiveTabsIfNeeded()
                }
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "bolt.badge.automatic",
                    title: "Optimize for battery & low power",
                    subtitle: "Suppresses animations and intensive visuals during Low Power Mode",
                    isOn: $lowPowerModeShimmerDisabled
                )
            }
        }
    }
}
