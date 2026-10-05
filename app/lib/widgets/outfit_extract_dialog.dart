import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/character_flow_screen.dart' show kindSelector;
import '../services/character_flow_service.dart';

/// #329: "Kiyafet cikar" penceresinin sonucu.
class OutfitExtractChoice {
  final String name;
  final String category;
  final String kind;
  final String note;
  const OutfitExtractChoice(this.name, this.category, this.kind, this.note);
}

/// #329: secili TEK gorseldeki kiyafeti gardirop kutuphanesine cikarmak icin
/// ad / tur / kategori / not sorar. Galeri (her kip) ve Jigsaw akisi
/// (incoming/staging/pushed) ayni pencereyi kullanir; kaynak gorseli cagiran
/// bilir, pencere yalniz kayit bilgisini toplar.
Future<OutfitExtractChoice?> showOutfitExtractDialog(BuildContext context,
    {String kind = 'female', String category = 'set'}) async {
  final ad = TextEditingController();
  final not = TextEditingController();
  var tur = kind;
  var kategori = category;
  final kategoriler = CharacterFlowService.defaultOutfitCategories;
  if (!kategoriler.any((k) => k['id'] == kategori)) kategori = 'set';
  if (!CharacterFlowService.characterKinds.any((k) => k['id'] == tur)) {
    tur = 'female';
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setLocal) {
        final l10n = AppLocalizations.of(c)!;
        return AlertDialog(
        scrollable: true,
        title: Text(l10n.outfitExtractTitle),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.outfitExtractBody,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: ad,
                autofocus: true,
                decoration: InputDecoration(
                    labelText: l10n.outfitExtractName,
                    hintText: l10n.outfitExtractNameHint),
              ),
              const SizedBox(height: 12),
              Text(l10n.type,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              kindSelector(
                value: tur,
                onChanged: (v) => setLocal(() => tur = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kategori,
                decoration: InputDecoration(labelText: l10n.commonCategory),
                items: [
                  for (final k in kategoriler)
                    DropdownMenuItem(
                        value: '${k['id']}',
                        child: Text(
                            CharacterFlowService.categoryLabel('${k['id']}'))),
                ],
                onChanged: (v) => setLocal(() => kategori = v ?? 'set'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: not,
                decoration: InputDecoration(
                    labelText: l10n.outfitExtractNote,
                    hintText: l10n.outfitExtractNoteHint),
                maxLines: 2,
              ),
              const SizedBox(height: 6),
              Text(l10n.outfitExtractHelp,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l10n.outfitExtractAction)),
        ],
      );
      },
    ),
  );
  if (ok != true) return null;
  final isim = ad.text.trim();
  if (isim.isEmpty) return null;
  return OutfitExtractChoice(isim, kategori, tur, not.text.trim());
}
