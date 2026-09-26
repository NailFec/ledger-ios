import SwiftUI

struct ActivityView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var entries = appModel.entries

        List {
            Section {
                Picker("Kind", selection: $entries.filterKind) {
                    Text("All").tag(Optional<EntryKind>.none)
                    ForEach(EntryKind.allCases) { kind in
                        Text(kind.title).tag(Optional(kind))
                    }
                }
                Picker(Copy.Fields.account, selection: $entries.filterAccountId) {
                    Text("All").tag(Optional<UUID>.none)
                    ForEach(appModel.accounts.items) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
                Picker(Copy.Fields.allocation, selection: $entries.filterAllocation) {
                    Text("All").tag(Optional<Allocation>.none)
                    ForEach(Allocation.allCases) { allocation in
                        Text(allocation.title).tag(Optional(allocation))
                    }
                }
            }

            Section {
                ForEach(entries.filtered) { entry in
                    EntryRowView(
                        entry: entry,
                        accountName: appModel.accounts.items.first { $0.id == entry.accountId }?.name
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await appModel.entries.softDelete(entry) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(Copy.Navigation.activity)
        .overlay {
            if entries.filtered.isEmpty && !entries.isLoading {
                ContentUnavailableView("No entries", systemImage: "tray")
            }
        }
        .refreshable {
            await appModel.entries.reload()
        }
    }
}

struct EntryRowView: View {
    let entry: Entry
    let accountName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.name)
                    .font(.headline)
                Spacer()
                Text(Money.formatYuan(cents: displaySignedCents))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(displaySignedCents < 0 ? .primary : .green)
            }
            HStack {
                Text(entry.kind.title)
                if let accountName {
                    Text("·")
                    Text(accountName)
                }
                Spacer()
                Text(LedgerDates.display(entry.occurredOnDate))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let note = entry.amountNote, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var displaySignedCents: Int64 {
        switch entry.kind {
        case .income:
            return entry.amountCents
        case .expense:
            return -entry.amountCents
        case .loan:
            switch entry.loanType {
            case .borrow, .lend_settle:
                return entry.amountCents
            default:
                return -entry.amountCents
            }
        }
    }
}
