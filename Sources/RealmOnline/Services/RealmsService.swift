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
    private static let mcVersion = "1.21.4"

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

    static func getWorlds(token: MinecraftTokenInfo) async throws -> [RealmServer] {
        let request = makeRequest(path: "/worlds", token: token)
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw RealmsError.authExpired
        }

        let decoded = try JSONDecoder().decode(WorldsResponse.self, from: data)
        return decoded.servers ?? []
    }

    static func getLivePlayerList(token: MinecraftTokenInfo) async throws -> [Int: [String]] {
        let request = makeRequest(path: "/activities/liveplayerlist", token: token)
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw RealmsError.authExpired
        }

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
