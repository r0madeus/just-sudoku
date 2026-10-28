# Küçültülmüş motor

Resmi Godot şablonu 3D, fizik, navigasyon, XR, Vulkan ve oyunun kullanmadığı onlarca modülü içerir. `engine/custom.py` yalnızca oyunun kullandıklarıyla derlenmiş bir şablon tanımlar. Dört sürüm de bu profili kullanır; GitHub her biri için şablonu kendisi derler, profilin özetine göre önbelleğe alır (yalnızca `engine/custom.py`, Godot sürümü ya da iş akışındaki `TEMPLATE_REVISION` değişince yeniden derlenir) ve oyunu onunla dışa aktarır.

| Sürüm | İş akışı | Şablon | Ayrıntı |
|---|---|---|---|
| Android | `android.yml` | `scons platform=android target=template_release arch=arm64 swappy=no` | [android.md](android.md#küçültülmüş-motor-daha-küçük-apk) |
| Tarayıcı | `web.yml` | `scons platform=web target=template_release threads=no arch=wasm32` (Emscripten 4.0.11) | [web.md](web.md) |
| Windows | `windows.yml` | `scons platform=windows target=template_release arch=x86_64 use_mingw=yes vulkan=no d3d12=no` (MinGW ile çapraz derleme) | aşağıda |
| Linux | `linux.yml` | `scons platform=linuxbsd target=template_release arch=x86_64 vulkan=no`, Ubuntu 22.04'te | [linux.md](linux.md) |

Hepsinde `profile=<oyun>/engine/custom.py` verilir. Web, Windows ve Linux çalıştırmalarının özetinde, oyunun resmi şablonla ve küçültülmüş şablonla dışa aktarılmış hâlinin boyutları yan yana yazılır; küçültülmüş olan daha küçük değilse iş kırmızı olur.

## Windows

Şablon Linux makinesinde MinGW (`mingw-w64`, POSIX iş parçacığı sürümü) ile derlenir; çıkan `godot.windows.template_release.x86_64.exe` dosyası dışa aktarmada Windows ön ayarının özel şablonu olur. Oyun OpenGL (Uyumluluk) ile çizer: Vulkan ve Direct3D 12 sürücüleri kapalıdır.

CI Windows exe'sini çalıştıramaz (Linux makinesi), yalnızca dosyanın 64-bit bir Windows programı olduğunu denetler. Açılışı gerçekten denemek için: çalıştırmanın *Artifacts* bölümündeki `just-sudoku-windows` zip'ini indirip Windows'ta aç.

## Ön ayar

`export_presets.cfg` resmi şablonu kullanmaya devam eder. CI, derleme sırasında `tools/use_slim_template.py <ön ayar numarası> <şablon>` ile yalnızca o ön ayarın `custom_template/release` satırını kendi şablonuna çevirir (testi `tests/test_engine_profile.gd`'de). Düzenleyicide *Run* ya da elle dışa aktarma bu yüzden ek kurulum istemez.

## Yeni özellik eklerken

`tests/test_engine_profile.gd` küçültülmüş motorda olmayan bir sınıf kullanılırsa uyarır. Godot'nun kullanımdan kaldırılmış (deprecated) işlevleri de bu motorda yoktur.
