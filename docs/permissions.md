# Permissions

[English](permissions.md) · [Türkçe](tr/permissions.md)

Verseglass does not ask for Accessibility, screen recording, or full-disk access.

**Spotify.** The first time Spotify is playing, macOS asks for Automation permission so the app can read the track name and playback position. You can change this later in System Settings → Privacy & Security → Automation.

**YouTube and YouTube Music.** The browser does not need an Automation prompt. Playback is read through a small helper run by the Apple-signed `/usr/bin/swift`, which is what macOS 15.4 and later allow for Now Playing. The helper is the script `now_playing_helper.swift` inside the app.

If a player stays empty, see [Troubleshooting](troubleshooting.md).
