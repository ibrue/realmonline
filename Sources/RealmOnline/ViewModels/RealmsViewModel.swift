import Foundation
import AppKit
import Observation

@MainActor @Observable
final class RealmsViewModel {
    var authState: AuthState = .unknown
    var realms: [RealmInfo] = []
    var selectedRealmID: Int?
    var isRefreshing = false

    private var tokenInfo: MinecraftTokenInfo?
    private var pollTask: Task<Void, Never>?
    private var signInTask: Task<Void, Never>?
    private let authService = AuthService.shared

    init() {
        // Kick off immediately at launch so the menu bar title is correct
        // before the popover is ever opened.
        Task { await checkCachedToken() }
    }

    var menuBarTitle: String {
        guard case .signedIn = authState else { return "\u{26CF} ?" }

        guard let selected = selectedRealm else {
            let total = realms.reduce(0) { $0 + $1.playerCount }
            return "\u{26CF} \(total)"
        }

        switch selected.state {
        case .closed: return "\u{26CF} off"
        case .open, .unknown: return "\u{26CF} \(selected.playerCount)"
        }
    }

    var selectedRealm: RealmInfo? {
        if let id = selectedRealmID {
            return realms.first { $0.id == id }
        }
        return realms.first { $0.state == .open } ?? realms.first
    }

    // MARK: - Lifecycle

    /// Called each time the popover opens — refresh right away if signed in.
    func onPopoverAppear() {
        if case .signedIn = authState {
            refreshInBackground()
        }
    }

    private func checkCachedToken() async {
        if let token = await authService.getValidToken() {
            tokenInfo = token
            authState = .signedIn(username: token.username)
            await refresh()
            startPolling()
        } else {
            authState = .signedOut
        }
    }

    // MARK: - Sign In

    func signIn() {
        signInTask?.cancel()
        signInTask = Task {
            do {
                let deviceCode = try await authService.requestDeviceCode()

                // Copy code to clipboard
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(deviceCode.userCode, forType: .string)

                // Show the code and keep showing it while we wait for the
                // user to enter it in the browser.
                authState = .awaitingCode(
                    userCode: deviceCode.userCode,
                    verificationURI: deviceCode.verificationUri
                )

                // Open browser
                if let url = URL(string: deviceCode.verificationUri) {
                    NSWorkspace.shared.open(url)
                }

                let msToken = try await authService.pollForMSToken(deviceCode)

                // The user has entered the code — now run the token chain.
                authState = .signingIn
                let token = try await authService.fullAuth(msToken)

                tokenInfo = token
                authState = .signedIn(username: token.username)

                await refresh()
                startPolling()
            } catch is CancellationError {
                // Whoever cancelled us (cancelSignIn, signOut, or a newer
                // sign-in attempt) owns the state — don't stomp it here.
            } catch {
                if !Task.isCancelled {
                    authState = .error(error.localizedDescription)
                }
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
        signInTask = nil
        authState = .signedOut
    }

    // MARK: - Sign Out

    func signOut() {
        stopPolling()
        signInTask?.cancel()
        signInTask = nil
        KeychainService.clearAll()
        tokenInfo = nil
        realms = []
        selectedRealmID = nil
        authState = .signedOut
    }

    // MARK: - Refresh

    func refresh() async {
        guard let token = tokenInfo else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            realms = try await RealmsService.getOnlinePlayers(token: token)
            // Recover from a transient error state once a refresh succeeds.
            if case .error = authState {
                authState = .signedIn(username: token.username)
            }
        } catch RealmsError.authExpired {
            // Token expired — try to refresh
            if let newToken = await authService.getValidToken() {
                tokenInfo = newToken
                do {
                    realms = try await RealmsService.getOnlinePlayers(token: newToken)
                } catch {
                    authState = .error(error.localizedDescription)
                }
            } else {
                authState = .signedOut
            }
        } catch {
            authState = .error(error.localizedDescription)
        }
    }

    func refreshInBackground() {
        Task { await refresh() }
    }

    // MARK: - Polling

    private func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, let self else { return }
                await self.refresh()
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
