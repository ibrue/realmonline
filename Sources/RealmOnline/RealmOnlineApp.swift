import SwiftUI
import AppKit

/// Delegate that sets the activation policy at the correct point in the
/// lifecycle — after NSApplication has finished launching.  The embedded
/// Info.plist already has LSUIElement=true, but bare SPM executables
/// sometimes ignore the embedded plist, so we set it explicitly here.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@main
struct RealmOnlineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
