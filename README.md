# RealmOnline

A native macOS menu bar app that shows how many players are online in your Minecraft Java Realms.

## Install

### Download (easiest)

1. Go to [Releases](https://github.com/ibrue/realmonline/releases)
2. Download `RealmOnline.zip`
3. Unzip and drag `RealmOnline.app` to your Applications folder
4. Double-click to launch

### Build from source

```bash
git clone https://github.com/ibrue/realmonline.git
cd realmonline
./scripts/bundle-app.sh
open dist/RealmOnline.app
```

Requires Xcode Command Line Tools (`xcode-select --install`).

## Usage

1. Launch the app — `⛏ ?` appears in your menu bar
2. Click it and select **Sign in with Microsoft**
3. A browser opens — sign in with your Minecraft account (code is auto-copied)
4. Once signed in, the menu bar shows: `⛏ 3`

Click the icon to see all your realms, who's online, and switch which realm is displayed.

| Menu bar | Meaning |
|----------|---------|
| `⛏ 3` | 3 players online |
| `⛏ 0` | No players online |
| `⛏ off` | Realm is closed |
| `⛏ ?` | Not signed in |

Auto-refreshes every 60 seconds. Tokens are stored securely in your macOS Keychain.

## Requirements

- macOS 14 Sonoma or later
- A Microsoft account linked to Minecraft Java Edition with Realms access

## How It Works

1. Microsoft OAuth2 device code flow for authentication
2. Xbox Live → XSTS → Minecraft token exchange
3. Queries the Minecraft Realms API for online players
4. Built with SwiftUI and MenuBarExtra
