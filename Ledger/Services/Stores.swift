import Foundation
import Supabase

@Observable
@MainActor
final class EntryStore {
    private(set) var items: [Entry] = []
    private(set) var isLoading = false
    var errorMessage: String?

    var filterKind: EntryKind?
    var filterAccountId: UUID?
    var filterAllocation: Allocation?

    private var client: SupabaseClient?

    func bind(to client: SupabaseClient) {
        self.client = client
    }

    func reset() {
        items = []
        errorMessage = nil
    }

    var filtered: [Entry] {
        items.filter { entry in
            if let filterKind, entry.kind != filterKind { return false }
            if let filterAccountId, entry.accountId != filterAccountId { return false }
            if let filterAllocation, entry.allocation != filterAllocation { return false }
            return true
        }
    }

    func reload() async {
        guard let client else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [Entry] = try await client
                .from("entries")
                .select()
                .is("deleted_at", value: nil)
                .order("occurred_on", ascending: false)
                .order("created_at", ascending: false)
                .execute()
                .value
            items = rows
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func softDelete(_ entry: Entry) async {
        guard let client else { return }
        do {
            try await client
                .from("entries")
                .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: entry.id)
                .execute()
            items.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(_ payload: EntryInsert) async throws -> Entry {
        guard let client else { throw LedgerError.notConfigured }
        let created: Entry = try await client
            .from("entries")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        await reload()
        return created
    }
}

@Observable
@MainActor
final class AccountStore {
    private(set) var items: [Account] = []
    private(set) var balances: [UUID: Int64] = [:]
    private(set) var loanPosition: LoanPosition?
    private(set) var isLoading = false
    var errorMessage: String?

    private var client: SupabaseClient?

    func bind(to client: SupabaseClient) {
        self.client = client
    }

    func reset() {
        items = []
        balances = [:]
        loanPosition = nil
        errorMessage = nil
    }

    var defaultAccount: Account? {
        items.min { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return (lhs.createdAt ?? .distantFuture) < (rhs.createdAt ?? .distantFuture)
        }
    }

    func reload() async {
        guard let client else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [Account] = try await client
                .from("accounts")
                .select()
                .is("deleted_at", value: nil)
                .order("sort_order", ascending: true)
                .order("created_at", ascending: true)
                .execute()
                .value
            items = rows
            await reloadBalances()
            await reloadLoanPosition()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadBalances() async {
        guard let client else { return }
        do {
            let rows: [AccountBalance] = try await client
                .from("account_balances")
                .select()
                .execute()
                .value
            balances = Dictionary(uniqueKeysWithValues: rows.map { ($0.accountId, $0.balanceCents) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadLoanPosition() async {
        guard let client else { return }
        do {
            let rows: [LoanPosition] = try await client
                .from("loan_positions")
                .select()
                .execute()
                .value
            loanPosition = rows.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(name: String) async {
        guard let client else { return }
        let nextOrder = (items.map(\.sortOrder).max() ?? -1) + 1
        struct Insert: Encodable {
            let name: String
            let sort_order: Int
        }
        do {
            try await client
                .from("accounts")
                .insert(Insert(name: name, sort_order: nextOrder))
                .execute()
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rename(_ account: Account, to name: String) async {
        guard let client else { return }
        do {
            try await client
                .from("accounts")
                .update(["name": name])
                .eq("id", value: account.id)
                .execute()
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reorder(_ accounts: [Account]) async {
        guard let client else { return }
        struct Update: Encodable {
            let sort_order: Int
        }
        do {
            for (index, account) in accounts.enumerated() {
                try await client
                    .from("accounts")
                    .update(Update(sort_order: index))
                    .eq("id", value: account.id)
                    .execute()
            }
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func softDelete(_ account: Account) async {
        guard let client else { return }
        do {
            try await client
                .from("accounts")
                .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: account.id)
                .execute()
            await reload()
        } catch {
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("Cannot delete the last account") {
                errorMessage = Copy.Accounts.cannotDeleteLast
            } else {
                errorMessage = message
            }
        }
    }
}

@Observable
@MainActor
final class TagStore {
    private(set) var items: [Tag] = []
    private var client: SupabaseClient?

    func bind(to client: SupabaseClient) {
        self.client = client
    }

    func reset() { items = [] }

    var roots: [Tag] {
        items.filter { $0.parentId == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func children(of parent: Tag) -> [Tag] {
        items.filter { $0.parentId == parent.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func reload() async {
        guard let client else { return }
        do {
            items = try await client
                .from("tags")
                .select()
                .is("deleted_at", value: nil)
                .order("sort_order", ascending: true)
                .execute()
                .value
        } catch {
            // Surface via settings when needed.
        }
    }

    func create(name: String, parentId: UUID?) async {
        guard let client else { return }
        let siblings = items.filter { $0.parentId == parentId }
        let nextOrder = (siblings.map(\.sortOrder).max() ?? -1) + 1
        struct Insert: Encodable {
            let name: String
            let parent_id: UUID?
            let sort_order: Int
        }
        do {
            try await client
                .from("tags")
                .insert(Insert(name: name, parent_id: parentId, sort_order: nextOrder))
                .execute()
            await reload()
        } catch {}
    }

    func softDelete(_ tag: Tag) async {
        guard let client else { return }
        do {
            try await client
                .from("tags")
                .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: tag.id)
                .execute()
            await reload()
        } catch {}
    }
}

@Observable
@MainActor
final class IncomeSourceStore {
    private(set) var items: [IncomeSource] = []
    private var client: SupabaseClient?

    func bind(to client: SupabaseClient) {
        self.client = client
    }

    func reset() { items = [] }

    func reload() async {
        guard let client else { return }
        do {
            items = try await client
                .from("income_sources")
                .select()
                .is("deleted_at", value: nil)
                .order("sort_order", ascending: true)
                .execute()
                .value
        } catch {}
    }

    func create(name: String) async {
        guard let client else { return }
        let nextOrder = (items.map(\.sortOrder).max() ?? -1) + 1
        struct Insert: Encodable {
            let name: String
            let sort_order: Int
        }
        do {
            try await client
                .from("income_sources")
                .insert(Insert(name: name, sort_order: nextOrder))
                .execute()
            await reload()
        } catch {}
    }

    func softDelete(_ source: IncomeSource) async {
        guard let client else { return }
        do {
            try await client
                .from("income_sources")
                .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: source.id)
                .execute()
            await reload()
        } catch {}
    }
}

enum LedgerError: LocalizedError {
    case notConfigured
    case missingUser
    case attachmentTooLarge
    case unsupportedAttachment

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Supabase is not configured."
        case .missingUser: "Not signed in."
        case .attachmentTooLarge: "Attachments must be 10 MB or smaller."
        case .unsupportedAttachment: "Only images and PDF files are supported."
        }
    }
}
