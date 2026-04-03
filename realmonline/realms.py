"""Minecraft Java Realms API client."""

import requests

REALMS_BASE_URL = "https://pc.realms.minecraft.net"
MC_VERSION = "1.21.4"


class RealmsError(Exception):
    pass


class RealmsClient:
    """Client for the Minecraft Java Edition Realms API."""

    def __init__(self, access_token: str, username: str, uuid: str):
        self.access_token = access_token
        self.username = username
        self.uuid = uuid

    @property
    def _headers(self) -> dict:
        return {
            "Cookie": (
                f"sid=token:{self.access_token}:{self.uuid};"
                f"user={self.username};"
                f"version={MC_VERSION}"
            ),
            "User-Agent": "Java/21.0.3",
            "Content-Type": "application/json",
        }

    def get_worlds(self) -> list[dict]:
        """Get all Realms the user has access to."""
        resp = requests.get(
            f"{REALMS_BASE_URL}/worlds",
            headers=self._headers,
            timeout=15,
        )
        if resp.status_code == 401:
            raise RealmsError("Authentication expired")
        resp.raise_for_status()
        data = resp.json()
        return data.get("servers", [])

    def get_world_details(self, world_id: int) -> dict:
        """Get detailed info for a specific realm, including online players."""
        resp = requests.get(
            f"{REALMS_BASE_URL}/worlds/{world_id}",
            headers=self._headers,
            timeout=15,
        )
        if resp.status_code == 401:
            raise RealmsError("Authentication expired")
        resp.raise_for_status()
        return resp.json()

    def get_live_player_list(self) -> dict[int, list[str]]:
        """
        Get currently online players using the dedicated liveplayerlist endpoint.

        Returns a dict mapping realm ID -> list of online player UUIDs.
        This endpoint is more reliable than the player data in /worlds.
        """
        resp = requests.get(
            f"{REALMS_BASE_URL}/activities/liveplayerlist",
            headers=self._headers,
            timeout=15,
        )
        if resp.status_code == 401:
            raise RealmsError("Authentication expired")
        resp.raise_for_status()
        data = resp.json()

        result: dict[int, list[str]] = {}
        for server in data.get("lists", []):
            realm_id = server.get("serverId")
            players = server.get("playerList", [])
            if realm_id is not None:
                result[realm_id] = [p.get("playerId", "") for p in players]
        return result

    def get_online_players(self) -> list[dict]:
        """
        Get all realms with their online player info.

        Combines /worlds (for realm metadata and invited player names) with
        /activities/liveplayerlist (for accurate online status).

        Returns a list of dicts with:
          - name: realm name
          - id: realm world id
          - owner: realm owner
          - players_online: list of online player names
          - player_count: number of online players
          - max_players: max player slots (10 for Realms)
          - state: realm state (OPEN, CLOSED, etc.)
        """
        worlds = self.get_worlds()
        live = self.get_live_player_list()

        # Build a UUID -> name lookup from the player lists in /worlds
        uuid_to_name: dict[str, str] = {}
        for world in worlds:
            for p in world.get("players", []):
                uid = p.get("uuid", "")
                name = p.get("name")
                if uid and name:
                    uuid_to_name[uid] = name

        results = []
        for world in worlds:
            world_id = world.get("id")
            online_uuids = live.get(world_id, [])
            online_names = [
                uuid_to_name.get(uid, uid[:8]) for uid in online_uuids
            ]
            results.append({
                "name": world.get("name", "Unknown"),
                "id": world_id,
                "owner": world.get("owner", "Unknown"),
                "players_online": online_names,
                "player_count": len(online_uuids),
                "max_players": world.get("maxPlayers", 10),
                "state": world.get("state", "UNKNOWN"),
            })
        return results
