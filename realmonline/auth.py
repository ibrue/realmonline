"""
Microsoft -> Xbox Live -> XSTS -> Minecraft authentication flow.

Uses the OAuth2 Device Code flow so the user can authenticate in their browser.
Tokens are cached in the macOS Keychain via the `keyring` library.
"""

import json
import os
import time
import webbrowser

import keyring
import requests

# Azure AD application client ID.
#
# You MUST register your own Azure AD app to use this tool:
#   1. Go to https://portal.azure.com -> "App registrations" -> "New registration"
#   2. Set "Supported account types" to "Personal Microsoft accounts only"
#   3. Under "Authentication", add a "Mobile and desktop applications" platform
#      with redirect URI: https://login.microsoftonline.com/common/oauth2/nativeclient
#   4. Under "API permissions", ensure XboxLive.signin is granted
#   5. Copy the "Application (client) ID" and set it below or via environment variable
#
# Set via: REALMONLINE_CLIENT_ID environment variable, or edit this default.
CLIENT_ID = os.environ.get("REALMONLINE_CLIENT_ID", "")

MICROSOFT_DEVICE_CODE_URL = (
    "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode"
)
MICROSOFT_TOKEN_URL = (
    "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"
)
XBOX_LIVE_AUTH_URL = "https://user.auth.xboxlive.com/user/authenticate"
XSTS_AUTH_URL = "https://xsts.auth.xboxlive.com/xsts/authorize"
MINECRAFT_AUTH_URL = (
    "https://api.minecraftservices.com/authentication/login_with_xbox"
)
MINECRAFT_PROFILE_URL = "https://api.minecraftservices.com/minecraft/profile"

KEYRING_SERVICE = "realmonline"
KEYRING_MS_REFRESH = "ms_refresh_token"
KEYRING_MC_TOKEN = "mc_token_data"


class AuthError(Exception):
    pass


def _save_token(key: str, data: str) -> None:
    keyring.set_password(KEYRING_SERVICE, key, data)


def _load_token(key: str) -> str | None:
    return keyring.get_password(KEYRING_SERVICE, key)


def _delete_token(key: str) -> None:
    try:
        keyring.delete_password(KEYRING_SERVICE, key)
    except keyring.errors.PasswordDeleteError:
        pass


def clear_tokens() -> None:
    """Remove all stored tokens (logout)."""
    _delete_token(KEYRING_MS_REFRESH)
    _delete_token(KEYRING_MC_TOKEN)


# ── Step 1: Microsoft OAuth2 Device Code Flow ──────────────────────────


def _require_client_id() -> str:
    if not CLIENT_ID:
        raise AuthError(
            "No Azure AD client ID configured. "
            "Set the REALMONLINE_CLIENT_ID environment variable. "
            "See README.md for setup instructions."
        )
    return CLIENT_ID


