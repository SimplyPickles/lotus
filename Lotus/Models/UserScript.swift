//
//  UserScript.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import Foundation

enum UserScriptType: String, Codable, CaseIterable, Identifiable {
    case css = "CSS Stylesheet"
    case javascript = "JavaScript"
    var id: String { rawValue }
}

enum UserScriptRunAt: String, Codable, CaseIterable, Identifiable {
    case documentStart = "Site Start"
    case documentEnd = "Site End"
    var id: String { rawValue }
}

struct UserScript: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var domainPattern: String   // e.g. "*wikipedia.org*", "github.com", "*"
    var type: UserScriptType
    var code: String
    var isEnabled: Bool = true
    var runAt: UserScriptRunAt = .documentEnd

    /// Glob-style wildcard matching against the URL's host + path.
    func matches(url: URL) -> Bool {
        guard isEnabled else { return false }
        guard let host = url.host else { return false }
        let subject = host + url.path
        return UserScript.globMatch(pattern: domainPattern, subject: subject)
    }

    static func globMatch(pattern: String, subject: String) -> Bool {
        if pattern == "*" { return true }
        // Convert glob pattern to regex: escape regex special chars, then replace * with .*
        var regexStr = NSRegularExpression.escapedPattern(for: pattern)
        regexStr = regexStr.replacingOccurrences(of: "\\*", with: ".*")
        regexStr = regexStr.replacingOccurrences(of: "\\?", with: ".")
        guard let regex = try? NSRegularExpression(pattern: "^" + regexStr + "$", options: .caseInsensitive) else {
            // fallback: simple contains check
            return subject.lowercased().contains(pattern.lowercased().replacingOccurrences(of: "*", with: ""))
        }
        let range = NSRange(subject.startIndex..., in: subject)
        return regex.firstMatch(in: subject, options: [], range: range) != nil
    }
}
