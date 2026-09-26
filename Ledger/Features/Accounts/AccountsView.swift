import SwiftUI

struct AccountsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showNewAccount = false
    @State private var newAccountName = ""
    @State private var renameTarget: Account?
    @State private var renameText = ""

    var body: some View {
        List {
            if let position = appModel.accounts.loanPosition {
                Section {
                    LabeledContent(Copy.Accounts.toReceive, value: Money.formatYuan(cents: position.receivableCents))
                    LabeledContent(Copy.Accounts.toRepay, value: Money.formatYuan(cents: position.payableCents))
                }
            }

            Section {
                ForEach(appModel.accounts.items) { account in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                            if account.id == appModel.accounts.defaultAccount?.id {
                                Text("Default")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(Money.formatYuan(cents: appModel.accounts.balances[account.id] ?? 0))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button("Rename") {
                            renameTarget = account
                            renameText = account.name
                        }
                        Button("Delete", role: .destructive) {
                            Task { await appModel.accounts.softDelete(account) }
                        }
                    }
                }
                .onMove { indices, newOffset in
                    var ordered = appModel.accounts.items
                    ordered.move(fromOffsets: indices, toOffset: newOffset)
                    Task { await appModel.accounts.reorder(ordered) }
                }
            } header: {
                Text(Copy.Accounts.balance)
            } footer: {
                if let error = appModel.accounts.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(Copy.Navigation.accounts)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(Copy.Accounts.newAccount) {
                    newAccountName = ""
                    showNewAccount = true
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .alert(Copy.Accounts.newAccount, isPresented: $showNewAccount) {
            TextField("Name", text: $newAccountName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let name = newAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task { await appModel.accounts.create(name: name) }
            }
        }
        .alert("Rename", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") {
                guard let account = renameTarget else { return }
                let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task { await appModel.accounts.rename(account, to: name) }
                renameTarget = nil
            }
        }
        .refreshable {
            await appModel.accounts.reload()
        }
    }
}
