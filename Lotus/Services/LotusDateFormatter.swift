//
//  LotusDateFormatter.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import Foundation

/// Shared date and relative-time formatting for internal management views (History, Bookmarks, Downloads).
enum LotusDateFormatter {
    private static let dayFormatterSameYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    private static let dayFormatterDifferentYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /// Produces a human-readable day heading ("Today", "Yesterday", "Wednesday, August 28").
    static func dayLabel(for date: Date, relativeTo referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let currentYear = calendar.component(.year, from: referenceDate)
            let dateYear = calendar.component(.year, from: date)
            if dateYear == currentYear {
                return dayFormatterSameYear.string(from: date)
            } else {
                return dayFormatterDifferentYear.string(from: date)
            }
        }
    }

    /// Produces a concise relative time string ("Just now", "5m ago", "2h ago", or "3:45 PM").
    static func relativeTime(for date: Date, relativeTo referenceDate: Date = Date()) -> String {
        let interval = referenceDate.timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = max(1, Int(interval / 60))
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = max(1, Int(interval / 3600))
            return "\(hours)h ago"
        } else {
            return timeFormatter.string(from: date)
        }
    }
}
