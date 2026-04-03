"""Tests for the auth module token caching and validation logic."""

import json
import time
from unittest.mock import MagicMock, patch

import pytest

from realmonline.auth import AuthError


# ── Client ID validation ────────────────────────────────────────────────


@patch("realmonline.auth.CLIENT_ID", "")
def test_require_client_id_raises_when_empty():
    from realmonline.auth import _require_client_id

    with pytest.raises(AuthError, match="No Azure AD client ID configured"):
        _require_client_id()


@patch("realmonline.auth.CLIENT_ID", "test-client-id")
def test_require_client_id_returns_id():
    from realmonline.auth import _require_client_id

    assert _require_client_id() == "test-client-id"


# ── Token caching ───────────────────────────────────────────────────────


@patch("realmonline.auth._load_token")
def test_get_token_returns_cached_when_valid(mock_load):
    from realmonline.auth import get_token

    token_info = {
        "access_token": "mc-token",
        "username": "TestUser",
        "uuid": "abcd1234",
        "expires_at": time.time() + 3600,  # 1 hour from now
    }
    mock_load.return_value = json.dumps(token_info)

    result = get_token()
    assert result["access_token"] == "mc-token"
    assert result["username"] == "TestUser"


@patch("realmonline.auth._load_token")
def test_get_token_returns_none_when_expired_and_no_refresh(mock_load):
    from realmonline.auth import get_token

    def side_effect(key):
        if key == "mc_token_data":
            return json.dumps({
                "access_token": "old-token",
                "expires_at": time.time() - 100,  # expired
            })
        return None  # no refresh token

    mock_load.side_effect = side_effect

    result = get_token()
    assert result is None


@patch("realmonline.auth._load_token")
def test_get_token_returns_none_when_no_tokens(mock_load):
    from realmonline.auth import get_token

    mock_load.return_value = None

    result = get_token()
    assert result is None


# ── Token clearing ──────────────────────────────────────────────────────


@patch("realmonline.auth._delete_token")
def test_clear_tokens(mock_delete):
    from realmonline.auth import clear_tokens

    clear_tokens()
    assert mock_delete.call_count == 2
    mock_delete.assert_any_call("ms_refresh_token")
    mock_delete.assert_any_call("mc_token_data")
