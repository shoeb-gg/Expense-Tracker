/// The date pop-up (PopDate) and the month pop-up (PopMonth / PopYear).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/days.dart';
import '../core/format.dart';
import '../state/providers.dart';
import '../theme/symbols.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'buttons.dart';
import 'dialogs.dart';
import 'now_pill.dart';
import 'pressable.dart';
import 'swipe.dart';

/// Opens the date pop-up on [initialDay] and returns the confirmed day, or
/// null on Cancel. Six-week grid with faint neighbouring days (tappable),
/// the chosen day filled, today as an accent number with a dot, weeks
/// starting on the day set in Settings. Tapping the month name shows the
/// twelve months (and from there twelve years) in the same pop-up.
/// Swipes and arrows change the month, without limit. A "Today" pill hangs
/// over the card's top edge while the chosen day or the page shown is not
/// today's; it shows today's month and chooses today.
Future<int?> showDayPicker(
  BuildContext context, {
  required int initialDay,
  String label = 'Date of this expense',
}) {
  return showAppPopup<int>(
    context,
    builder: (_) => DayPickerDialog(initialDay: initialDay, label: label),
  );
}

/// Opens the month pop-up ("Month to show") and returns the confirmed
/// (year, month) (month 1-12), or null on Cancel. Tapping the year swaps the
/// twelve months for twelve years; swipes and arrows step one year (twelve
/// in the year view), without limit. A "This month" pill hangs over the
/// card's top edge while the chosen month or the page shown is not the
/// current one; it shows this year and chooses this month.
Future<(int year, int month)?> showMonthPicker(
  BuildContext context, {
  required int year,
  required int month,
  String label = 'Month to show',
}) {
  return showAppPopup<(int, int)>(
    context,
    builder: (_) => MonthPickerDialog(year: year, month: month, label: label),
  );
}

enum _View { days, months, years }

/// First year of the twelve-year page that holds [year] (pages are aligned
/// so 2026 sits on the page 2018 - 2029, like the mockup).
int yearPageStart(int year) => year - ((year - 2018) % 12 + 12) % 12;

/// The date pop-up. Use [showDayPicker].
class DayPickerDialog extends ConsumerStatefulWidget {
  const DayPickerDialog({
    super.key,
    required this.initialDay,
    this.label = 'Date of this expense',
  });

  final int initialDay;
  final String label;

