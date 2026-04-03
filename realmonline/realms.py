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

    def get_online_players(self) -> list[dict]:
        """
        Get all realms with their online player info.

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
        results = []
        for world in worlds:
            players = world.get("players", [])
            online = [p for p in players if p.get("online", False)]
            results.append({
                "name": world.get("name", "Unknown"),
                "id": world.get("id"),
                "owner": world.get("owner", "Unknown"),
                "players_online": [p.get("name", "???") for p in online],
                "player_count": len(online),
                "max_players": world.get("maxPlayers", 10),
                "state": world.get("state", "UNKNOWN"),
            })
        return results
