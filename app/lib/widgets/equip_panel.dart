import 'package:flutter/material.dart';

import '../services/character_flow_service.dart';
import '../services/generate_service.dart';
import '../theme.dart';

/// #331: RPG giydirme secimi - set + tek secimli parcalar + coklu parcalar.
/// Sunucuya `outfit` (set slug) ve `pieces` (giydirme sirasiyla slug'lar)
/// olarak gider; sira `singlePieceCategories` + `multiPieceCategories`.
class EquipSelection {
  String set = '';
  final Map<String, String> single = {};
  final Map<String, List<String>> multi = {};

  bool get isEmpty => set.isEmpty && pieces.isEmpty;

  List<String> get pieces => [
        for (final c in CharacterFlowService.singlePieceCategories)
          if ((single[c] ?? '').isNotEmpty) single[c]!,
        for (final c in CharacterFlowService.multiPieceCategories)
          ...(multi[c] ?? const <String>[]),
      ];

  /// Bir yuvadaki secili slug'lar (set/tek = 0-1, coklu = n).
  List<String> of(String cat) {
    if (cat == 'set') return set.isEmpty ? const [] : [set];
    if (CharacterFlowService.multiPieceCategories.contains(cat)) {
      return List.unmodifiable(multi[cat] ?? const <String>[]);
    }
    final s = single[cat] ?? '';
    return s.isEmpty ? const [] : [s];
  }

  /// Yuvaya giydir / cikar. Coklu yuvada acma-kapama, digerlerinde degistirme.
  void toggle(String cat, String slug) {
    if (cat == 'set') {
      set = set == slug ? '' : slug;
    } else if (CharacterFlowService.multiPieceCategories.contains(cat)) {
      final l = List<String>.from(multi[cat] ?? const <String>[]);
      l.contains(slug) ? l.remove(slug) : l.add(slug);
      multi[cat] = l;
    } else {
      single[cat] = single[cat] == slug ? '' : slug;
    }
  }

  void clear(String cat) {
    if (cat == 'set') {
      set = '';
    } else if (CharacterFlowService.multiPieceCategories.contains(cat)) {
      multi.remove(cat);
    } else {
      single.remove(cat);
    }
  }

  void clearAll() {
    set = '';
    single.clear();
    multi.clear();
  }
}

/// #331: RPG yuvalari - sol sutun / sag sutun, ortada base. Sira = ekranda
/// yukaridan asagiya. `set` bir yuvadir (tam takim), parcalarla birlikte
/// kullanilabilir (sunucu once seti giydirir, sonra parcalari).
const kEquipLeft = <(String, String, IconData)>[
  ('hat', 'Kafa', Icons.face_retouching_natural),
  ('headgear', 'Kafalik', Icons.auto_awesome),
  ('top', 'Ust', Icons.checkroom),
  ('bottom', 'Alt', Icons.airline_seat_legroom_normal),
  ('socks', 'Corap', Icons.airline_seat_legroom_extra),
];
const kEquipRight = <(String, String, IconData)>[
  ('set', 'Set', Icons.dry_cleaning),
  ('shoes', 'Ayakkabi', Icons.ice_skating),
  ('accessory', 'Kolluk / Aks.', Icons.watch),
  ('weapon', 'Silah', Icons.gavel),
];

/// Kiyafet kucuk resmi (9:16 contain) - her yerde ayni gorunum.
Widget outfitThumb(OutfitItem o, {double width = 78, double height = 132,
    bool selected = false, double radius = 8}) =>
    Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: selected ? AppColors.success : Colors.white24,
            width: selected ? 2.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: Colors.black26,
        child: o.ready
            ? Image.network(
                CharacterFlowService.outfitThumbUrl(o.slug, size: 300),
                headers: CharacterFlowService.authHeaders,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.white10,
                  alignment: Alignment.center,
                  child: const Icon(Icons.checkroom, size: 20, color: Colors.grey),
                ),
              )
            : Container(
                color: Colors.white10,
                alignment: Alignment.center,
                child: const Text('kuyrukta',
                    style: TextStyle(fontSize: 10, color: Colors.orange)),
              ),
      ),
    );

