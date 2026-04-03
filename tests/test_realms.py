"""Tests for the Realms API client data processing logic."""

import json
from unittest.mock import MagicMock, patch

import pytest

from realmonline.realms import RealmsClient, RealmsError


@pytest.fixture
def client():
    return RealmsClient(
        access_token="fake-token",
        username="TestUser",
        uuid="abcd1234",
    )


# ── Header format ───────────────────────────────────────────────────────


def test_cookie_header_format(client):
    headers = client._headers
    cookie = headers["Cookie"]
    assert "sid=token:fake-token:abcd1234" in cookie
    assert "user=TestUser" in cookie
    assert "version=" in cookie
    # Proper semicolon-space separators
    parts = cookie.split("; ")
    assert len(parts) == 3


# ── get_worlds ──────────────────────────────────────────────────────────


@patch("realmonline.realms.requests.get")
def test_get_worlds_parses_servers(mock_get, client):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "servers": [
            {"id": 1, "name": "My Realm", "state": "OPEN"},
            {"id": 2, "name": "Other Realm", "state": "CLOSED"},
        ]
    }
    mock_get.return_value = mock_resp

    worlds = client.get_worlds()
    assert len(worlds) == 2
    assert worlds[0]["name"] == "My Realm"


@patch("realmonline.realms.requests.get")
def test_get_worlds_empty(mock_get, client):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"servers": []}
    mock_get.return_value = mock_resp

    assert client.get_worlds() == []


@patch("realmonline.realms.requests.get")
def test_get_worlds_401_raises_realms_error(mock_get, client):
    mock_resp = MagicMock()
    mock_resp.status_code = 401
    mock_get.return_value = mock_resp

    with pytest.raises(RealmsError, match="Authentication expired"):
        client.get_worlds()


# ── get_live_player_list ────────────────────────────────────────────────


@patch("realmonline.realms.requests.get")
def test_live_player_list(mock_get, client):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "lists": [
            {
                "serverId": 1,
                "playerList": [
                    {"playerId": "uuid-aaa"},
                    {"playerId": "uuid-bbb"},
                ],
            },
            {
                "serverId": 2,
                "playerList": [],
            },
        ]
    }
    mock_get.return_value = mock_resp

    result = client.get_live_player_list()
    assert result[1] == ["uuid-aaa", "uuid-bbb"]
    assert result[2] == []


@patch("realmonline.realms.requests.get")
def test_live_player_list_empty(mock_get, client):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"lists": []}
    mock_get.return_value = mock_resp

    assert client.get_live_player_list() == {}


# ── get_online_players (combined logic) ─────────────────────────────────


@patch("realmonline.realms.requests.get")
def test_get_online_players_combines_endpoints(mock_get, client):
    """Verifies that /worlds + /activities/liveplayerlist are merged correctly."""

    def side_effect(url, **kwargs):
        mock_resp = MagicMock()
        mock_resp.status_code = 200

        if "/activities/liveplayerlist" in url:
            mock_resp.json.return_value = {
                "lists": [
                    {
                        "serverId": 1,
                        "playerList": [
                            {"playerId": "uuid-alice"},
                            {"playerId": "uuid-bob"},
                        ],
                    }
                ]
            }
        else:
            # /worlds
            mock_resp.json.return_value = {
                "servers": [
                    {
                        "id": 1,
                        "name": "Survival Realm",
                        "owner": "TestUser",
                        "state": "OPEN",
                        "maxPlayers": 10,
                        "players": [
                            {"uuid": "uuid-alice", "name": "Alice", "online": False},
                            {"uuid": "uuid-bob", "name": "Bob", "online": False},
                            {"uuid": "uuid-charlie", "name": "Charlie", "online": False},
                        ],
                    }
                ]
            }
        return mock_resp

    mock_get.side_effect = side_effect

    results = client.get_online_players()
    assert len(results) == 1

    realm = results[0]
    assert realm["name"] == "Survival Realm"
    assert realm["player_count"] == 2
    assert realm["players_online"] == ["Alice", "Bob"]
    assert realm["max_players"] == 10
    assert realm["state"] == "OPEN"


@patch("realmonline.realms.requests.get")
def test_get_online_players_unknown_uuid_uses_short_id(mock_get, client):
    """If a player UUID isn't in /worlds, fall back to first 8 chars of UUID."""

    def side_effect(url, **kwargs):
        mock_resp = MagicMock()
        mock_resp.status_code = 200

        if "/activities/liveplayerlist" in url:
            mock_resp.json.return_value = {
                "lists": [
                    {
                        "serverId": 1,
                        "playerList": [{"playerId": "unknown-player-uuid-1234"}],
                    }
                ]
            }
        else:
            mock_resp.json.return_value = {
                "servers": [
                    {
                        "id": 1,
                        "name": "Test",
                        "owner": "Owner",
                        "state": "OPEN",
                        "maxPlayers": 10,
                        "players": [],
                    }
                ]
            }
        return mock_resp

    mock_get.side_effect = side_effect

    results = client.get_online_players()
    assert results[0]["players_online"] == ["unknown-"]


@patch("realmonline.realms.requests.get")
def test_get_online_players_closed_realm(mock_get, client):
    """Closed realms show 0 players (liveplayerlist won't list them)."""

    def side_effect(url, **kwargs):
        mock_resp = MagicMock()
        mock_resp.status_code = 200

        if "/activities/liveplayerlist" in url:
            mock_resp.json.return_value = {"lists": []}
        else:
            mock_resp.json.return_value = {
                "servers": [
                    {
                        "id": 1,
                        "name": "Closed Realm",
                        "owner": "Owner",
                        "state": "CLOSED",
                        "maxPlayers": 10,
                        "players": [],
                    }
                ]
            }
        return mock_resp

    mock_get.side_effect = side_effect

    results = client.get_online_players()
    assert results[0]["state"] == "CLOSED"
    assert results[0]["player_count"] == 0
    assert results[0]["players_online"] == []


@patch("realmonline.realms.requests.get")
def test_get_online_players_null_players_field(mock_get, client):
    """API may return players: null instead of an empty list."""

    def side_effect(url, **kwargs):
        mock_resp = MagicMock()
        mock_resp.status_code = 200

        if "/activities/liveplayerlist" in url:
            mock_resp.json.return_value = {"lists": None}
        else:
            mock_resp.json.return_value = {
                "servers": [
                    {
                        "id": 1,
                        "name": "Null Realm",
                        "owner": "Owner",
                        "state": "OPEN",
                        "maxPlayers": 10,
                        "players": None,
                    }
                ]
            }
        return mock_resp

    mock_get.side_effect = side_effect

    results = client.get_online_players()
    assert results[0]["player_count"] == 0
    assert results[0]["players_online"] == []
