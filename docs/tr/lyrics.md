# Sözler

[English](../lyrics.md) · [Türkçe](lyrics.md)

Zamanlı sözler herkese açık [LRCLIB](https://lrclib.net) API’sinden gelir. API anahtarı yoktur. İstek bir `Verseglass` kullanıcı kimliği ile parça adı, sanatçı ve süreyi gönderir.

Kart LRC zaman damgalarını kullanır:

- Beyaz satır, çalma konumundan önceki son damgadır.
- Ondan önceki boş olmayan bir satır üstte, soluk gösterilir.
- Sonraki en fazla üç boş olmayan satır altta, soluk gösterilir.
- İlk damgadan önce kart yaklaşan satırlarla dolar; hiçbiri güncel diye işaretlenmez.

Parça başına kaydırma, her damgayı 0,5 saniye oynatır. Menüdeki **0,5 sn geri** ve **0,5 sn ileri** bunu yapar. Kaydırma o parça için bu Mac’te saklanır.

Bulunan sözler ve kısa süreli boş sonuçlar `~/Library/Application Support/Verseglass/lyrics` altında tutulur.
