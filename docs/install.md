# Install

[English](install.md) · [Türkçe](tr/install.md)

You need macOS 15 or later. The app runs on both Apple Silicon and Intel. Installing the download does not need Xcode or an Apple Developer account.

1. Download [Verseglass-macOS.zip](https://github.com/emre-cil/verseglass/releases/latest/download/Verseglass-macOS.zip).
2. Unzip it.
3. Double-click `Install.command`.

That copies `Verseglass.app` to `/Applications` and turns on Open at login. The app does not appear in the Dock. Look for the music-note icon on the right side of the menu bar. Spotlight finds it as Verseglass. The same switch is in the menu if you want to turn login launch off later.

The download is ad-hoc signed and not notarized. `Install.command` clears the quarantine flag and signs the copy in `/Applications`. If macOS still blocks the app, right-click `Verseglass.app`, choose Open, and confirm. macOS may also ask you to allow Verseglass under System Settings → General → Login Items.

To build and install from source you need a Swift toolchain (Xcode 26 or the matching command-line tools):

```bash
git clone https://github.com/emre-cil/verseglass.git
cd verseglass
./install.sh
```

`./build.sh` alone compiles arm64 and x86_64, joins them with `lipo`, and writes `dist/Verseglass.app` plus `dist/Verseglass-macOS.zip`. It does not copy the app into `/Applications`.

To check the tests without packaging the app:

```bash
swift test
```

Quit from the menu-bar icon. If two cards appear, quit every copy, then open `/Applications/Verseglass.app` once.
