import 'dart:async';

import 'package:flutter/material.dart';

/// A brief message near the top of the screen, just below the status bar.
///
/// Studio rule: no SnackBars. The toast is drawn in the root overlay, never
/// under a system bar, does not block taps and fades out by itself after
/// about two seconds. A new message replaces the one on screen.
///
/// `AppToast.of(context)` captures the overlay right away, so (like a captured
/// `ScaffoldMessengerState`) it can still be used after an async gap.
class AppToast {
  const AppToast._(this._overlay);

  final OverlayState? _overlay;

  /// Key of the toast's visible card (for tests).
  static const Key toastKey = ValueKey<String>('app_toast');

  static OverlayEntry? _entry;

  static AppToast of(BuildContext context) =>
      AppToast._(Overlay.maybeOf(context, rootOverlay: true));

  static AppToast? maybeOf(BuildContext context) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    return overlay == null ? null : AppToast._(overlay);
  }

  /// Shows [message]. [error] tints the card with the theme's error colour.
  void show(
    String message, {
    IconData? icon,
    Color? iconColor,
    Widget? leading,
    bool error = false,
    Duration? duration,
  }) {
    final OverlayState? overlay = _overlay;
    if (overlay == null || !overlay.mounted) return;
    dismiss();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (BuildContext context) => _AppToastView(
            message: message,
            icon: icon,
            iconColor: iconColor,
            leading: leading,
            error: error,
            duration: duration ?? readingTime(message),
            onDone: () {
              if (identical(_entry, entry)) {
                dismiss();
              } else if (entry.mounted) {
                entry.remove();
              }
            },
          ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Hides the toast on screen, if any.
  void hide() => dismiss();

  /// Hides the toast on screen, if any.
  static void dismiss() {
    final OverlayEntry? entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  /// About two seconds; a little longer for long messages (max four).
  static Duration readingTime(String message) => Duration(
    milliseconds: (1200 + message.length * 30).clamp(2000, 4000).toInt(),
  );
}

/// Shorthand for `AppToast.of(context).show(message)`.
void showAppToast(
  BuildContext context,
  String message, {
  IconData? icon,
  Color? iconColor,
  bool error = false,
}) => AppToast.of(
  context,
).show(message, icon: icon, iconColor: iconColor, error: error);

class _AppToastView extends StatefulWidget {
  const _AppToastView({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.leading,
    required this.error,
    required this.duration,
    required this.onDone,
  });

  final String message;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final bool error;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_AppToastView> createState() => _AppToastViewState();
}

class _AppToastViewState extends State<_AppToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (!mounted) return;
    await _fade.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color background =
        widget.error ? scheme.errorContainer : scheme.inverseSurface;
    final Color foreground =
        widget.error ? scheme.onErrorContainer : scheme.onInverseSurface;
    final EdgeInsets insets = MediaQuery.viewPaddingOf(context);
    final Widget? leading =
        widget.leading ??
        (widget.icon == null
            ? null
            : Icon(
              widget.icon,
              size: 20,
              color: widget.iconColor ?? foreground,
            ));
    return Positioned(
      top: insets.top + 12,
      left: insets.left + 16,
      right: insets.right + 16,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                key: AppToast.toastKey,
                color: background,
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (leading != null) ...<Widget>[
                        leading,
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          widget.message,
                          textAlign:
                              leading == null
                                  ? TextAlign.center
                                  : TextAlign.start,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
