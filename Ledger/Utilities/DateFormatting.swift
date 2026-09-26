import Foundation

enum LedgerDates {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US")
        f.timeZone = TimeZone.current
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static let monDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "MMM d"
        return f
    }()

    static func string(from date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        dayFormatter.date(from: string)
    }

    static func display(_ date: Date) -> String {
        displayDayFormatter.string(from: date)
    }

    /// Default entry name style: `Expense · Sep 26`.
    static func defaultEntryName(kind: EntryKind, occurredOn: Date) -> String {
        "\(kind.title) · \(monDayFormatter.string(from: occurredOn))"
    }
}
