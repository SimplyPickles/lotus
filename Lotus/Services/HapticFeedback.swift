//
//  HapticFeedback.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import AppKit

enum HapticFeedback {
    static var isEnabled: Bool {
        (UserDefaults.standard.object(forKey: "lotus.browser.reorderHapticFeedback") as? Bool) ?? true
    }

    static func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern, performanceTime: NSHapticFeedbackManager.PerformanceTime = .now) {
        guard isEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: performanceTime)
    }
}
