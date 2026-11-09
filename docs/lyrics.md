# Lyrics

[English](lyrics.md) · [Türkçe](tr/lyrics.md)

Timed lyrics are loaded from the public [LRCLIB](https://lrclib.net) API. There is no API key. The request sends a `Verseglass` user agent and the track title, artist, and duration.

The card uses LRC timestamps:

- The white line is the last stamp at or before the playhead. Letters fill across that line; word stamps such as `<00:12.50>` advance word by word.
- The menu chooses how many neighbors show: this line, one line on either side, or one line above and three below.
- Before the first stamp, upcoming lines fill the card and none of them is marked current.
- **Choose lyrics** lists other timed matches. **Paste lyrics…** stores an LRC for that track on this Mac. **Use automatic match** clears that choice.

A per-track offset moves every stamp by 0.5 seconds. Use **Back 0.5 s** and **Forward 0.5 s** in the menu. The offset is stored for that track on this Mac.

Successful lookups and short-lived misses are cached under `~/Library/Application Support/Verseglass/lyrics`.