def request_device_code() -> dict:
    """Request a device code from Microsoft for user login."""
    client_id = _require_client_id()
    resp = requests.post(
        MICROSOFT_DEVICE_CODE_URL,
        data={
            "client_id": client_id,
            "scope": "XboxLive.signin offline_access",
        },
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()


def poll_for_ms_token(device_code_response: dict) -> dict:
    """Poll Microsoft until the user completes browser login."""
    interval = device_code_response.get("interval", 5)
    expires_in = device_code_response.get("expires_in", 900)
    device_code = device_code_response["device_code"]
    deadline = time.time() + expires_in

    while time.time() < deadline:
        time.sleep(interval)
        resp = requests.post(
            MICROSOFT_TOKEN_URL,
            data={
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                "client_id": _require_client_id(),
                "device_code": device_code,
            },
            timeout=15,
        )
        data = resp.json()
        if "access_token" in data:
            if "refresh_token" in data:
                _save_token(KEYRING_MS_REFRESH, data["refresh_token"])
            return data
        error = data.get("error", "")
        if error == "authorization_pending":
            continue
        if error == "slow_down":
            interval += 5
            continue
        raise AuthError(f"Microsoft auth failed: {data.get('error_description', error)}")

    raise AuthError("Device code expired. Please try again.")


def refresh_ms_token(refresh_token: str) -> dict:
    """Use a refresh token to get a new Microsoft access token."""
    resp = requests.post(
        MICROSOFT_TOKEN_URL,
        data={
            "client_id": _require_client_id(),
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
            "scope": "XboxLive.signin offline_access",
        },
        timeout=15,
    )
    resp.raise_for_status()
    data = resp.json()
    if "refresh_token" in data:
        _save_token(KEYRING_MS_REFRESH, data["refresh_token"])
    return data


# ── Step 2: Xbox Live Authentication ───────────────────────────────────


def authenticate_xbox_live(ms_access_token: str) -> tuple[str, str]:
    """Authenticate with Xbox Live. Returns (xbl_token, user_hash)."""
    resp = requests.post(
        XBOX_LIVE_AUTH_URL,
        json={
            "Properties": {
                "AuthMethod": "RPS",
                "SiteName": "user.auth.xboxlive.com",
                "RpsTicket": f"d={ms_access_token}",
            },
            "RelyingParty": "http://auth.xboxlive.com",
            "TokenType": "JWT",
        },
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        timeout=15,
    )
    resp.raise_for_status()
    data = resp.json()
    token = data["Token"]
    user_hash = data["DisplayClaims"]["xui"][0]["uhs"]
    return token, user_hash


# ── Step 3: XSTS Token ─────────────────────────────────────────────────


def authenticate_xsts(xbl_token: str) -> tuple[str, str]:
    """Get an XSTS token. Returns (xsts_token, user_hash)."""
    resp = requests.post(
        XSTS_AUTH_URL,
        json={
            "Properties": {
                "SandboxId": "RETAIL",
                "UserTokens": [xbl_token],
            },
            "RelyingParty": "rp://api.minecraftservices.com/",
            "TokenType": "JWT",
        },
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        timeout=15,
    )
    resp.raise_for_status()
    data = resp.json()
    token = data["Token"]
    user_hash = data["DisplayClaims"]["xui"][0]["uhs"]
    return token, user_hash


# ── Step 4: Minecraft Token ────────────────────────────────────────────


def authenticate_minecraft(xsts_token: str, user_hash: str) -> dict:
    """Exchange XSTS token for a Minecraft access token."""
    resp = requests.post(
        MINECRAFT_AUTH_URL,
        json={
            "identityToken": f"XBL3.0 x={user_hash};{xsts_token}",
            "ensureLegacyEnabled": True,
        },
        headers={"Content-Type": "application/json"},
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()


def get_minecraft_profile(mc_access_token: str) -> dict:
    """Get the Minecraft profile (username, UUID)."""
    resp = requests.get(
        MINECRAFT_PROFILE_URL,
        headers={"Authorization": f"Bearer {mc_access_token}"},
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()


# ── Full Auth Flow ──────────────────────────────────────────────────────


def _do_full_auth(ms_token_data: dict) -> dict:
    """Run Xbox Live -> XSTS -> Minecraft auth and cache the result."""
    ms_access_token = ms_token_data["access_token"]
    xbl_token, user_hash = authenticate_xbox_live(ms_access_token)
    xsts_token, user_hash = authenticate_xsts(xbl_token)
    mc_data = authenticate_minecraft(xsts_token, user_hash)

    mc_access_token = mc_data["access_token"]
    expires_in = mc_data.get("expires_in", 86400)

    profile = get_minecraft_profile(mc_access_token)

    token_info = {
        "access_token": mc_access_token,
        "username": profile["name"],
        "uuid": profile["id"],
        "expires_at": time.time() + expires_in,
    }
    _save_token(KEYRING_MC_TOKEN, json.dumps(token_info))
    return token_info


def login_interactive(on_code: callable = None) -> dict:
    """
    Full interactive device-code login flow.

    on_code(user_code, verification_uri) is called so the app can display
    the code to the user. Returns Minecraft token info dict.
    """
    device_resp = request_device_code()
    user_code = device_resp["user_code"]
    verification_uri = device_resp["verification_uri"]

    if on_code:
        on_code(user_code, verification_uri)
    else:
        print(f"Go to {verification_uri} and enter code: {user_code}")
        webbrowser.open(verification_uri)

    ms_token_data = poll_for_ms_token(device_resp)
    return _do_full_auth(ms_token_data)


def get_token() -> dict | None:
    """
    Get a valid Minecraft token, refreshing if needed.

    Returns token info dict or None if login is required.
    """
    # Try cached Minecraft token
    cached = _load_token(KEYRING_MC_TOKEN)
    if cached:
        token_info = json.loads(cached)
        if token_info.get("expires_at", 0) > time.time() + 300:
            return token_info

    # Try refreshing via Microsoft refresh token
    refresh_token = _load_token(KEYRING_MS_REFRESH)
    if refresh_token:
        try:
            ms_token_data = refresh_ms_token(refresh_token)
            return _do_full_auth(ms_token_data)
        except Exception:
            # Refresh failed, need fresh login
            pass

    return None
