import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class AppModel {
    private(set) var secrets: AppSecrets?
    private(set) var client: SupabaseClient?
    private(set) var session: Session?
    private(set) var isBootstrapping = true
    var authErrorMessage: String?
    var accountDeletionError: String?

    let entries = EntryStore()
    let accounts = AccountStore()
    let tags = TagStore()
    let incomeSources = IncomeSourceStore()

    private var authTask: Task<Void, Never>?
    private var realtimeTask: Task<Void, Never>?

    init() {
        reloadSecrets()
    }

    var isConfigured: Bool { secrets != nil && client != nil }
    var isSignedIn: Bool { session != nil }

    func reloadSecrets() {
        secrets = AppSecrets.loadFromBundle()
        guard let secrets else {
            client = nil
            session = nil
            isBootstrapping = false
            return
        }

        let supabase = SupabaseClient(
            supabaseURL: secrets.url,
            supabaseKey: secrets.anonKey,
            options: SupabaseClientOptions(
                auth: .init(redirectToURL: URL(string: "ledger://auth-callback"))
            )
        )
        client = supabase
        entries.bind(to: supabase)
        accounts.bind(to: supabase)
        tags.bind(to: supabase)
        incomeSources.bind(to: supabase)
        startAuthListening(supabase)
    }

    func handleOpenURL(_ url: URL) async {
        guard let client else { return }
        do {
            _ = try await client.auth.session(from: url)
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        guard let client else { return }
        do {
            try await client.auth.signOut()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    /// Deletes Storage objects for this user, then calls `delete_account()`.
    func deleteAccount() async {
        guard let client, let userId = session?.user.id else { return }
        accountDeletionError = nil
        do {
            try await AccountDeletionService(client: client).deleteAccount(userId: userId)
            try? await client.auth.signOut()
            session = nil
            clearLocalCaches()
            stopRealtime()
        } catch {
            accountDeletionError = error.localizedDescription
        }
    }

    private func startAuthListening(_ client: SupabaseClient) {
        authTask?.cancel()
        authTask = Task {
            for await (event, session) in client.auth.authStateChanges {
                self.session = session
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed:
                    if session != nil {
                        await refreshAll()
                        startRealtime(client)
                    }
                case .signedOut:
                    clearLocalCaches()
                    stopRealtime()
                default:
                    break
                }
                isBootstrapping = false
            }
        }
    }

    private func startRealtime(_ client: SupabaseClient) {
        stopRealtime()
        realtimeTask = Task {
            await RealtimeCoordinator(
                client: client,
                onEntriesChange: { [weak self] in
                    await self?.entries.reload()
                    await self?.accounts.reloadBalances()
                },
                onAccountsChange: { [weak self] in
                    await self?.accounts.reload()
                }
            ).run()
        }
    }

    private func stopRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    func refreshAll() async {
        await accounts.reload()
        await entries.reload()
        await tags.reload()
        await incomeSources.reload()
    }

    private func clearLocalCaches() {
        entries.reset()
        accounts.reset()
        tags.reset()
        incomeSources.reset()
    }
}
