import SwiftUI

@main
struct RealmOnlineApp: App {
    @State private var viewModel = RealmsViewModel()

    var body: some Scene {
        MenuBarExtra(viewModel.menuBarTitle, systemImage: "pickaxe") {
            PopoverView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
