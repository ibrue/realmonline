import SwiftUI

@main
struct RealmOnlineApp: App {
    @State private var viewModel = RealmsViewModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
        } label: {
            Label(viewModel.menuBarTitle, systemImage: "hammer.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
