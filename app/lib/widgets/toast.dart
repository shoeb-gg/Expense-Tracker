import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

OverlayEntry? _current;
Timer? _timer;

/// Shows a short message near the bottom ("Moved to Business", "214
/// expenses added") with an optional Undo. One toast at a time: a new one
/// replaces the old. It sits [bottom] px above the system inset (default 88:
/// just above the bottom bar) and goes away after [duration] (4 s, or 6 s
/// with Undo).
///
/// Not in the mockup; designed to match it: `tile` card, radius 16, 14/20
/// w600 white text, "Undo" in accent w800, the pop-up shadow.
void showToast(
  BuildContext context,
  String message, {
  VoidCallback? onUndo,
  Duration? duration,
  double bottom = 88,
}) {
  hideToast();
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ToastView(
      message: message,
      bottom: bottom,
      onUndo: onUndo == null
          ? null
          : () {
              hideToast();
              onUndo();
            },
    ),
  );
  _current = entry;
  overlay.insert(entry);
  _timer = Timer(
    duration ?? Duration(seconds: onUndo == null ? 4 : 6),
    hideToast,
  );
}

/// Removes the toast on screen, if any.
void hideToast() {
  _timer?.cancel();
  _timer = null;
  final entry = _current;
  _current = null;
  if (entry != null && entry.mounted) entry.remove();
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.bottom,
    required this.onUndo,
  });

  final String message;
  final double bottom;
  final VoidCallback? onUndo;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final curved = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);
    return Positioned(
      left: 16,
      right: 16,
      bottom: inset + widget.bottom,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
              .animate(curved),
          child: Semantics(
            liveRegion: true,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: EdgeInsets.only(
                  left: 16,
                  right: widget.onUndo == null ? 16 : 6,
                ),
                decoration: BoxDecoration(
                  color: c.tile,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [popupShadow],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          widget.message,
                          style: AppText.label.copyWith(color: c.text),
                        ),
                      ),
                    ),
                    if (widget.onUndo != null)
                      SizedBox(
                        height: 40,
                        child: Pressable(
                          onTap: widget.onUndo,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Center(
                              child: Text(
                                'Undo',
                                style: AppText.label.copyWith(
                                  color: c.accent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
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
    );
  }
}