  @override
  ConsumerState<DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends ConsumerState<DayPickerDialog> {
  late int _selected = widget.initialDay;
  late int _year = yearOfDay(widget.initialDay);
  late int _month = monthOfDay(widget.initialDay);
  late int _page = yearPageStart(_year);
  _View _view = _View.days;
  bool _forward = true;
  Axis _axis = Axis.horizontal;

  void _step(bool next, Axis axis) {
    setState(() {
      _forward = next;
      _axis = axis;
      switch (_view) {
        case _View.days:
          final ym = addMonths(_year, _month, next ? 1 : -1);
          _year = ym.year;
          _month = ym.month;
        case _View.months:
          _year += next ? 1 : -1;
        case _View.years:
          _page += next ? 12 : -12;
      }
    });
  }

  /// Shows today's month and chooses today (the "Today" pill).
  void _goToday(int today) {
    final now = yearMonthOfDay(today);
    setState(() {
      _forward = now.year * 12 + now.month > _year * 12 + _month;
      _axis = Axis.horizontal;
      _selected = today;
      _year = now.year;
      _month = now.month;
      _page = yearPageStart(now.year);
      _view = _View.days;
    });
  }

  void _toggle() {
    setState(() {
      switch (_view) {
        case _View.days:
          _view = _View.months;
        case _View.months:
          _page = yearPageStart(_year);
          _view = _View.years;
        case _View.years:
          _view = _View.months;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final first = ref.watch(settingsProvider.select((s) => s.firstDayOfWeek));
    final (
      String navLabel,
      IconData caret,
      String toggleHint,
    ) = switch (_view) {
      _View.days => (
        monthYear(_year, _month),
        Symbols.expand_more_rounded,
        'Choose month and year',
      ),
      _View.months => ('$_year', Symbols.expand_more_rounded, 'Choose year'),
      _View.years => (
        '$_page – ${_page + 11}',
        Symbols.expand_less_rounded,
        'Back to months',
      ),
    };
    final (String prevHint, String nextHint) = switch (_view) {
      _View.days => ('Previous month', 'Next month'),
      _View.months => ('Previous year', 'Next year'),
      _View.years => ('Earlier years', 'Later years'),
    };

    Widget body;
    switch (_view) {
      case _View.days:
        body = Column(
          key: const ValueKey('days'),
          children: [
            const SizedBox(height: 8),
            _WeekdayRow(first: first),
            const SizedBox(height: 4),
            SlideSwitcher(
              pageKey: _year * 12 + _month,
              forward: _forward,
              axis: _axis,
              child: _DayGrid(
                year: _year,
                month: _month,
                first: first,
                selected: _selected,
                today: today,
                onPick: (day) => setState(() {
                  _selected = day;
                  final ym = yearMonthOfDay(day);
                  if (ym.year != _year || ym.month != _month) {
                    _forward = day > monthStart(_year, _month);
                    _axis = Axis.horizontal;
                    _year = ym.year;
                    _month = ym.month;
                  }
                }),
              ),
            ),
          ],
        );
      case _View.months:
        body = Padding(
          key: const ValueKey('months'),
          padding: const EdgeInsets.only(top: 12),
          child: SlideSwitcher(
            pageKey: _year,
            forward: _forward,
            axis: _axis,
            child: _MonthTiles(
              year: _year,
              selectedYear: yearOfDay(_selected),
              selectedMonth: monthOfDay(_selected),
              today: today,
              onPick: (m) => setState(() {
                _month = m;
                _view = _View.days;
              }),
            ),
          ),
        );
      case _View.years:
        body = Padding(
          key: const ValueKey('years'),
          padding: const EdgeInsets.only(top: 12),
          child: SlideSwitcher(
            pageKey: _page,
            forward: _forward,
            axis: _axis,
            child: _YearTiles(
              page: _page,
              selectedYear: _year,
              today: today,
              onPick: (y) => setState(() {
                _year = y;
                _view = _View.months;
              }),
            ),
          ),
        );
    }

    final now = yearMonthOfDay(today);
    final moved =
        _selected != today ||
        switch (_view) {
          _View.days => _year != now.year || _month != now.month,
          _View.months => _year != now.year,
          _View.years => _page != yearPageStart(now.year),
        };

    return NowPillOverCard(
      pill: NowPill(
        visible: moved,
        label: 'Today',
        semanticLabel: 'Back to today',
        onTap: () => _goToday(today),
      ),
      child: AppPopupCard(
        semanticLabel: widget.label,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: SwipeArea(
          onSwipe: (e) => _step(e.next, e.axis),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Heading(label: widget.label, heading: weekdayDate(_selected)),
              const SizedBox(height: 16),
              _NavRow(
                label: navLabel,
                tabular: _view != _View.days,
                caret: caret,
                toggleHint: toggleHint,
                prevHint: prevHint,
                nextHint: nextHint,
                onToggle: _toggle,
                onPrev: () => _step(false, Axis.horizontal),
                onNext: () => _step(true, Axis.horizontal),
              ),
              SizedBox(
                height: 272,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  child: body,
                ),
              ),
              const SizedBox(height: 12),
              PopupButtons(
                onCancel: () => Navigator.of(context).pop(),
                onAction: () => Navigator.of(context).pop(_selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The month pop-up. Use [showMonthPicker].
class MonthPickerDialog extends ConsumerStatefulWidget {
  const MonthPickerDialog({
    super.key,
    required this.year,
    required this.month,
    this.label = 'Month to show',
  });

  final int year;

  /// 1-12.
  final int month;
  final String label;

  @override
  ConsumerState<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends ConsumerState<MonthPickerDialog> {
  late int _selYear = widget.year;
  late int _selMonth = widget.month;
  late int _year = widget.year;
  late int _page = yearPageStart(widget.year);
  bool _years = false;
  bool _forward = true;
  Axis _axis = Axis.horizontal;

  void _step(bool next, Axis axis) {
    setState(() {
      _forward = next;
      _axis = axis;
      if (_years) {
        _page += next ? 12 : -12;
      } else {
        _year += next ? 1 : -1;
      }
    });
  }

  /// Shows this year and chooses this month (the "This month" pill).
  void _goNow(int today) {
    final now = yearMonthOfDay(today);
    setState(() {
      _forward = _years ? yearPageStart(now.year) > _page : now.year > _year;
      _axis = Axis.horizontal;
      _selYear = now.year;
      _selMonth = now.month;
      _year = now.year;
      _page = yearPageStart(now.year);
      _years = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final now = yearMonthOfDay(today);
    final moved =
        _selYear != now.year ||
        _selMonth != now.month ||
        (_years ? _page != yearPageStart(now.year) : _year != now.year);
    final grid = _years
        ? SlideSwitcher(
            key: const ValueKey('years'),
            pageKey: _page,
            forward: _forward,
            axis: _axis,
            child: _YearTiles(
              page: _page,
              selectedYear: _year,
              today: today,
              onPick: (y) => setState(() {
                _year = y;
                _years = false;
              }),
            ),
          )
        : SlideSwitcher(
            key: const ValueKey('months'),
            pageKey: _year,
            forward: _forward,
            axis: _axis,
            child: _MonthTiles(
              year: _year,
              selectedYear: _selYear,
              selectedMonth: _selMonth,
              today: today,
              onPick: (m) => setState(() {
                _selYear = _year;
                _selMonth = m;
              }),
            ),
          );
    return NowPillOverCard(
      pill: NowPill(
        visible: moved,
        label: 'This month',
        semanticLabel: 'Back to this month',
        onTap: () => _goNow(today),
      ),
      child: AppPopupCard(
        semanticLabel: widget.label,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: SwipeArea(
          onSwipe: (e) => _step(e.next, e.axis),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Heading(
                label: widget.label,
                heading: monthYear(_selYear, _selMonth),
              ),
              const SizedBox(height: 16),
              _NavRow(
                label: _years ? '$_page – ${_page + 11}' : '$_year',
                caret: _years
                    ? Symbols.expand_less_rounded
                    : Symbols.expand_more_rounded,
                toggleHint: _years ? 'Back to months' : 'Choose year',
                prevHint: _years ? 'Earlier years' : 'Previous year',
                nextHint: _years ? 'Later years' : 'Next year',
                onToggle: () => setState(() {
                  if (!_years) _page = yearPageStart(_year);
                  _years = !_years;
                }),
                onPrev: () => _step(false, Axis.horizontal),
                onNext: () => _step(true, Axis.horizontal),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 192,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: grid,
                ),
              ),
              const SizedBox(height: 24),
              PopupButtons(
                onCancel: () => Navigator.of(context).pop(),
                onAction: () =>
                    Navigator.of(context).pop((_selYear, _selMonth)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ parts

class _Heading extends StatelessWidget {
  const _Heading({required this.label, required this.heading});

  final String label;
  final String heading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppText.overline.copyWith(color: c.text3),
        ),
        const SizedBox(height: 2),
        Semantics(
          liveRegion: true,
          child: Text(
            heading,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: AppText.popHeading.copyWith(color: c.text),
          ),
        ),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.caret,
    required this.toggleHint,
    required this.prevHint,
    required this.nextHint,
    required this.onToggle,
    required this.onPrev,
    required this.onNext,
    this.tabular = true,
  });

  final String label;

  /// Tabular figures (the years of PopMonth); the date pop-up's month name
  /// ("October 2026") is drawn with proportional figures like its board.
  final bool tabular;
  final IconData caret;
  final String toggleHint;
  final String prevHint;
  final String nextHint;
  final VoidCallback onToggle;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The board's `justify-content: space-between`: the label keeps the
    // width it needs (up to all the room left of the arrows) and the arrows
    // always end at the right content edge.
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Semantics(
              button: true,
              label: toggleHint,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!SwipeArea.swipedRecently(context)) onToggle();
                },
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: tabular
                              ? AppText.tabular(
                                  AppText.cardTitle.copyWith(color: c.text),
                                )
                              : AppText.cardTitle.copyWith(color: c.text),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(caret, size: 20, color: c.accent),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Arrow(
                  icon: Symbols.chevron_left_rounded,
                  hint: prevHint,
                  onTap: onPrev,
                ),
                _Arrow(
                  icon: Symbols.chevron_right_rounded,
                  hint: nextHint,
                  onTap: onNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.hint, required this.onTap});

  final IconData icon;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: hint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!SwipeArea.swipedRecently(context)) onTap();
        },
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: c.tile, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: c.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.first});

  final FirstDayOfWeek first;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final wd in weekdayOrder(first))
            SizedBox(
              width: 40,
              height: 20,
              child: Text(
                weekdayInitials[wd - 1],
                textAlign: TextAlign.center,
                style: AppText.weekdayLetter.copyWith(color: c.text3),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.year,
    required this.month,
    required this.first,
    required this.selected,
    required this.today,
    required this.onPick,
  });

  final int year;
  final int month;
  final FirstDayOfWeek first;
  final int selected;
  final int today;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final days = sixWeekGrid(year, month, first);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var w = 0; w < 6; w++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 7; i++)
                _DayCell(
                  day: days[w * 7 + i],
                  inMonth: monthOfDay(days[w * 7 + i]) == month,
                  selected: days[w * 7 + i] == selected,
                  isToday: days[w * 7 + i] == today,
                  onPick: onPick,
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.isToday,
    required this.onPick,
  });

  final int day;
  final bool inMonth;
  final bool selected;
  final bool isToday;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = dateOfDay(day);
    final fg = selected
        ? c.onAccent
        : isToday
        ? c.accent
        : inMonth
        ? c.text
        : c.popDim;
    final bold = selected || isToday;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${weekdayName(day)}, ${monthName(d.month)} ${d.day}'
          '${isToday ? ', today' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!SwipeArea.swipedRecently(context)) onPick(day);
        },
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? c.accent : c.accent.withValues(alpha: 0),
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Text(
                      '${d.day}',
                      textAlign: TextAlign.center,
                      style: AppText.pickerDay.copyWith(
                        color: fg,
                        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isToday)
                    Positioned(
                      left: 16,
                      bottom: 3,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: selected ? c.onAccent : c.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 12 tiles in 4 columns (gap 12, 56 px rows, radius 16).
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<_TileData> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < 3; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _Tile(data: tiles[r * 4 + i])),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _TileData {
  const _TileData({
    required this.label,
    required this.selected,
    required this.isNow,
    required this.onTap,
    required this.semanticLabel,
  });

  final String label;
  final bool selected;
  final bool isNow;
  final VoidCallback onTap;
  final String semanticLabel;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.data});

  final _TileData data;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = data.selected
        ? c.onAccent
        : data.isNow
        ? c.accent
        : c.text;
    return SizedBox(
      height: 56,
      child: Pressable(
        onTap: () {
          if (!SwipeArea.swipedRecently(context)) data.onTap();
        },
        selected: data.selected,
        semanticLabel: data.semanticLabel,
        color: data.selected ? c.accent : c.tile,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            data.label,
            style: AppText.pickerTile.copyWith(
              color: fg,
              fontWeight: data.selected || data.isNow
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthTiles extends StatelessWidget {
  const _MonthTiles({
    required this.year,
    required this.selectedYear,
    required this.selectedMonth,
    required this.today,
    required this.onPick,
  });

  final int year;
  final int selectedYear;
  final int selectedMonth;
  final int today;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final now = yearMonthOfDay(today);
    return _TileGrid(
      tiles: [
        for (var m = 1; m <= 12; m++)
          _TileData(
            label: monthShortName(m),
            semanticLabel: monthYear(year, m),
            selected: year == selectedYear && m == selectedMonth,
            isNow: year == now.year && m == now.month,
            onTap: () => onPick(m),
          ),
      ],
    );
  }
}

class _YearTiles extends StatelessWidget {
  const _YearTiles({
    required this.page,
    required this.selectedYear,
    required this.today,
    required this.onPick,
  });

  final int page;
  final int selectedYear;
  final int today;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final nowYear = yearOfDay(today);
    return _TileGrid(
      tiles: [
        for (var y = page; y < page + 12; y++)
          _TileData(
            label: '$y',
            semanticLabel: '$y',
            selected: y == selectedYear,
            isNow: y == nowYear,
            onTap: () => onPick(y),
          ),
      ],
    );
  }
}
