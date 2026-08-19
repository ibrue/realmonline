import XCTest
@testable import RealmOnline

final class ModelTests: XCTestCase {

    // MARK: - Realms /worlds

    func testWorldsResponseDecodesFullPayload() throws {
        let json = """
        {
            "servers": [
                {
                    "id": 123,
                    "name": "My Realm",
                    "owner": "Steve",
                    "state": "OPEN",
                    "maxPlayers": 10,
                    "players": [
                        {"uuid": "abc123", "name": "Alex", "online": true}
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WorldsResponse.self, from: json)
        let server = try XCTUnwrap(decoded.servers?.first)
        XCTAssertEqual(server.id, 123)
        XCTAssertEqual(server.name, "My Realm")
        XCTAssertEqual(server.state, "OPEN")
        XCTAssertEqual(server.players?.first?.name, "Alex")
    }

    func testWorldsResponseToleratesNullFields() throws {
        let json = """
        {"servers": [{"id": 1, "name": null, "owner": null, "state": null, "maxPlayers": null, "players": null}]}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WorldsResponse.self, from: json)
        let server = try XCTUnwrap(decoded.servers?.first)
        XCTAssertEqual(server.id, 1)
        XCTAssertNil(server.name)
        XCTAssertNil(server.players)
    }

    func testWorldsResponseToleratesMissingServers() throws {
        let decoded = try JSONDecoder().decode(WorldsResponse.self, from: "{}".data(using: .utf8)!)
        XCTAssertNil(decoded.servers)
    }

    // MARK: - Realms /activities/liveplayerlist

    func testLivePlayerListDecodesArrayForm() throws {
        let json = """
        {"lists": [{"serverId": 42, "playerList": [{"playerId": "uuid-1"}, {"playerId": "uuid-2"}]}]}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(LivePlayerListResponse.self, from: json)
        let server = try XCTUnwrap(decoded.lists?.first)
        XCTAssertEqual(server.serverId, 42)
        XCTAssertEqual(server.playerList?.map(\.playerId), ["uuid-1", "uuid-2"])
    }

    func testLivePlayerListDecodesStringEncodedForm() throws {
        let json = """
        {"lists": [{"serverId": 42, "playerList": "[{\\"playerId\\": \\"uuid-1\\"}]"}]}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(LivePlayerListResponse.self, from: json)
        let server = try XCTUnwrap(decoded.lists?.first)
        XCTAssertEqual(server.playerList?.map(\.playerId), ["uuid-1"])
    }

    func testLivePlayerListToleratesMissingPlayerList() throws {
        let json = """
        {"lists": [{"serverId": 42}]}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(LivePlayerListResponse.self, from: json)
        let server = try XCTUnwrap(decoded.lists?.first)
        XCTAssertEqual(server.serverId, 42)
        XCTAssertNil(server.playerList)
    }

    // MARK: - RealmState

    func testRealmStateMapping() {
        XCTAssertEqual(RealmState(from: "OPEN"), .open)
        XCTAssertEqual(RealmState(from: "open"), .open)
        XCTAssertEqual(RealmState(from: "CLOSED"), .closed)
        XCTAssertEqual(RealmState(from: "UNINITIALIZED"), .unknown)
        XCTAssertEqual(RealmState(from: nil), .unknown)
    }

    // MARK: - Microsoft auth models

    func testDeviceCodeResponseDecodes() throws {
        let json = """
        {
            "device_code": "DEV123",
            "user_code": "ABCD1234",
            "verification_uri": "https://www.microsoft.com/link",
            "expires_in": 900,
            "interval": 5
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(DeviceCodeResponse.self, from: json)
        XCTAssertEqual(decoded.userCode, "ABCD1234")
        XCTAssertEqual(decoded.deviceCode, "DEV123")
        XCTAssertEqual(decoded.interval, 5)
    }

    func testMSTokenResponseDecodesWithoutOptionalFields() throws {
        let json = """
        {"access_token": "tok"}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MSTokenResponse.self, from: json)
        XCTAssertEqual(decoded.accessToken, "tok")
        XCTAssertNil(decoded.refreshToken)
    }

    func testMSTokenErrorRoundTrip() throws {
        let json = """
        {"error": "authorization_pending", "error_description": "waiting"}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MSTokenErrorResponse.self, from: json)
        XCTAssertEqual(decoded.error, "authorization_pending")
        XCTAssertEqual(decoded.errorDescription, "waiting")
    }

    func testXboxAuthResponseDecodes() throws {
        let json = """
        {"Token": "xbl-token", "DisplayClaims": {"xui": [{"uhs": "hash123"}]}}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(XboxAuthResponse.self, from: json)
        XCTAssertEqual(decoded.token, "xbl-token")
        XCTAssertEqual(decoded.displayClaims.xui.first?.uhs, "hash123")
    }

    func testMinecraftTokenInfoRoundTrip() throws {
        let original = MinecraftTokenInfo(
            accessToken: "mc-token",
            username: "Steve",
            uuid: "deadbeef",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MinecraftTokenInfo.self, from: data)
        XCTAssertEqual(decoded.accessToken, original.accessToken)
        XCTAssertEqual(decoded.username, original.username)
        XCTAssertEqual(decoded.expiresAt, original.expiresAt)
    }

    // MARK: - RealmInfo

    func testRealmInfoPlayerCount() {
        let realm = RealmInfo(
            id: 1, name: "R", owner: "O", state: .open,
            maxPlayers: 10, onlinePlayers: ["a", "b", "c"]
        )
        XCTAssertEqual(realm.playerCount, 3)
    }
}
