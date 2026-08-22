//
//  NSResponder+BeepSuppression.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import AppKit

// MARK: - Unhandled Key Beep Suppression

extension NSResponder {
    private static var hasSwizzledNoResponder = false

    static func suppressUnhandledKeyBeep() {
        guard !hasSwizzledNoResponder else { return }
        hasSwizzledNoResponder = true

        let originalSelector = #selector(NSResponder.noResponder(for:))
        let swizzledSelector = #selector(NSResponder.lotus_noResponder(for:))

        guard let originalMethod = class_getInstanceMethod(NSResponder.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(NSResponder.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc private func lotus_noResponder(for selector: Selector) {
        if selector == #selector(NSResponder.keyDown(with:)) || selector == #selector(NSResponder.keyUp(with:)) {
            // Suppress the default error sound (NSBeep) when a key is pressed and unhandled
            return
        }
        lotus_noResponder(for: selector)
    }
}
