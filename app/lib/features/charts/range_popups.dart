import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';

/// An inclusive day range.
typedef DayRange = ({int from, int to});

/// Opens the Custom range pop-up on [initial] and returns the confirmed
/// range, or null on Cancel.
Future<DayRange?> showCustomRange(
  BuildContext context, {
  required DayRange initial,
}) => showAppPopup<DayRange>(
  context,
  builder: (_) => CustomRangeDialog(initial: initial),
);

/// The Custom range pop-up (board "Charts: custom range"): quick choices of
/// 7, 30 and 90 days ending today, From above To (each opens the date
/// pop-up), a line saying how many days the charts will show, Cancel and
/// Confirm. Confirm is off while To is earlier than From.
class CustomRangeDialog extends ConsumerStatefulWidget {
  const CustomRangeDialog({super.key, required this.initial});

  final DayRange initial;

  @override
  ConsumerState<CustomRangeDialog> createState() => _CustomRangeDialogState();
}

class _CustomRangeDialogState extends ConsumerState<CustomRangeDialog> {
  late int _from = widget.initial.from;
  late int _to = widget.initial.to;

  static const List<int> _quick = [7, 30, 90];

  Future<void> _pick({required bool from}) async {
    final day = await showDayPicker(
      context,
      initialDay: from ? _from : _to,
      label: from ? 'Start of the range' : 'End of the range',
    );
    if (day == null || !mounted) return;
    setState(() => from ? _from = day : _to = day);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = ref.watch(todayProvider);
    final days = _to - _from + 1;
    final valid = _to >= _from;
    final sub = !valid
        ? "To can't be earlier than From."
        : days == 1
        ? 'Charts will show this 1 day.'
        : 'Charts will show these $days days.';
    int? quick;
    for (final n in _quick) {
      if (_to == today && _from == today - n + 1) quick = n;
    }

    return AppPopupCard(
      semanticLabel: 'Custom range',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Custom range', style: AppText.screenTitle),
          const SizedBox(height: 2),
          Semantics(
            liveRegion: true,
            child: Text(
              sub,
              style: AppText.tabular(AppText.body.copyWith(color: c.text2)),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Quick choices, ending today',
            child: AppSegmented<int?>(
              // On the white pop-up of the light theme the track is the page
              // colour (the dark pop-up keeps the card colour).
              trackColor: c.brightness == Brightness.light ? c.bg : null,
              segments: [for (final n in _quick) Segment<int?>(n, '$n days')],
              value: quick,
              tabular: true,
              onChanged: (n) {
                if (n == null) return;
                setState(() {
                  _from = today - n + 1;
                  _to = today;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          _RangeRow(
            label: 'From',
            value: dayOrToday(_from, today),
            semanticLabel: 'From ${mediumDate(_from)}. Tap to change',
            onTap: () => unawaited(_pick(from: true)),
          ),
          const SizedBox(height: 8),
          _RangeRow(
            label: 'To',
            value: dayOrToday(_to, today),
            semanticLabel: 'To ${mediumDate(_to)}. Tap to change',
            onTap: () => unawaited(_pick(from: false)),
          ),
          const SizedBox(height: 20),
          PopupButtons(
            onCancel: () => Navigator.of(context).pop(),
            onAction: valid
                ? () => Navigator.of(
                    context,
                  ).pop<DayRange>((from: _from, to: _to))
                : null,
          ),
        ],
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({
    required this.label,
    required this.value,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String value;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      color: c.tile,
      borderRadius: BorderRadius.circular(16),
      semanticLabel: semanticLabel,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
          child: Row(
            children: [
              Text(
                label,
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.text2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.tabular(
                    AppText.rowAmount.copyWith(color: c.text),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Symbols.calendar_month_rounded, size: 20, color: c.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the year pop-up (the month pop-up's year view on its own: "Year to
/// show", twelve years with arrows that step twelve, without limit) and
/// returns the confirmed year, or null on Cancel. A "This year" pill hangs
/// over the card's top edge while the chosen year or the page shown is not
/// the current one; it shows this year's page and chooses it.
Future<int?> showYearPicker(
  BuildContext context, {
  required int year,
  String label = 'Year to show',
}) => showAppPopup<int>(
  context,
  builder: (_) => YearPickerDialog(year: year, label: label),
);

/// The year pop-up (see [showYearPicker]).
class YearPickerDialog extends ConsumerStatefulWidget {
  const YearPickerDialog({super.key, required this.year, required this.label});

  final int year;
  final String label;

  @override
  ConsumerState<YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends ConsumerState<YearPickerDialog> {
  late int _year = widget.year;
  late int _page = yearPageStart(widget.year);
  bool _forward = true;

  void _step(bool next) => setState(() {
    _forward = next;
    _page += next ? 12 : -12;
  });

  /// Shows this year's page and chooses this year (the "This year" pill).
  void _goNow(int thisYear) => setState(() {
    _forward = yearPageStart(thisYear) > _page;
    _page = yearPageStart(thisYear);
    _year = thisYear;
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final thisYear = yearOfDay(ref.watch(todayProvider));
    final span = '$_page – ${_page + 11}';
    final moved = _year != thisYear || _page != yearPageStart(thisYear);
    return NowPillOverCard(
      pill: NowPill(
        visible: moved,
        label: 'This year',
        semanticLabel: 'Back to this year',
        onTap: () => _goNow(thisYear),
      ),
      child: AppPopupCard(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        semanticLabel: widget.label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: AppText.overline.copyWith(color: c.text3),
            ),
            const SizedBox(height: 2),
            Text(
              '$_year',
              textAlign: TextAlign.center,
              style: AppText.popHeading,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      span,
                      style: AppText.tabular(AppText.cardTitle),
                    ),
                  ),
                  _Arrow(
                    icon: Symbols.chevron_left_rounded,
                    label: 'Earlier years',
                    onTap: () => _step(false),
                  ),
                  _Arrow(
                    icon: Symbols.chevron_right_rounded,
                    label: 'Later years',
                    onTap: () => _step(true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwipeArea(
              onSwipe: (e) => _step(e.next),
              child: SizedBox(
                height: 192,
                child: SlideSwitcher(
                  pageKey: _page,
                  forward: _forward,
                  child: _YearGrid(
                    key: ValueKey(_page),
                    first: _page,
                    chosen: _year,
                    current: thisYear,
                    onPick: (y) {
                      if (SwipeArea.swipedRecently(context)) return;
                      setState(() => _year = y);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PopupButtons(
              onCancel: () => Navigator.of(context).pop(),
              onAction: () => Navigator.of(context).pop<int>(_year),
            ),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: Pressable(
          onTap: onTap,
          color: c.tile,
          borderRadius: BorderRadius.circular(18),
          semanticLabel: label,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 22, color: c.text),
          ),
        ),
      ),
    );
  }
}

class _YearGrid extends StatelessWidget {
  const _YearGrid({
    super.key,
    required this.first,
    required this.chosen,
    required this.current,
    required this.onPick,
  });

  final int first;
  final int chosen;
  final int current;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        for (var r = 0; r < 3; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var k = 0; k < 4; k++) ...[
                  if (k > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final y = first + r * 4 + k;
                        final on = y == chosen;
                        final now = y == current;
                        return Pressable(
                          onTap: () => onPick(y),
                          color: on ? c.accentFill : c.tile,
                          borderRadius: BorderRadius.circular(16),
                          selected: on,
                          semanticLabel: '$y',
                          child: Center(
                            child: Text(
                              '$y',
                              style: AppText.pickerTile.copyWith(
                                fontWeight: on || now
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: on
                                    ? c.onFill
                                    : now
                                    ? c.accent
                                    : c.text,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
