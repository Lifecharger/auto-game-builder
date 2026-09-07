import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'asset_flow_screen.dart';
import 'cbn_flow_screen.dart';

/// "Hat" sekmesi: iki yayin hatti arasinda gecis - Jigsaw (jpg + mp4 + webp)
/// ve CBN (color-by-number varlik klasorleri). Ikisi de ayni 2-3-4 akisini
/// kullanir; anahtar ust cubukta durur, secim oturum boyunca kalir.
class FlowHub extends StatefulWidget {
  const FlowHub({super.key});

  @override
  State<FlowHub> createState() => _FlowHubState();
}

class _FlowHubState extends State<FlowHub> {
  String _kind = 'jigsaw';

  Widget _switch() => SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'jigsaw', label: Text('Jigsaw')),
          ButtonSegment(value: 'cbn', label: Text('CBN')),
        ],
        selected: {_kind},
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onSelectionChanged: (v) {
          HapticFeedback.selectionClick();
          setState(() => _kind = v.first);
        },
      );

  @override
  Widget build(BuildContext context) => _kind == 'cbn'
      ? CbnFlowScreen(key: const ValueKey('cbn'), kindSwitch: _switch())
      : AssetFlowScreen(key: const ValueKey('jigsaw'), kindSwitch: _switch());
}
