"""
Build a standalone macOS .app bundle using py2app.

Usage:
    python setup_app.py py2app
"""

from setuptools import setup

APP = ["realmonline/app.py"]
DATA_FILES = []
OPTIONS = {
    "argv_emulation": False,
    "iconfile": None,
    "plist": {
        "CFBundleName": "RealmOnline",
        "CFBundleDisplayName": "RealmOnline",
        "CFBundleIdentifier": "com.realmonline.menubar",
        "CFBundleVersion": "1.0.0",
        "CFBundleShortVersionString": "1.0.0",
        "LSUIElement": True,  # Hide from Dock (menu bar app only)
    },
    "packages": ["rumps", "requests", "keyring", "certifi"],
}

setup(
    app=APP,
    data_files=DATA_FILES,
    options={"py2app": OPTIONS},
    setup_requires=["py2app"],
)
