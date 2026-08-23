//
//  BrowserState+Clipboard.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import AppKit
import SwiftUI
import WebKit

struct URLCopyFeedback: Equatable {
    enum Outcome: Equatable {
        case copied
        case failed
    }

    let id: UUID
    let tabId: UUID
    let outcome: Outcome

    var message: String {
        switch outcome {
        case .copied:
            return "URL copied to clipboard"
        case .failed:
            return "Couldn't copy URL"
        }
    }

    var systemImage: String {
        switch outcome {
        case .copied:
            return "link"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
}

extension BrowserState {

    // MARK: - Clipboard

    /// Copies the active top-level page URL. `WKWebView.url` tracks the same
    /// navigation location exposed to a page as `window.location.href`.
    func copyCurrentPageURL() {
        copyPageURL(for: selectedTabId)
    }

    func copyPageURL(for tabId: UUID) {
        let currentURL = webViewStore[tabId]?.url ?? url(for: tabId)
        guard let currentURL else {
            presentURLCopyFeedback(for: tabId, outcome: .failed)
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didCopy = pasteboard.setString(currentURL.absoluteString, forType: .string)
        presentURLCopyFeedback(for: tabId, outcome: didCopy ? .copied : .failed)
    }

    private func presentURLCopyFeedback(for tabId: UUID, outcome: URLCopyFeedback.Outcome) {
        urlCopyFeedbackDismissalWorkItem?.cancel()

        let feedback = URLCopyFeedback(id: UUID(), tabId: tabId, outcome: outcome)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            urlCopyFeedback = feedback
        }

        let dismissal = DispatchWorkItem { [weak self] in
            guard self?.urlCopyFeedback?.id == feedback.id else { return }
            withAnimation(.easeIn(duration: 0.20)) {
                self?.urlCopyFeedback = nil
            }
        }
        urlCopyFeedbackDismissalWorkItem = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65, execute: dismissal)
    }
}
