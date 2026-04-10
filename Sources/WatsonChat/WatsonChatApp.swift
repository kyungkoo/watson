import SwiftUI

@main
struct WatsonChatApp: App {
    @State private var viewModel = ChatViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 900, minHeight: 650)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 750)
    }
}
