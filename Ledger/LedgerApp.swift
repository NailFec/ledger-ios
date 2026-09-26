import SwiftUI

@main
struct LedgerApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .onOpenURL { url in
                    Task { await appModel.handleOpenURL(url) }
                }
        }
    }
}
