//
//  SiteZapStore.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import Foundation
import Combine

/// A persistent record representing an element zapped (blocked) on a specific domain.
struct ZappedElement: Identifiable, Codable, Hashable {
    let id: UUID
    let domain: String
    let selector: String
    let elementSummary: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        domain: String,
        selector: String,
        elementSummary: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.domain = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.selector = selector
        self.elementSummary = elementSummary
        self.createdAt = createdAt
    }
}

/// Stores and manages per-site CSS element zap rules.
final class SiteZapStore: ObservableObject {
    static let shared = SiteZapStore()

    private let storageKey = "lotus.browser.zapped_elements"
    @Published private(set) var zapsByDomain: [String: [ZappedElement]] = [:]

    private init() {
        load()
    }

    private func normalize(domain: String) -> String {
        var clean = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.hasPrefix("https://") { clean = String(clean.dropFirst(8)) }
        if clean.hasPrefix("http://") { clean = String(clean.dropFirst(7)) }
        if let slashIdx = clean.firstIndex(of: "/") { clean = String(clean[..<slashIdx]) }
        if let colonIdx = clean.firstIndex(of: ":") { clean = String(clean[..<colonIdx]) }
        if clean.hasPrefix("www.") { clean = String(clean.dropFirst(4)) }
        return clean
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: [ZappedElement]].self, from: data)
            self.zapsByDomain = decoded
        } catch {
            print("SiteZapStore: Failed to decode zapped elements: \(error)")
        }
    }

    private func persist() {
        do {
            let encoded = try JSONEncoder().encode(zapsByDomain)
            UserDefaults.standard.set(encoded, forKey: storageKey)
        } catch {
            print("SiteZapStore: Failed to encode zapped elements: \(error)")
        }
    }

    /// Returns all zapped elements for a given domain.
    func zappedElements(for domain: String) -> [ZappedElement] {
        let key = normalize(domain: domain)
        guard !key.isEmpty else { return [] }

        var results: [ZappedElement] = []
        var seenIds = Set<UUID>()

        // Exact match
        if let list = zapsByDomain[key] {
            for item in list {
                if seenIds.insert(item.id).inserted {
                    results.append(item)
                }
            }
        }

        // Subdomain / parent domain matching
        for (storedDomain, list) in zapsByDomain where storedDomain != key {
            if key.hasSuffix("." + storedDomain) || storedDomain.hasSuffix("." + key) {
                for item in list {
                    if seenIds.insert(item.id).inserted {
                        results.append(item)
                    }
                }
            }
        }

        return results
    }

    /// Total count of zapped elements for a given domain.
    func zapCount(for domain: String) -> Int {
        zappedElements(for: domain).count
    }

    /// All domains with active zap rules.
    var allDomains: [String] {
        Array(zapsByDomain.keys).sorted()
    }

    /// Total count of all zapped elements across all domains.
    var totalZapCount: Int {
        zapsByDomain.values.reduce(0) { $0 + $1.count }
    }

    /// Adds a new zap rule for a domain and returns the created element.
    @discardableResult
    func addZap(domain: String, selector: String, elementSummary: String) -> ZappedElement {
        let key = normalize(domain: domain)
        var list = zapsByDomain[key] ?? []

        // Avoid exact duplicate selectors for the same domain
        if let existing = list.first(where: { $0.selector == selector }) {
            return existing
        }

        let newElement = ZappedElement(domain: key, selector: selector, elementSummary: elementSummary)
        list.insert(newElement, at: 0)
        zapsByDomain[key] = list
        persist()
        return newElement
    }

    /// Removes a specific zapped element by ID.
    func removeZap(id: UUID, domain: String) {
        let key = normalize(domain: domain)
        guard var list = zapsByDomain[key] else { return }
        list.removeAll(where: { $0.id == id })
        if list.isEmpty {
            zapsByDomain.removeValue(forKey: key)
        } else {
            zapsByDomain[key] = list
        }
        persist()
    }

    /// Removes a zapped element object directly.
    func removeZap(_ zap: ZappedElement) {
        removeZap(id: zap.id, domain: zap.domain)
    }

    /// Clears all zaps for a specific domain.
    func clearZaps(for domain: String) {
        let key = normalize(domain: domain)
        zapsByDomain.removeValue(forKey: key)
        persist()
    }

    /// Clears all zaps across all domains.
    func clearAll() {
        zapsByDomain.removeAll()
        persist()
    }

    /// Generates the CSS rule string to hide all zapped elements on a domain.
    func cssRules(for domain: String) -> String {
        let elements = zappedElements(for: domain)
        guard !elements.isEmpty else { return "" }
        let combinedSelectors = elements.map { $0.selector }.joined(separator: ", ")
        return "\(combinedSelectors) { display: none !important; visibility: hidden !important; pointer-events: none !important; }"
    }
}