/// #331: basili tutunca buyuk gorunum - tam boy kiyafet karesi + ad + prompt.
Future<void> showOutfitPreview(BuildContext context, OutfitItem o) =>
    showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  CharacterFlowService.outfitThumbUrl(o.slug, size: 1024),
                  headers: CharacterFlowService.authHeaders,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  Text(o.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(
                      '${CharacterFlowService.categoryLabel(o.category)}'
                      '${o.prompt.isEmpty ? "" : " - ${o.prompt}"}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

/// #331: bir yuva icin secici - o kategorinin kiyafetleri 3'lu izgara,
/// "(bos)" ile yuva temizlenir. Coklu yuvada kapanana kadar acma-kapama.
Future<void> showSlotPicker(
  BuildContext context, {
  required String cat,
  required List<OutfitItem> outfits,
  required EquipSelection selection,
  required VoidCallback onChanged,
}) {
  final list = outfits.where((o) => o.category == cat && o.ready).toList();
  final multi = CharacterFlowService.multiPieceCategories.contains(cat);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setLocal) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(c).size.height * 0.7,
          child: Column(
            children: [
              ListTile(
                title: Text('${CharacterFlowService.categoryLabel(cat)} yuvasi'),
                subtitle: Text(
                    multi
                        ? 'coklu secim - dokun: giydir / cikar'
                        : 'tek secim - dokun: giydir, tekrar dokun: cikar',
                    style: const TextStyle(fontSize: 11)),
                trailing: TextButton(
                  onPressed: () {
                    selection.clear(cat);
                    onChanged();
                    setLocal(() {});
                    if (!multi) Navigator.pop(c);
                  },
                  child: const Text('(bos)'),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Text('Bu kategoride hazir kiyafet yok - '
                            '"+ Kiyafet uret" ya da "Kiyafet cikar"',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey)))
                    : OutfitCatalogGrid(
                        outfits: list,
                        selected: (o) => selection.of(cat).contains(o.slug),
                        onTap: (o) {
                          selection.toggle(cat, o.slug);
                          onChanged();
                          setLocal(() {});
                          if (!multi) Navigator.pop(c);
                        },
                        onLongPress: (o) => showOutfitPreview(c, o),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// #331: 3'lu katalog izgarasi (satirda 3 kiyafet, kucuk kare + ad + kategori).
/// Dokunma = cagiranin menusu, basili tutma = buyuk gorunum.
class OutfitCatalogGrid extends StatelessWidget {
  const OutfitCatalogGrid({
    super.key,
    required this.outfits,
    required this.onTap,
    required this.onLongPress,
    this.selected,
    this.shrinkWrap = false,
  });

  final List<OutfitItem> outfits;
  final void Function(OutfitItem) onTap;
  final void Function(OutfitItem) onLongPress;
  final bool Function(OutfitItem)? selected;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.52,
        ),
        itemCount: outfits.length,
        itemBuilder: (_, i) {
          final o = outfits[i];
          final on = selected?.call(o) ?? false;
          return GestureDetector(
            onTap: () => onTap(o),
            onLongPress: () => onLongPress(o),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, cons) => outfitThumb(o,
                        width: cons.maxWidth,
                        height: cons.maxHeight,
                        selected: on),
                  ),
                ),
                const SizedBox(height: 3),
                Text(o.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        color: on ? AppColors.success : Colors.white)),
                Text(CharacterFlowService.categoryLabel(o.category),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: AppColors.accent)),
              ],
            ),
          );
        },
      );
}

/// #331: RPG giydirme paneli - ortada secili karakterin base'i (South),
/// iki yanda yuvalar; yuvaya dokun = secici, basili tut = giyili parcayi
/// buyut. Ustte base secici (hangi karakterin skini olusacak).
class EquipPanel extends StatelessWidget {
  const EquipPanel({
    super.key,
    required this.outfits,
    required this.selection,
    required this.characters,
    required this.selectedName,
    required this.onCharacter,
    required this.baseThumbUrl,
    required this.onChanged,
  });

