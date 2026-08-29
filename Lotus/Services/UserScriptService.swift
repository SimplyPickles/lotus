//
//  UserScriptService.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import Foundation
import Combine

@MainActor
final class UserScriptService: ObservableObject {
    static let shared = UserScriptService()

    @Published var scripts: [UserScript] = []
    @Published var isEnabled: Bool = true

    private let scriptsKey = "lotus.browser.userScripts"
    private let enabledKey = "lotus.browser.userScriptsEnabled"

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: scriptsKey),
              let decoded = try? JSONDecoder().decode([UserScript].self, from: data) else {
            scripts = []
            return
        }
        scripts = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        UserDefaults.standard.set(data, forKey: scriptsKey)
        UserDefaults.standard.set(isEnabled, forKey: enabledKey)
    }

    // MARK: - CRUD

    func add(_ script: UserScript) {
        scripts.append(script)
        save()
    }

    func update(_ script: UserScript) {
        if let idx = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[idx] = script
            save()
        }
    }

    func delete(id: UUID) {
        scripts.removeAll { $0.id == id }
        save()
    }

    func toggle(id: UUID) {
        if let idx = scripts.firstIndex(where: { $0.id == id }) {
            scripts[idx].isEnabled.toggle()
            save()
        }
    }

    func setGlobalEnabled(_ enabled: Bool) {
        isEnabled = enabled
        save()
    }

    // MARK: - Matching

    func matchingScripts(for url: URL) -> [UserScript] {
        guard isEnabled else { return [] }
        return scripts.filter { $0.matches(url: url) }
    }

    // MARK: - Compilation

    /// Returns JavaScript that injects a CSS stylesheet safely into the page.
    static func cssInjectionScript(css: String, scriptId: String) -> String {
        let escaped = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        return """
        (function() {
          var existing = document.querySelector('style[data-lotus-user-style="\(scriptId)"]');
          if (existing) { existing.remove(); }
          var style = document.createElement('style');
          style.setAttribute('data-lotus-user-style', '\(scriptId)');
          style.textContent = `\(escaped)`;
          (document.head || document.documentElement).appendChild(style);
        })();
        """
    }

    // MARK: - Built-in Templates

    static var templates: [UserScript] {
        [
            UserScript(
                name: "Minimal Dark Mode",
                domainPattern: "*",
                type: .css,
                code: "html { filter: invert(0.9) hue-rotate(180deg) !important; }\nimg, video { filter: invert(1) hue-rotate(180deg) !important; }"
            ),
            UserScript(
                name: "Wide GitHub Layout",
                domainPattern: "github.com",
                type: .css,
                code: ".container-xl, .container-lg { max-width: 100% !important; }"
            ),
            UserScript(
                name: "Page Load Logger",
                domainPattern: "*",
                type: .javascript,
                code: "console.log('[Lotus UserScript] Page loaded:', window.location.href);",
                runAt: .documentEnd
            )
        ]
    }
}
