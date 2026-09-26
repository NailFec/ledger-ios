import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedTab: AppTab = .activity
    @State private var showComposer = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(Copy.Navigation.activity, systemImage: "list.bullet", value: .activity) {
                NavigationStack {
                    ActivityView()
                }
            }
            Tab(Copy.Navigation.insights, systemImage: "chart.bar", value: .insights) {
                NavigationStack {
                    InsightsView()
                }
            }
            Tab(Copy.Navigation.accounts, systemImage: "creditcard", value: .accounts) {
                NavigationStack {
                    AccountsView()
                }
            }
            Tab(Copy.Navigation.settings, systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tabViewBottomAccessory {
            NewEntryActionBar {
                showComposer = true
            }
        }
        .sheet(isPresented: $showComposer) {
            NewEntrySheet()
                .environment(appModel)
        }
        .task {
            await appModel.refreshAll()
        }
    }
}

private enum AppTab: Hashable {
    case activity, insights, accounts, settings
}

/// Liquid Glass only on the new-entry bottom action bar.
struct NewEntryActionBar: View {
    let action: () -> Void

    var body: some View {
        GlassEffectContainer {
            Button(action: action) {
                Label(Copy.Navigation.newEntry, systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}
