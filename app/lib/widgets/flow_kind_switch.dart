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
          // #353: her ekranda AYNI genislik - segmentler satiri esit boler
          // (Uretilenler'deki gorunum); dar app bar basliginda kuculmuyor
          // cunku artik baslikta degil, app bar'in ALTINDA duruyor.
          expandedInsets: EdgeInsets.zero,
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

/// #353: kip/hat anahtarini app bar'in ALTINA, tam genislikte koyar
/// (Uretilenler ekranindaki kalip). Sekme cubugu varsa altina eklenir.
/// Anahtar null ise yalniz sekme cubugu (ya da hic bir sey) doner.
PreferredSizeWidget? kindSwitchBottom(Widget? kindSwitch,
    {PreferredSizeWidget? tabs}) {
  if (kindSwitch == null) return tabs;
  final h = 46.0 + (tabs?.preferredSize.height ?? 0);
  return PreferredSize(
    preferredSize: Size.fromHeight(h),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: SizedBox(width: double.infinity, child: kindSwitch),
        ),
        if (tabs != null) tabs,
      ],
    ),
  );
}
