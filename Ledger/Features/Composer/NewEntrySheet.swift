import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct NewEntrySheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedKind: EntryKind?

    var body: some View {
        NavigationStack {
            Group {
                if let selectedKind {
                    EntryComposerView(kind: selectedKind) {
                        dismiss()
                    }
                } else {
                    KindPickerView { kind in
                        selectedKind = kind
                    }
                }
            }
            .navigationTitle(selectedKind?.title ?? Copy.Navigation.newEntry)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct KindPickerView: View {
    let onSelect: (EntryKind) -> Void

    var body: some View {
        List {
            ForEach(EntryKind.allCases) { kind in
                Button(kind.title) {
                    onSelect(kind)
                }
            }
        }
    }
}

struct EntryComposerView: View {
    @Environment(AppModel.self) private var appModel
    let kind: EntryKind
    let onSaved: () -> Void

    @State private var amountText = ""
    @State private var amountNote = ""
    @State private var accountId: UUID?
    @State private var name = ""
    @State private var occurredOn = Date()
    @State private var allocation: Allocation = .day
    @State private var loanType: LoanType = .borrow
    @State private var selectedTagIds: Set<UUID> = []
    @State private var sourceId: UUID?
    @State private var repeats = false
    @State private var recurrenceMode: RecurrenceMode = .calendar
    @State private var recurrenceUnit: RecurrenceUnit = .month
    @State private var everyDaysText = "30"
    @State private var note = ""
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var pickedFiles: [PickedAttachment] = []
    @State private var showImporter = false

    private enum RecurrenceMode: String, CaseIterable, Identifiable {
        case calendar
        case interval
        var id: String { rawValue }
        var title: String {
            switch self {
            case .calendar: "Calendar"
            case .interval: Copy.Subscription.everyNDays
            }
        }
    }

    var body: some View {
        Form {
            Section {
                TextField(Copy.Fields.amount, text: $amountText)
                    .keyboardType(.decimalPad)
                TextField(Copy.Fields.amountNote, text: $amountNote, prompt: Text(Copy.Fields.amountNotePlaceholder))
                    .onChange(of: amountNote) { _, value in
                        if value.count > 60 { amountNote = String(value.prefix(60)) }
                    }
            }

            Section {
                Picker(Copy.Fields.account, selection: $accountId) {
                    ForEach(appModel.accounts.items) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
                TextField(Copy.Fields.name, text: $name)
                DatePicker(Copy.Fields.date, selection: $occurredOn, displayedComponents: .date)
            }

            if kind != .loan {
                Section(Copy.Fields.allocation) {
                    Picker(Copy.Fields.allocation, selection: $allocation) {
                        ForEach(Allocation.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if kind == .expense {
                Section(Copy.Fields.tags) {
                    ForEach(appModel.tags.roots) { root in
                        let children = appModel.tags.children(of: root)
                        if children.isEmpty {
                            tagToggle(root)
                        } else {
                            DisclosureGroup(root.name) {
                                ForEach(children) { child in
                                    tagToggle(child)
                                }
                            }
                        }
                    }
                }

                Section(Copy.Fields.subscription) {
                    Toggle(Copy.Subscription.repeats, isOn: $repeats)
                    if repeats {
                        Picker("Rule", selection: $recurrenceMode) {
                            ForEach(RecurrenceMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        if recurrenceMode == .calendar {
                            Picker("Unit", selection: $recurrenceUnit) {
                                ForEach(RecurrenceUnit.allCases) { unit in
                                    Text(unit.title).tag(unit)
                                }
                            }
                        } else {
                            TextField(Copy.Subscription.everyNDays, text: $everyDaysText)
                                .keyboardType(.numberPad)
                        }
                        if let next = nextSubscriptionDate {
                            Text(Copy.Subscription.next(LedgerDates.display(next)))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if kind == .income {
                Section(Copy.Fields.source) {
                    Picker(Copy.Fields.source, selection: $sourceId) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(appModel.incomeSources.items) { source in
                            Text(source.name).tag(Optional(source.id))
                        }
                    }
                }
            }

            if kind == .loan {
                Section(Copy.Fields.type) {
                    Picker(Copy.Fields.type, selection: $loanType) {
                        ForEach(LoanType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }
            }

            Section(Copy.Fields.note) {
                TextField(Copy.Fields.note, text: $note, axis: .vertical)
                    .lineLimit(3...8)
                    .onChange(of: note) { _, value in
                        if value.count > 2000 { note = String(value.prefix(2000)) }
                    }
            }

            Section(Copy.Fields.attachments) {
                PhotosPicker(selection: $photoItems, maxSelectionCount: 5, matching: .images) {
                    Label("Add photos", systemImage: "photo")
                }
                .onChange(of: photoItems) { _, items in
                    Task { await loadPhotos(items) }
                }
                Button {
                    showImporter = true
                } label: {
                    Label("Add PDF or image", systemImage: "doc")
                }
                ForEach(pickedFiles) { file in
                    Text(file.fileName)
                        .font(.footnote)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(isSaving ? "Saving…" : "Save") {
                    Task { await save() }
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            accountId = appModel.accounts.defaultAccount?.id
            allocation = kind == .expense ? .day : .none
            loanType = .borrow
            name = LedgerDates.defaultEntryName(kind: kind, occurredOn: occurredOn)
        }
        .onChange(of: occurredOn) { _, date in
            if name.hasPrefix("\(kind.title) · ") || name.isEmpty {
                name = LedgerDates.defaultEntryName(kind: kind, occurredOn: date)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf, .image, .jpeg, .png, .webP, .gif, .heic],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    ingestFileURL(url)
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func tagToggle(_ tag: Tag) -> some View {
        Toggle(isOn: Binding(
            get: { selectedTagIds.contains(tag.id) },
            set: { isOn in
                if isOn { selectedTagIds.insert(tag.id) }
                else { selectedTagIds.remove(tag.id) }
            }
        )) {
            Text(tag.name)
        }
    }

    private var nextSubscriptionDate: Date? {
        guard repeats else { return nil }
        switch recurrenceMode {
        case .calendar:
            return Recurrence.nextDate(
                after: occurredOn,
                kind: .calendar,
                unit: recurrenceUnit,
                everyDays: nil
            )
        case .interval:
            return Recurrence.nextDate(
                after: occurredOn,
                kind: .interval,
                unit: nil,
                everyDays: Int(everyDaysText)
            )
        }
    }

    private func save() async {
        guard let client = appModel.client else { return }
        guard let cents = Money.parseYuanToCents(amountText) else {
            errorMessage = "Enter a valid amount greater than zero."
            return
        }
        guard let accountId else {
            errorMessage = "Pick an account."
            return
        }

        var resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolvedName.isEmpty {
            resolvedName = LedgerDates.defaultEntryName(kind: kind, occurredOn: occurredOn)
        }

        var payload = EntryInsert(
            kind: kind,
            amountCents: cents,
            amountNote: amountNote.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            accountId: accountId,
            name: resolvedName,
            occurredOn: LedgerDates.string(from: occurredOn),
            allocation: kind == .loan ? nil : allocation,
            loanType: kind == .loan ? loanType : nil,
            tagIds: kind == .expense ? Array(selectedTagIds) : [],
            sourceId: kind == .income ? sourceId : nil,
            recurrenceKind: nil,
            recurrenceUnit: nil,
            recurrenceEveryDays: nil,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )

        if kind == .expense && repeats {
            switch recurrenceMode {
            case .calendar:
                payload.recurrenceKind = .calendar
                payload.recurrenceUnit = recurrenceUnit
            case .interval:
                guard let days = Int(everyDaysText), (1...3650).contains(days) else {
                    errorMessage = "Every N days must be between 1 and 3650."
                    return
                }
                payload.recurrenceKind = .interval
                payload.recurrenceEveryDays = days
            }
        }

        isSaving = true
        defer { isSaving = false }
        do {
            let created = try await appModel.entries.create(payload)
            if !pickedFiles.isEmpty, let userId = appModel.session?.user.id {
                let attachments = AttachmentService(client: client)
                for file in pickedFiles {
                    _ = try await attachments.upload(
                        userId: userId,
                        entryId: created.id,
                        fileName: file.fileName,
                        data: file.data,
                        mimeType: file.mimeType
                    )
                }
            }
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let name = "photo-\(UUID().uuidString.prefix(8)).jpg"
                pickedFiles.append(PickedAttachment(fileName: name, data: data, mimeType: "image/jpeg"))
            }
        }
        photoItems = []
    }

    private func ingestFileURL(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let mime: String
        switch url.pathExtension.lowercased() {
        case "pdf": mime = "application/pdf"
        case "png": mime = "image/png"
        case "jpg", "jpeg": mime = "image/jpeg"
        case "heic": mime = "image/heic"
        case "heif": mime = "image/heif"
        case "webp": mime = "image/webp"
        case "gif": mime = "image/gif"
        default:
            errorMessage = LedgerError.unsupportedAttachment.localizedDescription
            return
        }
        if data.count > AttachmentService.maxBytes {
            errorMessage = LedgerError.attachmentTooLarge.localizedDescription
            return
        }
        pickedFiles.append(PickedAttachment(fileName: url.lastPathComponent, data: data, mimeType: mime))
    }
}

struct PickedAttachment: Identifiable {
    let id = UUID()
    let fileName: String
    let data: Data
    let mimeType: String
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
