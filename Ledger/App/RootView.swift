import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if !appModel.isConfigured {
                SecretsSetupView()
            } else if appModel.isBootstrapping {
                ProgressView("Loading…")
            } else if appModel.isSignedIn {
                MainTabView()
            } else {
                AuthView()
            }
        }
    }
}

struct SecretsSetupView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Secrets required", systemImage: "key.fill")
            } description: {
                Text(
                    "Copy Ledger/Secrets.example.plist to Ledger/Secrets.plist and set SUPABASE_URL and SUPABASE_ANON_KEY, then rebuild."
                )
            } actions: {
                Button("Check again") {
                    appModel.reloadSecrets()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Ledger")
        }
    }
}
