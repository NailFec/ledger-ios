import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section(Copy.Settings.email) {
                Text(appModel.session?.user.email ?? "—")
                    .foregroundStyle(.secondary)
            }

            Section {
                NavigationLink(Copy.Settings.tags) {
                    TagsSettingsView()
                }
                NavigationLink(Copy.Settings.incomeSources) {
                    IncomeSourcesSettingsView()
                }
            }

            Section {
                Button(Copy.Navigation.signOut) {
                    Task { await appModel.signOut() }
                }
            }

            Section {
                Button(Copy.Settings.deleteAccount, role: .destructive) {
                    confirmDelete = true
                }
                if let error = appModel.accountDeletionError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(Copy.Navigation.settings)
        .confirmationDialog(
            Copy.Settings.deleteAccount,
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(Copy.Settings.deleteAccount, role: .destructive) {
                Task { await appModel.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(Copy.Settings.deleteAccountBody)
        }
    }
}

struct TagsSettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var draftName = ""
    @State private var draftParentId: UUID?
    @State private var showCreate = false

    var body: some View {
        List {
            ForEach(appModel.tags.roots) { root in
                Section {
                    ForEach(appModel.tags.children(of: root)) { child in
                        Text(child.name)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await appModel.tags.softDelete(child) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    Button("Add child") {
                        draftParentId = root.id
                        draftName = ""
                        showCreate = true
                    }
                } header: {
                    HStack {
                        Text(root.name)
                        Spacer()
                        Button(role: .destructive) {
                            Task { await appModel.tags.softDelete(root) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .navigationTitle(Copy.Settings.tags)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New tag") {
                    draftParentId = nil
                    draftName = ""
                    showCreate = true
                }
            }
        }
        .alert(draftParentId == nil ? "New tag" : "New child tag", isPresented: $showCreate) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task { await appModel.tags.create(name: name, parentId: draftParentId) }
            }
        }
    }
}

struct IncomeSourcesSettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showCreate = false
    @State private var newName = ""

    var body: some View {
        List {
            ForEach(appModel.incomeSources.items) { source in
                Text(source.name)
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await appModel.incomeSources.softDelete(source) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle(Copy.Settings.incomeSources)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New source") {
                    newName = ""
                    showCreate = true
                }
            }
        }
        .alert("New source", isPresented: $showCreate) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task { await appModel.incomeSources.create(name: name) }
            }
        }
    }
}