  final List<OutfitItem> outfits;
  final EquipSelection selection;
  final List<CharacterItem> characters;
  final String selectedName;
  final ValueChanged<String> onCharacter;
  final String baseThumbUrl;
  final VoidCallback onChanged;

  OutfitItem? _find(String slug) {
    for (final o in outfits) {
      if (o.slug == slug) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sol = [for (final s in kEquipLeft) _slot(context, s)];
    final sag = [for (final s in kEquipRight) _slot(context, s)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Base:',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: characters.any((c) => c.name == selectedName)
                    ? selectedName
                    : null,
                isExpanded: true,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final c in characters)
                    DropdownMenuItem(
                      value: c.name,
                      child: Text(
                          '${c.name}${c.klass.isEmpty ? "" : "  (${c.klass})"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onCharacter(v);
                },
              ),
            ),
            TextButton(
              onPressed: selection.isEmpty
                  ? null
                  : () {
                      selection.clearAll();
                      onChanged();
                    },
              child: const Text('Soyun', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: sol)),
            const SizedBox(width: 6),
            // Ortada base (South) - 9:16.
            Container(
              width: 104,
              height: 185,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              clipBehavior: Clip.antiAlias,
              child: ColoredBox(
                color: Colors.black26,
                child: baseThumbUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.grey)
                    : Image.network(
                        baseThumbUrl,
                        headers: CharacterFlowService.authHeaders,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.person, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: Column(children: sag)),
          ],
        ),
      ],
    );
  }

  Widget _slot(BuildContext context, (String, String, IconData) s) {
    final (cat, etiket, ikon) = s;
    final secili = selection.of(cat);
    final ilk = secili.isEmpty ? null : _find(secili.first);
    final dolu = secili.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () => showSlotPicker(context,
            cat: cat,
            outfits: outfits,
            selection: selection,
            onChanged: onChanged),
        onLongPress: ilk == null ? null : () => showOutfitPreview(context, ilk),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: dolu ? AppColors.success.withValues(alpha: 0.12) : Colors.white10,
            border: Border.all(
                color: dolu ? AppColors.success : Colors.white24,
                width: dolu ? 1.5 : 1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                height: 38,
                child: ilk == null
                    ? Icon(ikon, size: 18, color: Colors.grey)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          CharacterFlowService.outfitThumbUrl(ilk.slug, size: 120),
                          headers: CharacterFlowService.authHeaders,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Icon(ikon, size: 18, color: Colors.grey),
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etiket,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    Text(
                        ilk == null
                            ? '-'
                            : (secili.length > 1
                                ? '${ilk.name} +${secili.length - 1}'
                                : ilk.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            color: dolu ? AppColors.success : Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// #329/#331: "Kiyafet cikar" icin kaynak secici - son tamamlanmis uretim
/// gorselleri (her kip) 3'lu izgara; secilen isin kimligi doner.
Future<GenerateJob?> pickGeneratedImage(BuildContext context) async {
  List<GenerateJob> jobs;
  try {
    jobs = (await GenerateService.list(limit: 60))
        .where((j) => j.isDone && !j.isVideo)
        .toList();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
    return null;
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<GenerateJob>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(c).size.height * 0.75,
        child: Column(
          children: [
            const ListTile(
              title: Text('Kaynak gorsel sec'),
              subtitle: Text('Son tamamlanmis uretimler (her kip). Jigsaw akisindaki '
                  'incoming/staging/pushed icin FlowHub > Jigsaw ekranini kullan.',
                  style: TextStyle(fontSize: 11)),
            ),
            const Divider(height: 1),
            Expanded(
              child: jobs.isEmpty
                  ? const Center(
                      child: Text('Tamamlanmis gorsel yok',
                          style: TextStyle(color: Colors.grey)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.6,
                      ),
                      itemCount: jobs.length,
                      itemBuilder: (_, i) {
                        final j = jobs[i];
                        return GestureDetector(
                          onTap: () => Navigator.pop(c, j),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ColoredBox(
                              color: Colors.black26,
                              child: Image.network(
                                j.thumbUrl(size: 300),
                                headers: GenerateService.authHeaders,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Container(color: Colors.white10),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
