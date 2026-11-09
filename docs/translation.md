# Translation

[English](translation.md) · [Türkçe](tr/translation.md)

Translations are optional and free. Verseglass uses the on-device Translation framework that ships with macOS. Lines are not sent to a lyrics service for translation.

The target language is the language your Mac prefers. A line that already matches that language is not repeated under the original. If the language pack is installed, translations appear under each lyric line. If macOS supports the language but has not downloaded it, the menu offers **Download [language] translation**, which opens the system download. If the language cannot be translated on this Mac, the menu stays quiet and the original lines remain.

The menu and card chrome follow the same language list: English and Turkish ship in the app. Add another `*.lproj` next to `Resources/en.lproj` to translate the interface.
