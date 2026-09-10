import 'package:flutter/material.dart';

/// #327: Kip / hat anahtari - her ekranda AYNI gorunum. Dar telefonda
/// SegmentedButton etiketleri satira sariyordu ("Jig/saw", "Kar/akt/er");
/// burada etiketler sarmaz, sigmayan etiket kendi yuvasinda kuculur.
/// Tam genisliktir (expandedInsets); sinirli genislikli bir ebeveyn ister
/// (govde, app bar'in alti = kindSwitchBottom). Basliga (title) KOYMA.
/// #355: kip kimligi -> kisa etiket. Uretim, Uretilenler ve Hat hepsi BU
/// tablodan okur; kimse "Jigsaw Modu"ndan kelime kirparak etiket uretmez
/// ("Jigsawu" faciasi).
const Map<String, String> kindLabels = {
  'free': 'Free',
  'jigsaw': 'Jigsaw',
  'cbn': 'CBN',
  'card': 'Kart',
  'character': 'Karakter',
};

/// Tabloda olmayan kip icin sunucu etiketinden " Mod"/" Modu" ekini atar.
String kindLabel(String id, [String? fallback]) =>
    kindLabels[id] ??
    (fallback ?? id).replaceAll(RegExp(r'\s+Modu?$', caseSensitive: false), '');

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
  Widget build(BuildContext context) => SegmentedButton<String>(
        segments: [
          for (final e in items.entries)
            ButtonSegment(
              value: e.key,
              // Etiket kendi yuvasina sigmiyorsa yalniz o etiket kuculur;
              // asla satira sarmaz.
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(e.value, maxLines: 1, softWrap: false),
              ),
            ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        // #353: her ekranda AYNI genislik - segmentler satiri esit boler
        // (Uretilenler'deki gorunum). #354: eskiden butun anahtar bir
        // FittedBox icindeydi; FittedBox cocuga SINIRSIZ genislik verir,
        // expandedInsets ise sonsuz genislige yayilmaya calisir -> anahtar
        // hicbir ekranda cizilmiyordu ("modlar yok oldu"). FittedBox kalkti;
        // anahtar her zaman sinirli genislikli bir ebeveyn icinde kullanilir.
        expandedInsets: EdgeInsets.zero,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 6)),
          textStyle: WidgetStatePropertyAll(
              Theme.of(context).textTheme.labelMedium),
        ),
        onSelectionChanged: (v) => onChanged(v.first),
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
