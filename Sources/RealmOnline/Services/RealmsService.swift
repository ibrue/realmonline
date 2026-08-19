import Foundation

enum RealmsError: LocalizedError {
    case authExpired
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .authExpired: return "Authentication expired"
        case .requestFailed(let msg): return msg
        }
    }
}

enum RealmsService {
    private static let baseURL = "https://pc.realms.minecraft.net"
    private static let mcVersion = "1.21.8"

    private static func makeRequest(path: String, token: MinecraftTokenInfo) -> URLRequest {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.setValue(
            "sid=token:\(token.accessToken):\(token.uuid); user=\(token.username); version=\(mcVersion)",
            forHTTPHeaderField: "Cookie"
        )
        request.setValue("Java/21.0.3", forHTTPHeaderField: "User-Agent")
        return request
    }

    private static func fetch(path: String, token: MinecraftTokenInfo) async throws -> Data {
        let request = makeRequest(path: path, token: token)

        // The Realms API sometimes answers 503 "Retry again later" right
        // after signing in; give it one short retry before surfacing it.
        for attempt in 0..<2 {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            switch status {
            case 200:
                return data
            case 401, 403:
                throw RealmsError.authExpired
            case 503 where attempt == 0:
                try await Task.sleep(nanoseconds: 2_000_000_000)
            default:
                let body = String(data: data, encoding: .utf8)?.prefix(120) ?? ""
                throw RealmsError.requestFailed("Realms API error (HTTP \(status)) \(body)")
            }
        }
        throw RealmsError.requestFailed("Realms API is busy. Try again in a minute.")
    }

    static func getWorlds(token: MinecraftTokenInfo) async throws -> [RealmServer] {
        let data = try await fetch(path: "/worlds", token: token)
        let decoded = try JSONDecoder().decode(WorldsResponse.self, from: data)
        return decoded.servers ?? []
    }

    static func getLivePlayerList(token: MinecraftTokenInfo) async throws -> [Int: [String]] {
        let data = try await fetch(path: "/activities/liveplayerlist", token: token)
        let decoded = try JSONDecoder().decode(LivePlayerListResponse.self, from: data)
        var result: [Int: [String]] = [:]
        for server in decoded.lists ?? [] {
            result[server.serverId] = (server.playerList ?? []).map(\.playerId)
        }
        return result
    }

    static func getOnlinePlayers(token: MinecraftTokenInfo) async throws -> [RealmInfo] {
        async let worldsTask = getWorlds(token: token)
        async let liveTask = getLivePlayerList(token: token)

        let worlds = try await worldsTask
        let live = try await liveTask

        // Build UUID → name lookup from /worlds player lists
        var uuidToName: [String: String] = [:]
        for world in worlds {
            for player in world.players ?? [] {
                if let uuid = player.uuid, let name = player.name {
                    uuidToName[uuid] = name
                }
            }
        }

        return worlds.map { world in
            let onlineUUIDs = live[world.id] ?? []
            let onlineNames = onlineUUIDs.map { uuid in
                uuidToName[uuid] ?? String(uuid.prefix(8))
            }
            return RealmInfo(
                id: world.id,
                name: world.name ?? "Unknown",
                owner: world.owner ?? "Unknown",
                state: RealmState(from: world.state),
                maxPlayers: world.maxPlayers ?? 10,
                onlinePlayers: onlineNames
            )
        }
    }
}
