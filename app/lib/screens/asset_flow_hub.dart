import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'asset_flow_screen.dart';
import 'card_flow_screen.dart';
import 'cbn_flow_screen.dart';
import 'character_flow_screen.dart';
import 'free_flow_screen.dart';
import '../widgets/flow_kind_switch.dart';

/// "Hat" sekmesi: dort yayin hatti arasinda gecis - Jigsaw (jpg + mp4 + webp),
/// CBN (color-by-number varlik klasorleri), Kart (#323: Hot Card Games
/// koleksiyon kartlari) ve Karakter (isimli kadin karakterler). Jigsaw ile CBN
/// ayni 2-3-4 akisini kullanir; Kart'in dort asamasi (Still / Video / WebP /
/// Push), Karakter'in kendi uc asamasi vardir. Anahtar ust cubukta durur,
/// secim oturum boyunca kalir.
///
/// Sira SABIT: Jigsaw | CBN | Kart | Karakter - Kart, Karakter'den ONCE
/// (design/kart_modu.md).
class FlowHub extends StatefulWidget {
  const FlowHub({super.key});

  @override
  State<FlowHub> createState() => _FlowHubState();
}

class _FlowHubState extends State<FlowHub> {
  String _kind = 'jigsaw';

  // #327: ortak anahtar - dar ekranda sarmaz, sigmazsa olcekle kuculur.
  // #353: Free de bir hat (basit: duzenle / video uret) - Uretilenler'deki
  // anahtarla ayni sira: Free | Jigsaw | CBN | Kart | Karakter.
  Widget _switch() => FlowKindSwitch(
        items: kindLabels,                 // #355: tek kaynak
        selected: _kind,
        onChanged: (v) {
          HapticFeedback.selectionClick();
          setState(() => _kind = v);
        },
      );

  @override
  Widget build(BuildContext context) => switch (_kind) {
        'free' => FreeFlowScreen(key: const ValueKey('free'), kindSwitch: _switch()),
        'cbn' => CbnFlowScreen(key: const ValueKey('cbn'), kindSwitch: _switch()),
        'card' => CardFlowScreen(key: const ValueKey('card'), kindSwitch: _switch()),
        'character' => CharacterFlowScreen(
            key: const ValueKey('character'), kindSwitch: _switch()),
        _ => AssetFlowScreen(key: const ValueKey('jigsaw'), kindSwitch: _switch()),
      };
}
