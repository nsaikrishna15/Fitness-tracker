import Foundation

// MARK: - Shared formatters (allocated once, reused everywhere)
// DateFormatter is expensive to create — never create inside a render loop.
enum SharedDateFormatter {
    static let dateKey: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .iso8601)
        return f
    }()

    static let shortWeekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

extension Date {
    /// Returns the Monday of the ISO week containing this date.
    func startOfWeek() -> Date {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: components) ?? self
    }

    /// "yyyy-MM-dd" string key for UserDefaults storage.
    var dateKey: String {
        SharedDateFormatter.dateKey.string(from: self)
    }

    /// Returns an array of the 7 days (Mon–Sun) for the week starting on `self`.
    func weekDays() -> [Date] {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: self) }
    }

    /// Short day label e.g. "MON"
    var shortWeekdayLabel: String {
        SharedDateFormatter.shortWeekday.string(from: self).uppercased()
    }

    /// Day-of-month number string.
    var dayOfMonthLabel: String {
        let cal = Calendar(identifier: .iso8601)
        return "\(cal.component(.day, from: self))"
    }

    /// True if this date falls on today's calendar day.
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// True if this date is strictly after today (calendar day).
    var isFutureDay: Bool {
        Calendar.current.startOfDay(for: self) > Calendar.current.startOfDay(for: Date())
    }

    /// True if this date is strictly before today (calendar day).
    var isPastDay: Bool {
        Calendar.current.startOfDay(for: self) < Calendar.current.startOfDay(for: Date())
    }
}
