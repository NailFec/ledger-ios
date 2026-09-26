import Foundation

enum EntryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense
    case income
    case loan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense: Copy.EntryKind.expense
        case .income: Copy.EntryKind.income
        case .loan: Copy.EntryKind.loan
        }
    }
}

enum Allocation: String, Codable, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month
    case year
    case reserved
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: Copy.Allocation.day
        case .week: Copy.Allocation.week
        case .month: Copy.Allocation.month
        case .year: Copy.Allocation.year
        case .reserved: Copy.Allocation.reserved
        case .none: Copy.Allocation.none
        }
    }

    static var expenseDefault: Allocation { .day }
    static var incomeDefault: Allocation { .none }
}

enum LoanType: String, Codable, CaseIterable, Identifiable, Sendable {
    case lend
    case borrow
    case lend_settle
    case borrow_settle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lend: Copy.LoanType.lend
        case .borrow: Copy.LoanType.borrow
        case .lend_settle: Copy.LoanType.lendSettle
        case .borrow_settle: Copy.LoanType.borrowSettle
        }
    }

    static var defaultSelection: LoanType { .borrow }
}

enum RecurrenceKind: String, Codable, Sendable {
    case calendar
    case interval
}

enum RecurrenceUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: Copy.Subscription.everyDay
        case .week: Copy.Subscription.everyWeek
        case .month: Copy.Subscription.everyMonth
        case .year: Copy.Subscription.everyYear
        }
    }
}

struct Account: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var sortOrder: Int
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct AccountBalance: Identifiable, Codable, Hashable, Sendable {
    var accountId: UUID
    var balanceCents: Int64

    var id: UUID { accountId }

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case balanceCents = "balance_cents"
    }
}

struct LoanPosition: Codable, Hashable, Sendable {
    var receivableCents: Int64
    var payableCents: Int64

    enum CodingKeys: String, CodingKey {
        case receivableCents = "receivable_cents"
        case payableCents = "payable_cents"
    }
}

struct Tag: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var parentId: UUID?
    var name: String
    var sortOrder: Int
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case parentId = "parent_id"
        case sortOrder = "sort_order"
        case deletedAt = "deleted_at"
    }
}

struct IncomeSource: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var sortOrder: Int
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case sortOrder = "sort_order"
        case deletedAt = "deleted_at"
    }
}

struct Entry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: EntryKind
    var amountCents: Int64
    var amountNote: String?
    var accountId: UUID
    var name: String
    /// Civil date `yyyy-MM-dd` from Postgres `date`.
    var occurredOn: String
    var allocation: Allocation?
    var loanType: LoanType?
    var tagIds: [UUID]
    var sourceId: UUID?
    var recurrenceKind: RecurrenceKind?
    var recurrenceUnit: RecurrenceUnit?
    var recurrenceEveryDays: Int?
    var note: String?
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?

    var occurredOnDate: Date {
        LedgerDates.date(from: occurredOn) ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, name, note, allocation
        case amountCents = "amount_cents"
        case amountNote = "amount_note"
        case accountId = "account_id"
        case occurredOn = "occurred_on"
        case loanType = "loan_type"
        case tagIds = "tag_ids"
        case sourceId = "source_id"
        case recurrenceKind = "recurrence_kind"
        case recurrenceUnit = "recurrence_unit"
        case recurrenceEveryDays = "recurrence_every_days"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct AttachmentRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var entryId: UUID
    var storagePath: String
    var fileName: String
    var mimeType: String
    var sizeBytes: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case entryId = "entry_id"
        case storagePath = "storage_path"
        case fileName = "file_name"
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
    }
}

struct EntryInsert: Encodable, Sendable {
    var kind: EntryKind
    var amountCents: Int64
    var amountNote: String?
    var accountId: UUID
    var name: String
    var occurredOn: String
    var allocation: Allocation?
    var loanType: LoanType?
    var tagIds: [UUID]
    var sourceId: UUID?
    var recurrenceKind: RecurrenceKind?
    var recurrenceUnit: RecurrenceUnit?
    var recurrenceEveryDays: Int?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case kind, name, note, allocation
        case amountCents = "amount_cents"
        case amountNote = "amount_note"
        case accountId = "account_id"
        case occurredOn = "occurred_on"
        case loanType = "loan_type"
        case tagIds = "tag_ids"
        case sourceId = "source_id"
        case recurrenceKind = "recurrence_kind"
        case recurrenceUnit = "recurrence_unit"
        case recurrenceEveryDays = "recurrence_every_days"
    }
}
