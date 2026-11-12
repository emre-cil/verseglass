# Sorun giderme

[English](../troubleshooting.md) · [Türkçe](troubleshooting.md)

**Menü çubuğunda simge var, kart yok.** Kart ekranın sağ alt tarafına yakın başlar. Duraklatmak kartı gizlemez. **Kartı gizle** gizler. Tamamen saydam pencere eski bir derlemeydi. Güncel kart macOS 26 ve sonrasında buzlu cam, macOS 15’te koyu HUD panelidir.

**Kart “Söz yok” diyor.** LRCLIB’de o ad ve sanatçı için zamanlı söz yoktur. Zamansız metin şarkıya yayılmaz. Kaydırmayı ancak zamanlı eşleşme bulunduktan sonra dene.

**Spotify hiç görünmüyor.** Spotify’ın çaldığını doğrula, sonra Verseglass için Automation iznini ver. Spotify yalnızca duraklatılmışsa tarayıcının Şimdi Çalıyor parçası kullanılır.

**YouTube başlıkta kalıyor.** Yardımcı ilk seferde birkaç saniye sürebilir; `/usr/bin/swift` betiği derleyebilir. Tarayıcının sistemdeki Şimdi Çalıyor uygulaması olması gerekir. Başlıkta sanatçı zaten yazılıysa kanal adı ayıklanır.

**İki kart.** Menüden çık, sonra `/Applications/Verseglass.app` dosyasını bir kez aç. Kurmadıysan `dist/Verseglass.app` dosyasını bir kez aç. Çalışır kalan eski kopya kendi penceresini tutar.

**Intel Mac.** `./build.sh` x86_64 derlemesini bitirmelidir. `lipo -info dist/Verseglass.app/Contents/MacOS/Verseglass` hem `x86_64` hem `arm64` listelemelidir.
