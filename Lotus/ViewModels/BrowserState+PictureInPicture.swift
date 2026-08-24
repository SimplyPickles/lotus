//
//  BrowserState+PictureInPicture.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import Foundation
import WebKit

extension BrowserState {

    // MARK: - Picture in Picture

    /// Toggles native Picture in Picture for a tab's largest playing video
    /// (ellipsis menu action).
    func togglePictureInPicture(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        guard let webView = webViewStore[targetId] else { return }
        webView.evaluateJavaScript(UserScripts.pictureInPictureStatus) { [weak self] result, _ in
            if (result as? String) == "pip" {
                webView.evaluateJavaScript(UserScripts.exitPictureInPicture, completionHandler: nil)
                DispatchQueue.main.async {
                    self?.autoPiPTabs.remove(targetId)
                }
            } else {
                webView.evaluateJavaScript(UserScripts.enterPictureInPictureManual) { result, error in
                    #if DEBUG
                    NSLog("[Lotus] PiP enter (manual): \(result as? String ?? "nil") \(error.map { "error: \($0.localizedDescription)" } ?? "")")
                    #endif
                }
            }
        }
    }

    /// Auto-PiP on tab switch: a playing video in the tab being left enters
    /// PiP; returning to an auto-PiP'd tab brings its video back inline.
    /// Manually-invoked PiP (ellipsis menu) is untracked and survives
    /// switching back.
    func handlePictureInPictureOnTabSwitch(from oldId: UUID, to newId: UUID) {
        guard oldId != newId else { return }

        // Returning to a tab whose video we auto-detached.
        if autoPiPTabs.contains(newId), let webView = webViewStore[newId] {
            webView.evaluateJavaScript(UserScripts.exitPictureInPicture, completionHandler: nil)
            autoPiPTabs.remove(newId)
        }

        let isAutoPiPEnabled = UserDefaults.standard.object(forKey: "lotus.browser.autoPiPEnabled") as? Bool ?? true
        guard isAutoPiPEnabled else { return }

        // The old tab may still be on screen as half of a split — leave it be.
        guard !currentTabIds.contains(oldId), let oldWebView = webViewStore[oldId] else { return }

        oldWebView.evaluateJavaScript(UserScripts.pictureInPictureStatus) { [weak self] result, _ in
            guard let self, (result as? String) == "playing" else { return }
            DispatchQueue.main.async {
                // Re-verify: the user may have already switched back.
                guard self.selectedTabId != oldId, !self.currentTabIds.contains(oldId) else { return }
                oldWebView.evaluateJavaScript(UserScripts.enterPictureInPicture) { result, error in
                    #if DEBUG
                    NSLog("[Lotus] PiP enter (auto): \(result as? String ?? "nil") \(error.map { "error: \($0.localizedDescription)" } ?? "")")
                    #endif
                    if (result as? String) == "ok" {
                        DispatchQueue.main.async {
                            self.autoPiPTabs.insert(oldId)
                        }
                    }
                }
            }
        }
    }
}
