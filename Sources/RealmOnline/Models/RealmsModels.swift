import Foundation

// MARK: - GET /worlds

struct WorldsResponse: Codable {
    let servers: [RealmServer]?
}

struct RealmServer: Codable {
    let id: Int
    let name: String?
    let owner: String?
    let state: String?
    let maxPlayers: Int?
    let players: [RealmPlayer]?
}

struct RealmPlayer: Codable {
    let uuid: String?
    let name: String?
    let online: Bool?
}

// MARK: - GET /activities/liveplayerlist

struct LivePlayerListResponse: Codable {
    let lists: [LivePlayerServer]?
}

struct LivePlayerServer: Codable {
    let serverId: Int
    let playerList: [LivePlayer]?

    enum CodingKeys: String, CodingKey {
        case serverId, playerList
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serverId = try container.decode(Int.self, forKey: .serverId)

        // The API has returned playerList both as a JSON array and as a
        // JSON-encoded string containing that array; accept either.
        if let list = try? container.decodeIfPresent([LivePlayer].self, forKey: .playerList) {
            playerList = list
        } else if let raw = try? container.decodeIfPresent(String.self, forKey: .playerList),
                  let data = raw.data(using: .utf8) {
            playerList = try? JSONDecoder().decode([LivePlayer].self, from: data)
        } else {
            playerList = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serverId, forKey: .serverId)
        try container.encodeIfPresent(playerList, forKey: .playerList)
    }
}

struct LivePlayer: Codable {
    let playerId: String
}

// MARK: - App-level Model

enum RealmState {
    case open, closed, unknown

    init(from string: String?) {
        switch string?.uppercased() {
        case "OPEN": self = .open
        case "CLOSED": self = .closed
        default: self = .unknown
        }
    }
}

struct RealmInfo: Identifiable {
    let id: Int
    let name: String
    let owner: String
    let state: RealmState
    let maxPlayers: Int
    let onlinePlayers: [String]
    var playerCount: Int { onlinePlayers.count }
}
