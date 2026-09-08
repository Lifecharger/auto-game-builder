import 'package:flutter/material.dart';

/// #327: Kip / hat anahtari - her ekranda AYNI gorunum. Dar telefonda
/// SegmentedButton etiketleri satira sariyordu ("Jig/saw", "Kar/akt/er");
/// burada etiketler sarmaz, yazi kucuk ve yerine sigmiyorsa butun anahtar
/// olcekle kucultulur (FittedBox). AppBar basliginda da, govdede de calisir.
class FlowKindSwitch extends StatelessWidget {
  const FlowKindSwitch({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  /// deger -> etiket (sira korunur).
  final Map<String, String> items;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: SegmentedButton<String>(
          segments: [
            for (final e in items.entries)
              ButtonSegment(
                value: e.key,
                label: Text(e.value, maxLines: 1, softWrap: false),
              ),
          ],
          selected: {selected},
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 9)),
            textStyle: WidgetStatePropertyAll(
                Theme.of(context).textTheme.labelMedium),
          ),
          onSelectionChanged: (v) => onChanged(v.first),
        ),
      );
}
