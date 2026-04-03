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

### 1. Register an Azure AD Application

This app uses Microsoft's OAuth2 device code flow, which requires your own Azure AD app:

1. Go to [Azure Portal → App registrations](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade) → **New registration**
2. Name it anything (e.g. "RealmOnline")
3. Set **Supported account types** to **Personal Microsoft accounts only**
4. Under **Authentication** → **Add a platform** → **Mobile and desktop applications**
5. Add redirect URI: `https://login.microsoftonline.com/common/oauth2/nativeclient`
6. Under **API permissions**, ensure `XboxLive.signin` is granted
7. Copy the **Application (client) ID** (a UUID like `a1b2c3d4-...`)

### 2. Install

```bash
# Clone the repo
git clone https://github.com/ibrue/realmonline.git
cd realmonline

# Install
pip install -e .

# Set your Azure AD client ID
export REALMONLINE_CLIENT_ID="your-client-id-here"

# Run
realmonline
```

To make the env var permanent, add the `export` line to your `~/.zshrc` or `~/.bash_profile`.

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
- An Azure AD application (see [Setup](#setup) above)
