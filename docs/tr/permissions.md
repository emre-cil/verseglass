# İzinler

[English](../permissions.md) · [Türkçe](permissions.md)

Verseglass Erişilebilirlik, ekran kaydı veya tam disk erişimi istemez.

**Spotify.** Spotify çalarken macOS ilk seferde Automation izni sorar. Uygulama parça adını ve konumu buradan okur. Sonradan Sistem Ayarları → Gizlilik ve Güvenlik → Automation altından değiştirilebilir.

**YouTube ve YouTube Music.** Tarayıcı için Automation penceresi çıkmaz. Çalma bilgisi, Apple imzalı `/usr/bin/swift` ile çalışan küçük bir yardımcıdan okunur. macOS 15.4 ve sonrası Şimdi Çalıyor verisini imzasız uygulamaya vermez; yardımcı bu yüzden vardır. Betik, uygulamanın içindeki `now_playing_helper.swift` dosyasıdır.

Bir oynatıcı boş kalırsa [Sorun giderme](troubleshooting.md) bölümüne bak.
