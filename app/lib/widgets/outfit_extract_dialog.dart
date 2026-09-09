import 'package:flutter/material.dart';

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
      builder: (c, setLocal) => AlertDialog(
        scrollable: true,
        title: const Text('Kiyafet cikar'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Secili gorseldeki kisi silinir, uzerindeki kiyafet duz gri '
                  'fonda hayalet manken urun karesi olarak gardiroba yazilir. '
                  'Sonra her karakterde skin olarak giydirilir.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: ad,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Kiyafet adi', hintText: 'orn. Kirmizi gece elbisesi'),
              ),
              const SizedBox(height: 12),
              const Text('Tur',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              kindSelector(
                value: tur,
                onChanged: (v) => setLocal(() => tur = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kategori,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: [
                  for (final k in kategoriler)
                    DropdownMenuItem(
                        value: '${k['id']}', child: Text('${k['label']}')),
                ],
                onChanged: (v) => setLocal(() => kategori = v ?? 'set'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: not,
                decoration: const InputDecoration(
                    labelText: 'Not (istege bagli)',
                    hintText: 'orn. sadece elbise, ayakkabilar haric'),
                maxLines: 2,
              ),
              const SizedBox(height: 6),
              const Text(
                  'Set: kisinin ustundeki her sey tek karede. Silah/aksesuar: '
                  'yalniz o nesne, mankensiz.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cikar')),
        ],
      ),
    ),
  );
  if (ok != true) return null;
  final isim = ad.text.trim();
  if (isim.isEmpty) return null;
  return OutfitExtractChoice(isim, kategori, tur, not.text.trim());
}
