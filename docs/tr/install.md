# Kurulum

[English](../install.md) · [Türkçe](install.md)

macOS 15 veya sonrası gerekir. Uygulama hem Apple Silicon hem Intel’de çalışır. İndirilen paketi kurmak için Xcode veya Apple Developer hesabı gerekmez.

1. [Verseglass-macOS.zip](https://github.com/emre-cil/verseglass/releases/latest/download/Verseglass-macOS.zip) dosyasını indir.
2. Zip’i aç.
3. `Install.command` dosyasına çift tıkla.

Bu, `Verseglass.app` dosyasını `/Applications` içine kopyalar ve Açılışta başlat’ı açar. Uygulama Dock’ta görünmez. Menü çubuğunun sağındaki nota simgesine bak. Spotlight’ta Verseglass diye aranır. Aynı anahtar menüdedir; açılışta başlamasını sonradan kapatabilirsin.

İndirme ad-hoc imzalıdır, noterize değildir. `Install.command` karantina işaretini kaldırır ve `/Applications` kopyasını imzalar. macOS uygulamayı yine de engellerse `Verseglass.app` üzerine sağ tıkla, Aç’ı seç ve onayla. macOS, Sistem Ayarları → Genel → Açılışta açılan öğeler altında Verseglass’a izin vermeni de isteyebilir.

Kaynak koddan derleyip kurmak için bir Swift araç takımı gerekir (Xcode 26 veya ona uygun komut satırı araçları):

```bash
git clone https://github.com/emre-cil/verseglass.git
cd verseglass
./install.sh
```

Yalnızca `./build.sh` arm64 ve x86_64 derler, `lipo` ile birleştirir ve `dist/Verseglass.app` ile `dist/Verseglass-macOS.zip` yazar. Uygulamayı `/Applications` içine kopyalamaz.

Uygulamayı paketlemeden testler:

```bash
swift test
```

Menü çubuğu simgesinden çık. İki kart görünürse her kopyayı kapat, sonra `/Applications/Verseglass.app` dosyasını bir kez aç.
