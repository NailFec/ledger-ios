import Foundation
import Supabase

struct AccountDeletionService {
    let client: SupabaseClient

    /// Removes objects under `attachments/{userId}/…`, then calls `delete_account()`.
    func deleteAccount(userId: UUID) async throws {
        try await removeAllAttachments(for: userId)
        try await client.rpc("delete_account").execute()
    }

    private func removeAllAttachments(for userId: UUID) async throws {
        let bucket = client.storage.from("attachments")
        let root = userId.uuidString.lowercased()
        let entryFolders = try await bucket.list(path: root)
        var paths: [String] = []

        for folder in entryFolders {
            let prefix = "\(root)/\(folder.name)"
            let files = try await bucket.list(path: prefix)
            for file in files where file.id != nil {
                paths.append("\(prefix)/\(file.name)")
            }
        }

        let batchSize = 100
        var index = 0
        while index < paths.count {
            let end = min(index + batchSize, paths.count)
            let batch = Array(paths[index..<end])
            _ = try await bucket.remove(paths: batch)
            index = end
        }
    }
}

struct AttachmentService {
    let client: SupabaseClient
    static let maxBytes: Int64 = 10_485_760
    static let allowedMIME: Set<String> = [
        "image/jpeg", "image/png", "image/heic", "image/heif",
        "image/webp", "image/gif", "application/pdf"
    ]

    func upload(
        userId: UUID,
        entryId: UUID,
        fileName: String,
        data: Data,
        mimeType: String
    ) async throws -> AttachmentRecord {
        guard data.count > 0, data.count <= Self.maxBytes else {
            throw LedgerError.attachmentTooLarge
        }
        guard Self.allowedMIME.contains(mimeType.lowercased()) else {
            throw LedgerError.unsupportedAttachment
        }

        let safeName = fileName
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let path = "\(userId.uuidString.lowercased())/\(entryId.uuidString.lowercased())/\(safeName)"

        try await client.storage
            .from("attachments")
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: mimeType, upsert: false)
            )

        struct Insert: Encodable {
            let entry_id: UUID
            let storage_path: String
            let file_name: String
            let mime_type: String
            let size_bytes: Int64
        }

        let record: AttachmentRecord = try await client
            .from("attachments")
            .insert(
                Insert(
                    entry_id: entryId,
                    storage_path: path,
                    file_name: safeName,
                    mime_type: mimeType,
                    size_bytes: Int64(data.count)
                )
            )
            .select()
            .single()
            .execute()
            .value
        return record
    }

    func list(for entryId: UUID) async throws -> [AttachmentRecord] {
        try await client
            .from("attachments")
            .select()
            .eq("entry_id", value: entryId)
            .is("deleted_at", value: nil)
            .execute()
            .value
    }
}

struct RealtimeCoordinator {
    let client: SupabaseClient
    let onEntriesChange: @MainActor () async -> Void
    let onAccountsChange: @MainActor () async -> Void

    func run() async {
        let channel = await client.channel("ledger-sync")

        let entriesStream = await channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "entries"
        )
        let accountsStream = await channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "accounts"
        )

        await channel.subscribe()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in entriesStream {
                    await onEntriesChange()
                }
            }
            group.addTask {
                for await _ in accountsStream {
                    await onAccountsChange()
                }
            }
            await group.next()
            group.cancelAll()
        }

        await client.removeChannel(channel)
    }
}
