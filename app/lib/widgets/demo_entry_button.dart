import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/demo/demo_mode.dart';
import '../services/usage_events.dart';
import '../theme.dart';

/// "Try demo" on the first screens (before pairing): opens the whole app on
/// bundled sample data, with no server and no network.
class DemoEntryButton extends StatelessWidget {
  const DemoEntryButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            key: const ValueKey('try-demo'),
            onPressed: () {
              HapticFeedback.lightImpact();
              Usage.used('demo_start');
              DemoMode.enter();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_circle_outline),
            label: Text(l10n.tryDemo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.tryDemoSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
