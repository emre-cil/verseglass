# Contributing

Issues and pull requests are welcome. Keep changes small and describe the behavior you are fixing or adding.

- macOS 15 is the oldest system the app runs on. Do not raise that floor without saying why.
- User-facing strings go in `Resources/en.lproj` and `Resources/tr.lproj`. English is the source language.
- Guides exist in English (`docs/`) and Turkish (`docs/tr/`). Update both when a guide changes.
- Do not add account names, machine paths, or private notes to the tree.

```bash
swift test
./build.sh
```
