# Verseglass

[English](../../README.md) · [Türkçe](README.md)

macOS için menü çubuğu söz kartı. Diğer uygulamaların üstünde durur. Söylenen satır beyazdır; bir önceki satır onun üstünde soluk, sonrakiler altında soluktur. Kartı istediğin yere sürükle. Dock ikonu ve hesap yoktur.

Spotify ile tarayıcıdaki YouTube veya YouTube Music desteklenir. Sözler ücretsiz [LRCLIB](https://lrclib.net) kaynağından gelir, anahtar gerekmez. Mac’te cihaz içi çeviri dili yüklüyse her satırın altında çeviri görünebilir.

**macOS 15** ve sonrası gerekir; Apple Silicon ve Intel. macOS 14 ve öncesi desteklenmez. Ücretli Apple Developer üyeliği gerekmez.

```bash
git clone https://github.com/emre-cil/verseglass.git
cd verseglass
./build.sh
open dist/Verseglass.app
```

`./build.sh` tek bir evrensel uygulama üretir ve onu ad-hoc imzalar.

## Kart

- Söylenen satır beyazdır.
- Önceki satır soluktur ve üstte durur.
- Sonraki satırlar soluktur ve altta durur.
- Kartı sürükleyince yeri hatırlanır.
- Menü çubuğundaki nota; kaydırma, gizleme ve çıkışı açar.

## Rehberler

- [Kurulum](install.md)
- [İzinler](permissions.md)
- [Oynatıcılar](players.md)
- [Sözler](lyrics.md)
- [Çeviri](translation.md)
- [Sorun giderme](troubleshooting.md)

## Lisans

[MIT](../../LICENSE)
