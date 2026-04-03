import SwiftUI

struct SignInView: View {
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("RealmOnline")
                .font(.headline)

            Text("See who's on your Minecraft Realms")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: onSignIn) {
                Label("Sign in with Microsoft", systemImage: "person.badge.key")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(24)
    }
}
