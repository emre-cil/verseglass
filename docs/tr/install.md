# Kurulum

[English](../install.md) · [Türkçe](install.md)

macOS 15 veya sonrası ve bir Swift araç takımı gerekir (Xcode 26 veya ona uygun komut satırı araçları). Uygulama hem Apple Silicon hem Intel’de çalışır. Derlemek için ücretli Apple Developer hesabı gerekmez.

```bash
git clone https://github.com/emre-cil/verseglass.git
cd verseglass
./build.sh
open dist/Verseglass.app
```

`./build.sh` arm64 ve x86_64 derler, `lipo` ile birleştirir ve `dist/Verseglass.app` yazar. Uygulama ad-hoc imzalıdır. Dock’ta görünmez. Menü çubuğunun sağındaki nota simgesine bak.

Uygulamayı paketlemeden testler:

```bash
swift test
```

Menü çubuğu simgesinden çık. Depo noterize edilmiş bir indirme dağıtmaz; uygulama yerelde derlenir.
