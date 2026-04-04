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
    private var pollTimer: Timer?
    private let authService = AuthService.shared

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

    func onAppear() {
        Task { await checkCachedToken() }
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
        Task {
            do {
                let deviceCode = try await authService.requestDeviceCode()
                authState = .awaitingCode(
                    userCode: deviceCode.userCode,
                    verificationURI: deviceCode.verificationUri
                )

                // Copy code to clipboard
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(deviceCode.userCode, forType: .string)

                // Open browser
                if let url = URL(string: deviceCode.verificationUri) {
                    NSWorkspace.shared.open(url)
                }

                authState = .signingIn

                let msToken = try await authService.pollForMSToken(deviceCode)
                let token = try await authService.fullAuth(msToken)

                tokenInfo = token
                authState = .signedIn(username: token.username)

                await refresh()
                startPolling()
            } catch {
                authState = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        stopPolling()
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
        } catch is RealmsError {
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
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshInBackground()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
