// Forced update gate (2026-09-26, user: "update can't skip").
//
// Copied UNCHANGED into every Life Charger Flutter app (sync: C:/Cloudflare Workers/_build/
// sync_update_gate.py). Wrap the root widget:  runApp(ForcedUpdateGate(child: MyApp()));
//
// On launch (after the first frame) and every return to the foreground it asks Google Play
// whether a newer version exists. If one does, Play's own IMMEDIATE update screen runs; if the
// player backs out of it or it fails, a full-screen "Update required" page covers the app with a
// single Update button (again the immediate flow, or the store page when Play does not allow it).
// There is no way past it but updating.
//
// When the check itself cannot be made (offline, installed outside Play, debug build, tests)
// the app runs normally: a player is never locked out because Play could not be asked.
//
// Self-contained on purpose: it sits ABOVE MaterialApp, so it brings its own Directionality and
// styling and reads the device language for its three strings.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

class ForcedUpdateGate extends StatefulWidget {
  const ForcedUpdateGate({super.key, required this.child});

  final Widget child;

  /// Off under `flutter test` unless a test turns it on (and supplies [checkForTest]).
  @visibleForTesting
  static bool enabledInTests = false;

  /// Test seam: stands in for Play's update check. Returns true when an update is available.
  @visibleForTesting
  static Future<bool> Function()? checkForTest;

  @override
  State<ForcedUpdateGate> createState() => _ForcedUpdateGateState();
}

class _ForcedUpdateGateState extends State<ForcedUpdateGate> with WidgetsBindingObserver {
  bool _blocked = false;
  bool _checking = false;
  bool _starting = false;
  AppUpdateInfo? _info;

  bool get _active {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return ForcedUpdateGate.enabledInTests;
    return !kIsWeb && Platform.isAndroid && !kDebugMode;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check(startUpdate: true)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Play's update screen (cancelled) or from anywhere else: ask again.
    if (state == AppLifecycleState.resumed) unawaited(_check(startUpdate: !_blocked));
  }

  Future<void> _check({required bool startUpdate}) async {
    if (!_active || _checking) return;
    _checking = true;
    try {
      bool needed;
      final Future<bool> Function()? fake = ForcedUpdateGate.checkForTest;
      if (fake != null) {
        needed = await fake();
      } else {
        final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
        _info = info;
        needed = info.updateAvailability == UpdateAvailability.updateAvailable ||
            info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress;
      }
      if (!mounted) return;
      if (needed != _blocked) setState(() => _blocked = needed);
      if (needed && startUpdate) await _startUpdate();
    } catch (e) {
      // Play could not be asked (offline, not a Play install): the player keeps playing.
      debugPrint('[UpdateGate] update check failed: $e');
    } finally {
      _checking = false;
    }
  }

  Future<void> _startUpdate() async {
    if (_starting) return;
    _starting = true;
    try {
      final AppUpdateInfo? info = _info;
      final bool immediate = info != null &&
          (info.immediateUpdateAllowed ||
              info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress);
      if (immediate) {
        final AppUpdateResult result = await InAppUpdate.performImmediateUpdate();
        debugPrint('[UpdateGate] immediate update: $result');
        // success restarts the app into the new version; anything else leaves the gate up.
      } else if (ForcedUpdateGate.checkForTest == null) {
        await _openStore(info?.packageName);
      }
    } catch (e) {
      debugPrint('[UpdateGate] update flow failed: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> _openStore(String? packageName) async {
    if (packageName == null || packageName.isEmpty) return;
    final Uri market = Uri.parse('market://details?id=$packageName');
    final Uri web = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
    try {
      if (await launchUrl(market, mode: LaunchMode.externalApplication)) return;
    } catch (e) {
      debugPrint('[UpdateGate] market link failed: $e');
    }
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[UpdateGate] store page failed: $e');
    }
  }

  Future<void> _onUpdatePressed() async {
    // Re-read Play first: the info may be stale after a cancelled flow.
    await _check(startUpdate: false);
    if (_blocked) await _startUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final ui.Locale locale = ui.PlatformDispatcher.instance.locale;
    final _GateText text = _GateText.of(locale.languageCode);
    final TextDirection dir = _GateText.rtl.contains(locale.languageCode) ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: dir,
      child: Stack(
        children: <Widget>[
          widget.child,
          if (_blocked)
            Positioned.fill(
              child: _BlockingPage(text: text, onUpdate: _onUpdatePressed),
            ),
        ],
      ),
    );
  }
}

