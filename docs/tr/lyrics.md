# Sözler

[English](../lyrics.md) · [Türkçe](lyrics.md)

Zamanlı sözler herkese açık [LRCLIB](https://lrclib.net) API’sinden gelir. API anahtarı yoktur. İstek bir `Verseglass` kullanıcı kimliği ile parça adı, sanatçı ve süreyi gönderir.

Kart LRC zaman damgalarını kullanır:

- Beyaz satır, çalma konumundan önceki son damgadır. Harfler satır boyunca dolar; `<00:12.50>` gibi kelime damgaları kelime kelime ilerler.
- Menü komşu satır sayısını seçer: yalnızca bu satır, iki yanda birer satır, ya da üstte bir ve altta üç satır.
- İlk damgadan önce kart yaklaşan satırlarla dolar; hiçbiri güncel diye işaretlenmez.
- **Söz seç** başka zamanlı eşleşmeleri listeler. **Söz yapıştır…** o parça için bir LRC’yi bu Mac’te saklar. **Otomatik eşleşmeyi kullan** bu seçimi siler.

Parça başına kaydırma, her damgayı 0,5 saniye oynatır. Menüdeki **0,5 sn geri** ve **0,5 sn ileri** bunu yapar. Kaydırma o parça için bu Mac’te saklanır.

Bulunan sözler ve kısa süreli boş sonuçlar `~/Library/Application Support/Verseglass/lyrics` altında tutulur.
