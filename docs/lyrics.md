# Lyrics

[English](lyrics.md) · [Türkçe](tr/lyrics.md)

Timed lyrics are loaded from the public [LRCLIB](https://lrclib.net) API. There is no API key. The request sends a `Verseglass` user agent and the track title, artist, and duration.

The card uses LRC timestamps:

- The white line is the last stamp at or before the playhead.
- One earlier non-blank line is shown above it, dimmed.
- Up to three following non-blank lines are shown below it, dimmed.
- Before the first stamp, upcoming lines fill the card and none of them is marked current.

A per-track offset moves every stamp by 0.5 seconds. Use **Back 0.5 s** and **Forward 0.5 s** in the menu. The offset is stored for that track on this Mac.

Successful lookups and short-lived misses are cached under `~/Library/Application Support/Verseglass/lyrics`.
