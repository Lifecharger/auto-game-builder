import 'package:flutter/foundation.dart';

/// Uygulama modu.
///
/// `Code Mod`  : proje yonetimi (dashboard, issues, raporlar, kontrol)
/// `Asset Mod` : yerel uretim (uretim, uretilenler)
///
/// Ayarlar her iki modda da son sekme olarak sabit kalir.
/// MainShell bu bildiriciyi dinler; ekranlar sadece [toggle] cagirir,
/// birbirlerinin state'ini tanimalarina gerek kalmaz.
/// #363: ucuncu mod `Delivery Mod` - uygulamalara ne sunulacaginin
/// anahtarlari (olasi bir Play strike'ina hizli tepki). `mode` bildiricisi
/// uc degerden birini tasir; `assetMode` geriye uyum icin eslenik kalir.
class ModeService {
  ModeService._();

  static const code = 'code';
  static const asset = 'asset';
  static const delivery = 'delivery';

  static final ValueNotifier<String> mode = ValueNotifier<String>(code);
  static final ValueNotifier<bool> assetMode = ValueNotifier<bool>(false);

  static bool get isAsset => mode.value == asset;
  static bool get isDelivery => mode.value == delivery;
  static bool get isCode => mode.value == code;

  static void setMode(String m) {
    if (m != code && m != asset && m != delivery) m = code;
    if (mode.value == m) return;
    mode.value = m;
    assetMode.value = m == asset;
  }

  static void toggle() => setMode(isAsset ? code : asset);

  static void set(bool asset_) => setMode(asset_ ? asset : code);
}
