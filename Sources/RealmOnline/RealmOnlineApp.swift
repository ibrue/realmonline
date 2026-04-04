import SwiftUI
import AppKit

@main
struct RealmOnlineApp: App {
    @State private var viewModel = RealmsViewModel()

    init() {
        // Required for SPM-built executables that are not inside a .app bundle.
        // Without this, macOS does not treat the process as a GUI application,
        // so NSStatusBar (used by MenuBarExtra) never creates the status item.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
        } label: {
            Label(viewModel.menuBarTitle, systemImage: "hammer.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
