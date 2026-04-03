"""macOS menu bar app showing Minecraft Realms online player count."""

import subprocess
import threading
import time

import rumps

from realmonline import auth
from realmonline.realms import RealmsClient, RealmsError

POLL_INTERVAL_SECONDS = 60


class RealmOnlineApp(rumps.App):
    def __init__(self):
        super().__init__(
            name="RealmOnline",
            title="\u26cf ?",  # ⛏ ? (pickaxe + unknown count)
            quit_button=None,
        )
        self._token_info = None
        self._realms_data = []
        self._selected_realm_id = None
        self._build_menu()

    def _build_menu(self):
        """Build the dropdown menu."""
        self.menu.clear()
        if self._token_info is None:
            self.menu = [
                rumps.MenuItem("Sign In with Microsoft", callback=self._on_sign_in),
                None,  # separator
                rumps.MenuItem("Quit", callback=self._on_quit),
            ]
        else:
            username = self._token_info.get("username", "Unknown")
            self.menu = [
                rumps.MenuItem(f"Signed in as {username}", callback=None),
                None,
                rumps.MenuItem("Realms:", callback=None),
            ]
            if self._realms_data:
                for realm in self._realms_data:
                    state = realm["state"]
                    count = realm["player_count"]
                    name = realm["name"]
                    if state == "CLOSED":
                        label = f"  {name} (closed)"
                    else:
                        label = f"  {name}: {count} online"
                    item = rumps.MenuItem(label, callback=self._make_realm_selector(realm["id"]))
                    if realm["id"] == self._selected_realm_id:
                        item.state = 1  # checkmark
                    self.menu.add(item)

                    # Show online player names as sub-items
                    if realm["players_online"]:
                        for player_name in realm["players_online"]:
                            player_item = rumps.MenuItem(f"    \u25b8 {player_name}")
                            self.menu.add(player_item)
            else:
                self.menu.add(rumps.MenuItem("  No realms found"))

            self.menu.add(None)  # separator
            self.menu.add(rumps.MenuItem("Refresh Now", callback=self._on_refresh))
            self.menu.add(rumps.MenuItem("Sign Out", callback=self._on_sign_out))
            self.menu.add(None)
            self.menu.add(rumps.MenuItem("Quit", callback=self._on_quit))

    def _make_realm_selector(self, realm_id):
        """Create a callback for selecting which realm to show in the menu bar."""
        def callback(sender):
            self._selected_realm_id = realm_id
            self._update_title()
            self._build_menu()
        return callback

    def _update_title(self):
        """Update the menu bar title with the selected realm's player count."""
        if not self._realms_data:
            self.title = "\u26cf ?"
            return

        # If no realm selected, pick the first open one
        if self._selected_realm_id is None:
            for realm in self._realms_data:
                if realm["state"] == "OPEN":
                    self._selected_realm_id = realm["id"]
                    break
            else:
                # No open realms, just pick the first one
                if self._realms_data:
                    self._selected_realm_id = self._realms_data[0]["id"]

        for realm in self._realms_data:
            if realm["id"] == self._selected_realm_id:
                if realm["state"] == "CLOSED":
                    self.title = "\u26cf off"
                else:
                    self.title = f"\u26cf {realm['player_count']}"
                return

        self.title = "\u26cf ?"

    # ── Callbacks ───────────────────────────────────────────────────────

    def _on_sign_in(self, _sender):
        """Start the Microsoft device code login flow."""
        self.title = "\u26cf ..."
        thread = threading.Thread(target=self._sign_in_thread, daemon=True)
        thread.start()

    def _sign_in_thread(self):
        try:
            def on_code(user_code, verification_uri):
                # Copy code to clipboard and show notification
                try:
                    subprocess.run(
                        ["pbcopy"],
                        input=user_code.encode(),
                        check=True,
                    )
                except Exception:
                    pass
                rumps.notification(
                    "RealmOnline - Sign In",
                    f"Code: {user_code} (copied to clipboard)",
                    f"Opening {verification_uri} in your browser...",
                )
                import webbrowser
                webbrowser.open(verification_uri)

            self._token_info = auth.login_interactive(on_code=on_code)
            rumps.notification(
                "RealmOnline",
                "Signed in successfully!",
                f"Welcome, {self._token_info['username']}",
            )
            self._refresh_realms()
            self._build_menu()
        except Exception as e:
            self.title = "\u26cf !"
            rumps.notification("RealmOnline - Error", "Sign in failed", str(e))

    def _on_sign_out(self, _sender):
        """Sign out and clear tokens."""
        auth.clear_tokens()
        self._token_info = None
        self._realms_data = []
        self._selected_realm_id = None
        self.title = "\u26cf ?"
        self._build_menu()
        rumps.notification("RealmOnline", "Signed out", "")

    def _on_refresh(self, _sender):
        """Manual refresh."""
        thread = threading.Thread(target=self._refresh_realms_and_rebuild, daemon=True)
        thread.start()

    def _on_quit(self, _sender):
        rumps.quit_application()

    # ── Data fetching ───────────────────────────────────────────────────

    def _refresh_realms(self):
        """Fetch realm data from the API."""
        if self._token_info is None:
            return
        try:
            client = RealmsClient(
                access_token=self._token_info["access_token"],
                username=self._token_info["username"],
                uuid=self._token_info["uuid"],
            )
            self._realms_data = client.get_online_players()
            self._update_title()
        except RealmsError:
            # Token expired, try refreshing
            self._token_info = auth.get_token()
            if self._token_info is None:
                self.title = "\u26cf !"
                rumps.notification(
                    "RealmOnline",
                    "Session expired",
                    "Please sign in again.",
                )
                self._build_menu()
            else:
                # Retry with new token
                try:
                    client = RealmsClient(
                        access_token=self._token_info["access_token"],
                        username=self._token_info["username"],
                        uuid=self._token_info["uuid"],
                    )
                    self._realms_data = client.get_online_players()
                    self._update_title()
                except Exception as e:
                    self.title = "\u26cf !"
                    rumps.notification("RealmOnline", "Error", str(e))
        except Exception as e:
            self.title = "\u26cf !"
            rumps.notification("RealmOnline", "Error fetching realms", str(e))

    def _refresh_realms_and_rebuild(self):
        self._refresh_realms()
        self._build_menu()

    # ── Timer ───────────────────────────────────────────────────────────

    @rumps.timer(POLL_INTERVAL_SECONDS)
    def _poll(self, _timer):
        """Periodically refresh realm data."""
        if self._token_info is None:
            # Try loading cached token on startup
            self._token_info = auth.get_token()
            if self._token_info:
                self._build_menu()

        if self._token_info:
            self._refresh_realms()
            self._build_menu()


def main():
    app = RealmOnlineApp()
    app.run()
