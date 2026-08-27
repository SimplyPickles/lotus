//
//  CustomSearchEnginesStore.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/26/26.
//

import SwiftUI
import Combine

struct CustomSearchEngine: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var searchURLTemplate: String
    var shortcut: String? = nil
    var iconName: String = "magnifyingglass"

    var host: String {
        if let url = URL(string: searchURLTemplate) {
            return url.host ?? ""
        }
        return ""
    }

    var displayURL: String {
        if let url = URL(string: searchURLTemplate), let host = url.host {
            let path = url.path
            return host + (path.isEmpty || path == "/" ? "" : path)
        }
        return searchURLTemplate
    }

    func searchURL(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let populated: String
        if searchURLTemplate.contains("{searchTerms}") {
            populated = searchURLTemplate.replacingOccurrences(of: "{searchTerms}", with: encoded)
        } else if searchURLTemplate.contains("%s") {
            populated = searchURLTemplate.replacingOccurrences(of: "%s", with: encoded)
        } else if searchURLTemplate.contains("{q}") {
            populated = searchURLTemplate.replacingOccurrences(of: "{q}", with: encoded)
        } else {
            populated = "\(searchURLTemplate)\(encoded)"
        }
        return URL(string: populated)
    }
}

struct SearchEngineItem: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let searchURLTemplate: String
    let displayURL: String
    let iconName: String
    let isCustom: Bool
    let customId: UUID?
    let shortcut: String?
}

final class CustomSearchEnginesStore: ObservableObject {
    static let shared = CustomSearchEnginesStore()

    private let userDefaultsKey = "lotus.browser.custom_search_engines"

    @Published var customEngines: [CustomSearchEngine] = []

    static let builtInEngines: [SearchEngineItem] = [
        SearchEngineItem(
            id: "google",
            name: "Google",
            searchURLTemplate: "https://www.google.com/search?q={searchTerms}",
            displayURL: "google.com/search",
            iconName: "g.circle.fill",
            isCustom: false,
            customId: nil,
            shortcut: "g"
        ),
        SearchEngineItem(
            id: "duckDuckGo",
            name: "DuckDuckGo",
            searchURLTemplate: "https://duckduckgo.com/?q={searchTerms}",
            displayURL: "duckduckgo.com",
            iconName: "shield.fill",
            isCustom: false,
            customId: nil,
            shortcut: "ddg"
        ),
        SearchEngineItem(
            id: "bing",
            name: "Bing",
            searchURLTemplate: "https://www.bing.com/search?q={searchTerms}",
            displayURL: "bing.com/search",
            iconName: "b.circle.fill",
            isCustom: false,
            customId: nil,
            shortcut: "b"
        ),
        SearchEngineItem(
            id: "brave",
            name: "Brave",
            searchURLTemplate: "https://search.brave.com/search?q={searchTerms}",
            displayURL: "search.brave.com",
            iconName: "shield.lefthalf.filled",
            isCustom: false,
            customId: nil,
            shortcut: "brave"
        ),
        SearchEngineItem(
            id: "startpage",
            name: "Startpage",
            searchURLTemplate: "https://www.startpage.com/sp/search?query={searchTerms}",
            displayURL: "startpage.com",
            iconName: "magnifyingglass",
            isCustom: false,
            customId: nil,
            shortcut: "sp"
        ),
        SearchEngineItem(
            id: "kagi",
            name: "Kagi",
            searchURLTemplate: "https://kagi.com/search?q={searchTerms}",
            displayURL: "kagi.com/search",
            iconName: "magnifyingglass.circle.fill",
            isCustom: false,
            customId: nil,
            shortcut: "kagi"
        ),
        SearchEngineItem(
            id: "ecosia",
            name: "Ecosia",
            searchURLTemplate: "https://www.ecosia.org/search?q={searchTerms}",
            displayURL: "ecosia.org/search",
            iconName: "leaf.fill",
            isCustom: false,
            customId: nil,
            shortcut: "eco"
        )
    ]

    var allEngines: [SearchEngineItem] {
        var items = Self.builtInEngines
        for custom in customEngines {
            items.append(
                SearchEngineItem(
                    id: custom.id.uuidString,
                    name: custom.name,
                    searchURLTemplate: custom.searchURLTemplate,
                    displayURL: custom.displayURL,
                    iconName: custom.iconName,
                    isCustom: true,
                    customId: custom.id,
                    shortcut: custom.shortcut
                )
            )
        }
        return items
    }

    private init() {
        load()
    }

    func engineName(for id: String) -> String {
        if let match = allEngines.first(where: { $0.id == id || $0.id.lowercased() == id.lowercased() || $0.name.lowercased() == id.lowercased() }) {
            return match.name
        }
        return "Google"
    }

    func searchURL(for id: String, query: String) -> URL? {
        if let custom = customEngines.first(where: { $0.id.uuidString == id || $0.name.lowercased() == id.lowercased() }) {
            return custom.searchURL(for: query)
        }
        if let builtIn = Self.builtInEngines.first(where: { $0.id == id || $0.id.lowercased() == id.lowercased() }) {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let populated = builtIn.searchURLTemplate.replacingOccurrences(of: "{searchTerms}", with: encoded)
            return URL(string: populated)
        }
        // Fallback to Google
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.google.com/search?q=\(encoded)")
    }

    @discardableResult
    func addEngine(name: String, searchURLTemplate: String, shortcut: String? = nil) -> CustomSearchEngine {
        let engine = CustomSearchEngine(
            name: name.trimmingCharacters(in: .whitespaces),
            searchURLTemplate: searchURLTemplate.trimmingCharacters(in: .whitespaces),
            shortcut: shortcut?.trimmingCharacters(in: .whitespaces)
        )
        customEngines.removeAll(where: { $0.name.lowercased() == engine.name.lowercased() })
        customEngines.append(engine)
        save()
        return engine
    }

    func removeEngine(id: UUID) {
        customEngines.removeAll(where: { $0.id == id })
        save()
        let currentEngine = UserDefaults.standard.string(forKey: "lotus.browser.searchEngine")
        if currentEngine == id.uuidString {
            UserDefaults.standard.set("google", forKey: "lotus.browser.searchEngine")
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(customEngines) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([CustomSearchEngine].self, from: data) {
            self.customEngines = decoded
        }
    }
}
