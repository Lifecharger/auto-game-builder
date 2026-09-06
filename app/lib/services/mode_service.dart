import 'package:flutter/foundation.dart';

/// Uygulama modu.
///
/// `Code Mod`  : proje yonetimi (dashboard, issues, raporlar, kontrol)
/// `Asset Mod` : yerel uretim (uretim, uretilenler)
///
/// Ayarlar her iki modda da son sekme olarak sabit kalir.
/// MainShell bu bildiriciyi dinler; ekranlar sadece [toggle] cagirir,
/// birbirlerinin state'ini tanimalarina gerek kalmaz.
class ModeService {
  ModeService._();

  static final ValueNotifier<bool> assetMode = ValueNotifier<bool>(false);

  static bool get isAsset => assetMode.value;

  static void toggle() => assetMode.value = !assetMode.value;

  static void set(bool asset) => assetMode.value = asset;
}
