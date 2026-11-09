# Install

[English](install.md) · [Türkçe](tr/install.md)

You need macOS 15 or later and a Swift toolchain (Xcode 26 or the matching command-line tools). The app runs on both Apple Silicon and Intel. Building it does not need a paid Apple Developer account.

```bash
git clone https://github.com/emre-cil/verseglass.git
cd verseglass
./build.sh
open dist/Verseglass.app
```

`./build.sh` compiles arm64 and x86_64, joins them with `lipo`, and writes `dist/Verseglass.app`. The app is ad-hoc signed. It does not appear in the Dock. Look for the music-note icon on the right side of the menu bar.

To check the tests without packaging the app:

```bash
swift test
```

Quit from the menu-bar icon. The built app is local; this repository does not ship a notarized download.
