//
//  CustomBangsStore.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI
import Combine

struct CustomBang: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var trigger: String
    var name: String
    var searchURLTemplate: String
    var accentColorHex: String? = nil
    var iconName: String = "magnifyingglass"

    var formattedTrigger: String {
        trigger.hasPrefix("!") ? trigger : "!\(trigger)"
    }

    var cleanTrigger: String {
        trigger.trimmingCharacters(in: CharacterSet(charactersIn: "!"))
    }

    var accentColor: Color {
        if let hex = accentColorHex, let parsed = ColorParser.parse(hex)?.color {
            return parsed
        }
        return .accentColor
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

final class CustomBangsStore: ObservableObject {
    static let shared = CustomBangsStore()

    private let userDefaultsKey = "lotus.browser.custom_bangs"

    @Published var customBangs: [CustomBang] = []

    static let defaultBangs: [CustomBang] = [
        CustomBang(trigger: "g", name: "Google", searchURLTemplate: "https://www.google.com/search?q={searchTerms}", accentColorHex: "4285F4", iconName: "g.circle.fill"),
        CustomBang(trigger: "w", name: "Wikipedia", searchURLTemplate: "https://en.wikipedia.org/wiki/Special:Search?search={searchTerms}", accentColorHex: "636466", iconName: "book.fill"),
        CustomBang(trigger: "yt", name: "YouTube", searchURLTemplate: "https://www.youtube.com/results?search_query={searchTerms}", accentColorHex: "FF0000", iconName: "play.rectangle.fill"),
        CustomBang(trigger: "gh", name: "GitHub", searchURLTemplate: "https://github.com/search?q={searchTerms}", accentColorHex: "24292E", iconName: "chevron.left.forwardslash.chevron.right"),
        CustomBang(trigger: "r", name: "Reddit", searchURLTemplate: "https://www.reddit.com/search/?q={searchTerms}", accentColorHex: "FF4500", iconName: "bubble.left.and.bubble.right.fill"),
        CustomBang(trigger: "a", name: "Amazon", searchURLTemplate: "https://www.amazon.com/s?k={searchTerms}", accentColorHex: "FF9900", iconName: "cart.fill"),
        CustomBang(trigger: "m", name: "Google Maps", searchURLTemplate: "https://www.google.com/maps/search/{searchTerms}", accentColorHex: "34A853", iconName: "map.fill"),
        CustomBang(trigger: "ddg", name: "DuckDuckGo", searchURLTemplate: "https://duckduckgo.com/?q={searchTerms}", accentColorHex: "DE5833", iconName: "shield.fill"),
        CustomBang(trigger: "kagi", name: "Kagi", searchURLTemplate: "https://kagi.com/search?q={searchTerms}", accentColorHex: "FFC107", iconName: "magnifyingglass.circle.fill"),
        CustomBang(trigger: "b", name: "Bing", searchURLTemplate: "https://www.bing.com/search?q={searchTerms}", accentColorHex: "008373", iconName: "b.circle.fill")
    ]

    private init() {
        load()
    }

    func allBangs() -> [CustomBang] {
        var result = Self.defaultBangs
        for custom in customBangs {
            if let idx = result.firstIndex(where: { $0.cleanTrigger.lowercased() == custom.cleanTrigger.lowercased() }) {
                result[idx] = custom
            } else {
                result.append(custom)
            }
        }
        return result
    }

    func match(for input: String) -> CustomBang? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("!") else { return nil }
        let trigger = String(trimmed.dropFirst()).split(separator: " ").first.map(String.init) ?? ""
        guard !trigger.isEmpty else { return nil }

        return allBangs().first { bang in
            bang.cleanTrigger.lowercased() == trigger.lowercased()
        }
    }

    func addBang(trigger: String, name: String, searchURLTemplate: String, accentColorHex: String? = nil) {
        let bang = CustomBang(
            trigger: trigger.trimmingCharacters(in: CharacterSet(charactersIn: "!")),
            name: name.trimmingCharacters(in: .whitespaces),
            searchURLTemplate: searchURLTemplate.trimmingCharacters(in: .whitespaces),
            accentColorHex: accentColorHex
        )
        customBangs.removeAll(where: { $0.cleanTrigger.lowercased() == bang.cleanTrigger.lowercased() })
        customBangs.append(bang)
        save()
    }

    func removeBang(id: UUID) {
        customBangs.removeAll(where: { $0.id == id })
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(customBangs) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([CustomBang].self, from: data) {
            self.customBangs = decoded
        }
    }
}
