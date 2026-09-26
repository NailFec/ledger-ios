import Foundation

enum Recurrence {
    /// Next occurrence after `occurredOn` for a stored rule. Does not insert rows.
    static func nextDate(
        after occurredOn: Date,
        kind: RecurrenceKind?,
        unit: RecurrenceUnit?,
        everyDays: Int?
    ) -> Date? {
        guard let kind else { return nil }
        let calendar = Calendar.current
        switch kind {
        case .calendar:
            guard let unit else { return nil }
            switch unit {
            case .day:
                return calendar.date(byAdding: .day, value: 1, to: occurredOn)
            case .week:
                return calendar.date(byAdding: .weekOfYear, value: 1, to: occurredOn)
            case .month:
                return calendar.date(byAdding: .month, value: 1, to: occurredOn)
            case .year:
                return calendar.date(byAdding: .year, value: 1, to: occurredOn)
            }
        case .interval:
            guard let everyDays, everyDays >= 1, everyDays <= 3650 else { return nil }
            return calendar.date(byAdding: .day, value: everyDays, to: occurredOn)
        }
    }
}
