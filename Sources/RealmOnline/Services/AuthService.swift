import Foundation

enum AuthError: LocalizedError {
    case noClientID
    case deviceCodeExpired
    case authFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noClientID: return "No Azure AD client ID configured"
        case .deviceCodeExpired: return "Device code expired. Please try again."
        case .authFailed(let msg): return msg
        case .invalidResponse: return "Invalid response from server"
        }
    }
}

actor AuthService {
    static let shared = AuthService()

    private let clientID = "c36a9fb6-4f2a-41ff-90bd-ae7cc92031eb"
    private let session = URLSession.shared

    private static func statusCode(_ response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    // MARK: - Step 1a: Request Device Code

    func requestDeviceCode() async throws -> DeviceCodeResponse {
        let url = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "client_id=\(clientID)&scope=XboxLive.signin%20offline_access".data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard Self.statusCode(response) == 200 else {
            let err = try? JSONDecoder().decode(MSTokenErrorResponse.self, from: data)
            throw AuthError.authFailed(err?.errorDescription ?? "Could not start Microsoft sign-in (HTTP \(Self.statusCode(response)))")
        }
        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    // MARK: - Step 1b: Poll for MS Token

    func pollForMSToken(_ deviceCode: DeviceCodeResponse) async throws -> MSTokenResponse {
        let url = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!
        var interval = deviceCode.interval
        let deadline = Date().addingTimeInterval(TimeInterval(deviceCode.expiresIn))

        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let body = "grant_type=urn:ietf:params:oauth:grant-type:device_code&client_id=\(clientID)&device_code=\(deviceCode.deviceCode)"
            request.httpBody = body.data(using: .utf8)

            let (data, _) = try await session.data(for: request)

            if let token = try? JSONDecoder().decode(MSTokenResponse.self, from: data) {
                if let refresh = token.refreshToken {
                    KeychainService.save(key: "ms_refresh_token", data: refresh.data(using: .utf8) ?? Data())
                }
                return token
            }

            if let error = try? JSONDecoder().decode(MSTokenErrorResponse.self, from: data) {
                switch error.error {
                case "authorization_pending": continue
                case "slow_down": interval += 5; continue
                case "expired_token": throw AuthError.deviceCodeExpired
                default:
                    throw AuthError.authFailed(error.errorDescription ?? error.error ?? "Unknown error")
                }
            }
        }
        throw AuthError.deviceCodeExpired
    }

    // MARK: - Step 1b (refresh path)

    func refreshMSToken(_ refreshToken: String) async throws -> MSTokenResponse {
        let url = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=\(clientID)&grant_type=refresh_token&refresh_token=\(refreshToken)&scope=XboxLive.signin%20offline_access"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await session.data(for: request)
        let token = try JSONDecoder().decode(MSTokenResponse.self, from: data)
        if let refresh = token.refreshToken {
            KeychainService.save(key: "ms_refresh_token", data: refresh.data(using: .utf8) ?? Data())
        }
        return token
    }

    // MARK: - Step 2: Xbox Live

    func authenticateXboxLive(_ msAccessToken: String) async throws -> (token: String, userHash: String) {
        let url = URL(string: "https://user.auth.xboxlive.com/user/authenticate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "Properties": [
                "AuthMethod": "RPS",
                "SiteName": "user.auth.xboxlive.com",
                "RpsTicket": "d=\(msAccessToken)",
            ],
            "RelyingParty": "http://auth.xboxlive.com",
            "TokenType": "JWT",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard Self.statusCode(response) == 200 else {
            throw AuthError.authFailed("Xbox Live sign-in failed (HTTP \(Self.statusCode(response)))")
        }
        let resp = try JSONDecoder().decode(XboxAuthResponse.self, from: data)
        guard let uhs = resp.displayClaims.xui.first?.uhs else { throw AuthError.invalidResponse }
        return (resp.token, uhs)
    }

    // MARK: - Step 3: XSTS

    func authenticateXSTS(_ xblToken: String) async throws -> (token: String, userHash: String) {
        let url = URL(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "Properties": [
                "SandboxId": "RETAIL",
                "UserTokens": [xblToken],
            ],
            "RelyingParty": "rp://api.minecraftservices.com/",
            "TokenType": "JWT",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard Self.statusCode(response) == 200 else {
            throw AuthError.authFailed(Self.xstsErrorMessage(data: data, status: Self.statusCode(response)))
        }
        let resp = try JSONDecoder().decode(XboxAuthResponse.self, from: data)
        guard let uhs = resp.displayClaims.xui.first?.uhs else { throw AuthError.invalidResponse }
        return (resp.token, uhs)
    }

    private static func xstsErrorMessage(data: Data, status: Int) -> String {
        struct XSTSError: Codable { let XErr: UInt64? }
        let xerr = (try? JSONDecoder().decode(XSTSError.self, from: data))?.XErr ?? 0
        switch xerr {
        case 2_148_916_233:
            return "This Microsoft account has no Xbox profile. Sign in at xbox.com once to create one, then try again."
        case 2_148_916_235:
            return "Xbox Live is not available in your account's region."
        case 2_148_916_236, 2_148_916_237:
            return "This account needs adult verification on xbox.com before it can sign in."
        case 2_148_916_238:
            return "This is a child account. It must be added to a family by an adult before it can sign in."
        default:
            return "Xbox authorization failed (HTTP \(status))"
        }
    }

    // MARK: - Step 4: Minecraft Auth

    func authenticateMinecraft(xstsToken: String, userHash: String) async throws -> MinecraftAuthResponse {
        let url = URL(string: "https://api.minecraftservices.com/authentication/login_with_xbox")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "identityToken": "XBL3.0 x=\(userHash);\(xstsToken)",
            "ensureLegacyEnabled": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let status = Self.statusCode(response)
        guard status == 200 else {
            if status == 403 {
                throw AuthError.authFailed("Minecraft rejected the sign-in (HTTP 403). The app's client ID may not be approved for the Minecraft API.")
            }
            throw AuthError.authFailed("Minecraft sign-in failed (HTTP \(status))")
        }
        return try JSONDecoder().decode(MinecraftAuthResponse.self, from: data)
    }

    // MARK: - Step 5: Minecraft Profile

    func getMinecraftProfile(_ accessToken: String) async throws -> MinecraftProfile {
        let url = URL(string: "https://api.minecraftservices.com/minecraft/profile")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        let status = Self.statusCode(response)
        guard status == 200 else {
            if status == 404 {
                throw AuthError.authFailed("This Microsoft account doesn't own Minecraft Java Edition.")
            }
            throw AuthError.authFailed("Could not load Minecraft profile (HTTP \(status))")
        }
        return try JSONDecoder().decode(MinecraftProfile.self, from: data)
    }

    // MARK: - Full Auth Chain

    func fullAuth(_ msToken: MSTokenResponse) async throws -> MinecraftTokenInfo {
        let (xblToken, _) = try await authenticateXboxLive(msToken.accessToken)
        let (xstsToken, xstsHash) = try await authenticateXSTS(xblToken)
        let mcAuth = try await authenticateMinecraft(xstsToken: xstsToken, userHash: xstsHash)
        let profile = try await getMinecraftProfile(mcAuth.accessToken)

        let tokenInfo = MinecraftTokenInfo(
            accessToken: mcAuth.accessToken,
            username: profile.name,
            uuid: profile.id,
            expiresAt: Date().addingTimeInterval(TimeInterval(mcAuth.expiresIn))
        )
        KeychainService.save(key: "mc_token_data", value: tokenInfo)
        return tokenInfo
    }

    // MARK: - Get Valid Token (check cache, try refresh)

    func getValidToken() async -> MinecraftTokenInfo? {
        // Check cached MC token
        if let cached: MinecraftTokenInfo = KeychainService.load(key: "mc_token_data", as: MinecraftTokenInfo.self) {
            if cached.expiresAt > Date().addingTimeInterval(300) {
                return cached
            }
        }

        // Try MS refresh token
        guard let refreshData = KeychainService.load(key: "ms_refresh_token"),
              let refreshToken = String(data: refreshData, encoding: .utf8) else {
            return nil
        }

        do {
            let msToken = try await refreshMSToken(refreshToken)
            return try await fullAuth(msToken)
        } catch {
            return nil
        }
    }
}
