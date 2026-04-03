import Foundation

// MARK: - Microsoft Device Code Flow

struct DeviceCodeResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct MSTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct MSTokenErrorResponse: Codable {
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - Xbox Live / XSTS

struct XboxAuthResponse: Codable {
    let token: String
    let displayClaims: DisplayClaims

    struct DisplayClaims: Codable {
        let xui: [XUI]
        struct XUI: Codable {
            let uhs: String
        }
    }

    enum CodingKeys: String, CodingKey {
        case token = "Token"
        case displayClaims = "DisplayClaims"
    }
}

// MARK: - Minecraft

struct MinecraftAuthResponse: Codable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

struct MinecraftProfile: Codable {
    let id: String
    let name: String
}

// MARK: - Persisted Token

struct MinecraftTokenInfo: Codable {
    let accessToken: String
    let username: String
    let uuid: String
    let expiresAt: Date
}

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case signedOut
    case awaitingCode(userCode: String, verificationURI: String)
    case signingIn
    case signedIn(username: String)
    case error(String)
}
