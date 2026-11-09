# Troubleshooting

[English](troubleshooting.md) · [Türkçe](tr/troubleshooting.md)

**The menu bar has an icon and the card does not.** The card starts toward the lower right of the screen. Pause does not hide it. **Hide card** does. A fully clear window was an older build; the current card is frosted glass on macOS 26 and later, and a dark HUD panel on macOS 15.

**The card says “No lyrics”.** LRCLIB has no timed lyrics for that title and artist. Untimed text is not spread across the song. Try the menu offset only after a timed match exists.

**Spotify never appears.** Confirm Spotify is playing, then allow Automation for Verseglass. If Spotify is only paused, the browser’s Now Playing track is used instead.

**YouTube stays on the title.** Give the helper a few seconds the first time; `/usr/bin/swift` may compile it. The browser has to be the system Now Playing app. A channel name in the artist field is stripped when the title already contains the performer.

**Two cards.** Quit from the menu, then open `dist/Verseglass.app` once. An older copy left running will keep its own window.

**Intel Mac.** `./build.sh` must finish the x86_64 compile. `lipo -info dist/Verseglass.app/Contents/MacOS/Verseglass` should list both `x86_64` and `arm64`.