class _BlockingPage extends StatelessWidget {
  const _BlockingPage({required this.text, required this.onUpdate});

  final _GateText text;
  final Future<void> Function() onUpdate;

  @override
  Widget build(BuildContext context) {
    // Above MaterialApp there is no Theme, MediaQuery or Localizations: build what this page needs.
    return MediaQuery.fromView(
      view: View.of(context),
      child: Material(
        key: const Key('forced_update_gate'),
        color: const Color(0xF20E0B16),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.system_update, size: 64, color: Color(0xFFFF4FA3)),
                  const SizedBox(height: 20),
                  Text(
                    text.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text.body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFCFC8DD), fontSize: 15, height: 1.35),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      key: const Key('forced_update_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4FA3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => unawaited(onUpdate()),
                      child: Text(text.button, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GateText {
  const _GateText(this.title, this.body, this.button);

  final String title;
  final String body;
  final String button;

  static const Set<String> rtl = <String>{'ar', 'he', 'fa', 'ur'};

  static _GateText of(String languageCode) => _all[languageCode] ?? _all['en']!;

  static const Map<String, _GateText> _all = <String, _GateText>{
    'en': _GateText('Update required', 'A new version is available. Please update to keep playing.', 'Update'),
    'tr': _GateText('Güncelleme gerekli', 'Yeni bir sürüm var. Devam etmek için lütfen güncelle.', 'Güncelle'),
    'de': _GateText('Update erforderlich', 'Eine neue Version ist verfügbar. Bitte aktualisiere, um weiterzuspielen.', 'Aktualisieren'),
    'es': _GateText('Actualización necesaria', 'Hay una nueva versión. Actualiza para seguir jugando.', 'Actualizar'),
    'fr': _GateText('Mise à jour requise', 'Une nouvelle version est disponible. Mets à jour pour continuer.', 'Mettre à jour'),
    'it': _GateText('Aggiornamento necessario', 'È disponibile una nuova versione. Aggiorna per continuare a giocare.', 'Aggiorna'),
    'pt': _GateText('Atualização necessária', 'Há uma nova versão. Atualize para continuar jogando.', 'Atualizar'),
    'ru': _GateText('Требуется обновление', 'Доступна новая версия. Обновите приложение, чтобы продолжить.', 'Обновить'),
    'ja': _GateText('アップデートが必要です', '新しいバージョンがあります。続けるにはアップデートしてください。', 'アップデート'),
    'ko': _GateText('업데이트 필요', '새 버전이 있습니다. 계속하려면 업데이트하세요.', '업데이트'),
    'zh': _GateText('需要更新', '有新版本可用。请更新后继续。', '更新'),
    'ar': _GateText('التحديث مطلوب', 'يتوفر إصدار جديد. يرجى التحديث لمتابعة اللعب.', 'تحديث'),
    'hi': _GateText('अपडेट ज़रूरी है', 'नया संस्करण उपलब्ध है। खेलना जारी रखने के लिए अपडेट करें।', 'अपडेट करें'),
    'id': _GateText('Pembaruan diperlukan', 'Versi baru tersedia. Perbarui untuk terus bermain.', 'Perbarui'),
    'nl': _GateText('Update vereist', 'Er is een nieuwe versie. Werk bij om verder te spelen.', 'Bijwerken'),
    'pl': _GateText('Wymagana aktualizacja', 'Dostępna jest nowa wersja. Zaktualizuj, aby grać dalej.', 'Aktualizuj'),
    'vi': _GateText('Cần cập nhật', 'Đã có phiên bản mới. Vui lòng cập nhật để tiếp tục.', 'Cập nhật'),
    'th': _GateText('ต้องอัปเดต', 'มีเวอร์ชันใหม่ โปรดอัปเดตเพื่อเล่นต่อ', 'อัปเดต'),
  };
}
