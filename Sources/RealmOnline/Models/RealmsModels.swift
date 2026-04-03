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
