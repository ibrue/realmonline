# RealmOnline ⛏

A macOS menu bar app that shows how many players are online in your Minecraft Java Realms.

![menu bar preview](https://img.shields.io/badge/menu%20bar-%E2%9B%8F%203-green)

## Features

- **Live player count** in your menu bar (e.g. `⛏ 3`)
- **Click to see details**: which realm, who's online
- **Multiple realms** supported — pick which one to display
- **Auto-refresh** every 60 seconds
- **Secure auth** via Microsoft device code flow (tokens stored in macOS Keychain)

## Setup

```bash
# Clone the repo
git clone https://github.com/ibrue/realmonline.git
cd realmonline

# Create a virtual environment (required on modern macOS)
python3 -m venv .venv
source .venv/bin/activate

# Install
pip install -e .

# Test auth from terminal first
python3 -m realmonline --test-auth

# Run the menu bar app
python3 -m realmonline
```

A default Azure AD client ID is included. To use your own, set:
```bash
export REALMONLINE_CLIENT_ID="your-client-id-here"
```

### Build Standalone .app

```bash
pip install py2app
python setup_app.py py2app

# The app will be in dist/RealmOnline.app
# Drag it to your Applications folder
```

## Usage

1. **Launch** the app — you'll see `⛏ ?` in your menu bar
2. **Click** the icon and select **Sign In with Microsoft**
3. A browser window opens — sign in with your Microsoft/Minecraft account
4. The login code is automatically copied to your clipboard
5. Once signed in, the app shows the online player count: `⛏ 3`

### Menu Bar

| Display | Meaning |
|---------|---------|
| `⛏ 3` | 3 players online |
| `⛏ 0` | No players online |
| `⛏ off` | Realm is closed |
| `⛏ ?` | Not signed in |
| `⛏ !` | Error (check notifications) |

### Dropdown Menu

Click the menu bar icon to see:
- Your signed-in username
- All your realms with player counts
- Names of online players
- Click a realm to pin it to the menu bar display

## How It Works

1. **Microsoft OAuth2** device code flow for authentication
2. **Xbox Live** → **XSTS** → **Minecraft** token exchange
3. Queries the **Minecraft Realms API** (`pc.realms.minecraft.net`)
4. Tokens cached securely in **macOS Keychain** via `keyring`

## Requirements

- macOS
- Python 3.11+
- A Minecraft Java Edition account with Realms access
- A Microsoft account linked to Minecraft
