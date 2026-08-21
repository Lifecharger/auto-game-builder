import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../services/report_service.dart';
import '../theme.dart';

/// "Report a bug / suggestion" screen. Opened from Settings. Lets the user pick
/// a category, write a message, attach up to 3 screenshots, and send it to the
/// shared game-reports Worker.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _Category {
  final String value;
  final String label;
  final IconData icon;
  const _Category(this.value, this.label, this.icon);
}

class _PickedShot {
  final Uint8List bytes;
  final String filename;
  final MediaType contentType;
  const _PickedShot(this.bytes, this.filename, this.contentType);
}

class _ReportScreenState extends State<ReportScreen> {
  static const _categories = [
    _Category('bug', 'Bug', Icons.bug_report_outlined),
    _Category('suggestion', 'Suggestion', Icons.lightbulb_outline),
    _Category('other', 'Other', Icons.chat_bubble_outline),
  ];

  final _controller = TextEditingController();
  final _picker = ImagePicker();
  String _category = 'bug';
  final List<_PickedShot> _shots = [];
  bool _sending = false;
  bool _consent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _totalBytes => _shots.fold(0, (s, e) => s + e.bytes.length);

  static MediaType _mimeFor(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return MediaType('image', 'png');
    if (p.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg'); // jpg / jpeg / default
  }

  Future<void> _addShots() async {
    if (_shots.length >= ReportService.maxShots) return;
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1920,
      );
      if (picked.isEmpty) return;
      final remaining = ReportService.maxShots - _shots.length;
      for (final x in picked.take(remaining)) {
        final bytes = await x.readAsBytes();
        _shots.add(_PickedShot(bytes, x.name, _mimeFor(x.path)));
      }
      if (mounted) setState(() {});
      if (_totalBytes > ReportService.maxTotalBytes && mounted) {
        _snack('Screenshots are large — you may need to remove one.');
      }
    } catch (_) {
      if (mounted) _snack('Could not open the picker.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _canSubmit =>
      !_sending && _consent && _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final error = await ReportService.submit(
      category: _category,
      message: _controller.text,
      shots: _shots
          .map((s) => ReportShot(
                bytes: s.bytes,
                filename: s.filename,
                contentType: s.contentType,
              ))
          .toList(),
    );

    if (!mounted) return;
    setState(() => _sending = false);
    if (error == null) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Thanks! Your report was sent.'),
          backgroundColor: AppColors.success,
        ),
      );
      navigator.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Bug / Suggestion')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('What is this?'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _categories.map((c) {
                      final selected = _category == c.value;
                      return ChoiceChip(
                        label: Text(c.label),
                        avatar: Icon(c.icon, size: 18),
                        selected: selected,
                        onSelected: (_) => setState(() => _category = c.value),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _label('Tell us more'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    maxLines: 6,
                    maxLength: 4000,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'What happened, or what would you like to see?',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _label('Screenshots (optional)'),
                  const SizedBox(height: 8),
                  _shotsRow(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _consentTile(),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _canSubmit ? _submit : null,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Sending…' : 'Send report'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shotsRow() {
    return Row(
      children: [
        for (var i = 0; i < _shots.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_shots[i].bytes,
                      width: 64, height: 64, fit: BoxFit.cover),
                ),
                Positioned(
                  top: -10,
                  right: -10,
                  child: IconButton(
                    icon: Icon(Icons.cancel, color: AppColors.error, size: 20),
                    onPressed: () => setState(() => _shots.removeAt(i)),
                  ),
                ),
              ],
            ),
          ),
        if (_shots.length < ReportService.maxShots)
          InkWell(
            onTap: _addShots,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Icon(Icons.add_a_photo_outlined, color: AppColors.accent),
            ),
          ),
      ],
    );
  }

  Widget _consentTile() {
    return Card(
      child: InkWell(
        onTap: () => setState(() => _consent = !_consent),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                activeColor: AppColors.accent,
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 12, right: 8),
                  child: Text(
                    'I agree to send this report with my device info (model, OS and app version) to the developer to help fix issues.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }
}
