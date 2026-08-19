import SwiftUI

struct PopoverView: View {
    @Bindable var viewModel: RealmsViewModel

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.authState {
            case .unknown:
                ProgressView()
                    .padding(40)

            case .signedOut:
                SignInView(onSignIn: viewModel.signIn)

            case .awaitingCode(let code, _):
                awaitingCodeView(code: code)

            case .signingIn:
                signingInView

            case .signedIn(let username):
                signedInView(username: username)

            case .error(let message):
                errorView(message: message)
            }
        }
        .frame(width: 280)
        .onAppear { viewModel.onPopoverAppear() }
    }

    // MARK: - Awaiting Code

    private func awaitingCodeView(code: String) -> some View {
        VStack(spacing: 12) {
            Text("Sign in at microsoft.com/link")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(code)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .textSelection(.enabled)

            Text("Code copied to clipboard")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            ProgressView()
                .controlSize(.small)
                .padding(.top, 4)

            Button("Cancel") {
                viewModel.cancelSignIn()
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    // MARK: - Signing In

    private var signingInView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Signing in...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    // MARK: - Signed In

    private func signedInView(username: String) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text(username)
                    .font(.headline)
                Spacer()
                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Realm list
            if viewModel.realms.isEmpty {
                Text("No realms found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(20)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(viewModel.realms) { realm in
                            RealmRowView(
                                realm: realm,
                                isSelected: viewModel.selectedRealmID == realm.id
                            ) {
                                viewModel.selectedRealmID = realm.id
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Footer
            HStack(spacing: 12) {
                Button("Refresh") {
                    viewModel.refreshInBackground()
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Spacer()

                Button("Sign Out") {
                    viewModel.signOut()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.yellow)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Button("Try Again") { viewModel.signIn() }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(20)
    }
}
