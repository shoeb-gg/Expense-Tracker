import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../data/db.dart';
import '../../router.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import '../charts/chart_data.dart';
import 'calendar_data.dart';

/// The tallest a week of the month grid is (it is this high unless the
/// screen is short).
const double _weekMax = 64;

/// The shortest a week gets: the day number (4 px above, 26 px) and the
/// amount strip (22 px), with nothing left over.
const double _weekMin = 52;

/// Space between two weeks.
const double _weekGap = 4;

/// Space above the weekday names, and between them and the grid.
const double _weekdaysTop = 16;
const double _weekdaysGap = 8;

/// The room the part that scrolls keeps under the grid: its 12 px of
/// padding, the legend (16) and the gap under it (16), the day card's header
/// (60) and two expense rows (2 x 68, with 4 px of padding above them).
const double _dayCardRoom = 12 + 16 + 16 + 60 + 4 + 2 * 68;

/// Calendar (`/calendar?day=`): opens on the month of [day] (today when
/// null) with that day chosen. A turquoise bar with the month and its total
/// and arrows, a month grid whose cells get brighter with spending, and the
/// chosen day's card with its expenses and "Add expense on Oct 18". Swiping
/// the grid changes the month: finger left to right or top to bottom shows
/// the previous month, right to left or bottom to top the next one. Arrows,
/// swipes and the month pop-up have no limit, back or forward. The weeks of
/// the grid are 64 px high; on a short screen (a six-week month, large text)
/// they shrink, down to 52 px, so the day card keeps room for its header and
/// two expenses.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.day});

  final int? day;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late YearMonth _ym;
  late int _sel;
  bool _forward = true;
  Axis _axis = Axis.horizontal;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    final day = widget.day ?? today;
    _ym = yearMonthOfDay(day);
    _sel = day;
  }

  void _go(YearMonth ym, {required bool forward, required Axis axis, int? day}) {
    final today = ref.read(todayProvider);
    setState(() {
      _forward = forward;
      _axis = axis;
      _ym = ym;
      _sel = day ?? defaultDay(ym.year, ym.month, today);
    });
  }

  void _step(bool next, Axis axis) {
    _go(
      addMonths(_ym.year, _ym.month, next ? 1 : -1),
      forward: next,
      axis: axis,
    );
  }

  Future<void> _pickMonth() async {
    final ym = await showMonthPicker(context, year: _ym.year, month: _ym.month);
    if (ym == null || !mounted) return;
    final key = monthKey(ym.$1, ym.$2);
    final cur = monthKey(_ym.year, _ym.month);
    if (key == cur) return;
    _go(
      (year: ym.$1, month: ym.$2),
      forward: key > cur,
      axis: Axis.horizontal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final today = ref.watch(todayProvider);
    final settings = ref.watch(settingsProvider);
    final pocketId = ref.watch(currentPocketIdProvider);
    final index = pocketId == null
        ? null
        : ref.watch(spendIndexProvider(pocketId)).value;
    final now = yearMonthOfDay(today);
    final latest = monthKey(now.year, now.month);
    final key = monthKey(_ym.year, _ym.month);
    final first = monthStart(_ym.year, _ym.month);
    final lastPast = math.min(monthEnd(_ym.year, _ym.month), today);
    final monthTotal = index?.sum(first, lastPast) ?? 0;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                const SubHeader(title: 'Calendar'),
                // At the right of the header, where the title leaves room:
                // shown once the month is not this one or today is not the
                // chosen day.
                Positioned(
                  top: (60 - NowPill.height) / 2,
                  right: 16,
                  child: NowPill(
                    visible: key != latest || _sel != today,
                    label: 'Today',
                    semanticLabel: 'Back to today',
                    onTap: () => _go(
                      now,
                      forward: latest > key,
                      axis: Axis.horizontal,
                      day: today,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MonthBar(
                label: monthYear(_ym.year, _ym.month),
                total: '${fmt.format(monthTotal)} spent',
                onPrev: () => _step(false, Axis.horizontal),
                onNext: () => _step(true, Axis.horizontal),
                onLabel: () => unawaited(_pickMonth()),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // What the grid may take of the room under the month bar:
                  // all but the weekday names and what the day card needs.
                  final room = box.maxHeight -
                      _weekdaysTop -
                      _textHeight(context, AppText.caption) -
                      _weekdaysGap -
                      _dayCardRoom -
                      bottom;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The weekdays and the grid stay in place: a vertical
                      // swipe on the grid changes the month, so the page
                      // must not scroll from there. Only what is below them
                      // scrolls.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, _weekdaysTop, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _WeekdayRow(first: settings.firstDayOfWeek),
                            const SizedBox(height: _weekdaysGap),
                            SwipeArea(
                              onSwipe: (e) => _step(e.next, e.axis),
                              child: SlideSwitcher(
                                pageKey: key,
                                forward: _forward,
                                axis: _axis,
                                child: _MonthGrid(
                                  key: ValueKey(key),
                                  ym: _ym,
                                  index: index,
                                  selected: _sel,
                                  room: room,
                                  onPick: (d) => setState(() => _sel = d),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottom),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Legend(
                                // "K = thousand" only when a cell of this month uses K.
                                amounts: settings.calendarAmounts &&
                                    (index?.dayTotals(first, lastPast).values.any(
                                              (v) => fmt.short(v).endsWith('K'),
                                            ) ??
                                        false),
                              ),
                              const SizedBox(height: 16),
                              if (pocketId != null)
                                _DayCard(
                                  pocketId: pocketId,
                                  day: _sel,
                                  total: index?.dayTotal(_sel) ?? 0,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The height of one line of [style] at the current text size.
double _textHeight(BuildContext context, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: 'Sun', style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.label,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onLabel,
  });

  final String label;
  final String total;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _Arrow(
            icon: Symbols.chevron_left_rounded,
            label: 'Previous month',
            onTap: onPrev,
          ),
          Expanded(
            child: Semantics(
              button: true,
              liveRegion: true,
              label: 'Choose month, $label',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onLabel,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      style: AppText.dayTitle.copyWith(
                        fontSize: 16,
                        height: 20 / 16,
                        letterSpacing: -0.2,
                        color: c.onAccent,
                      ),
                    ),
                    Text(
                      total,
                      maxLines: 1,
                      style: AppText.overline.copyWith(color: c.onAccentDim),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _Arrow(
            icon: Symbols.chevron_right_rounded,
            label: 'Next month',
            onTap: onNext,
          ),
        ],
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
    return Pressable(
      onTap: onTap,
      color: c.onAccent,
      borderRadius: BorderRadius.circular(20),
      semanticLabel: label,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: 24, color: c.accent),
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
    final order = weekdayOrder(first);
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Text(
                weekdayShortNames[order[i] - 1],
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.text3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({
    super.key,
    required this.ym,
    required this.index,
    required this.selected,
    required this.room,
    required this.onPick,
  });

  final YearMonth ym;
  final SpendIndex? index;
  final int selected;

  /// The height the grid may take. A week is 64 px high when the weeks fit
  /// in it, else they share it (never less than 52 px each).
  final double room;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final settings = ref.watch(settingsProvider);
    final cells = monthCells(ym.year, ym.month, settings.firstDayOfWeek);
    final first = monthStart(ym.year, ym.month);
    final lastPast = math.min(monthEnd(ym.year, ym.month), today);
    final totals = index?.dayTotals(first, lastPast) ?? const <int, int>{};
    final steps = heatSteps(totals.values);
    final weeks = (cells.length / 7).ceil();
    final week = math.min(
      _weekMax,
      math.max(_weekMin, (room - _weekGap * (weeks - 1)) / weeks),
    );
    return Column(
      children: [
        for (var w = 0; w < weeks; w++) ...[
          if (w > 0) const SizedBox(height: _weekGap),
          SizedBox(
            height: week,
            child: Row(
              children: [
                for (var k = 0; k < 7; k++) ...[
                  if (k > 0) const SizedBox(width: 4),
                  Expanded(
                    child: () {
                      final i = w * 7 + k;
                      final day = i < cells.length ? cells[i] : null;
                      if (day == null) return const SizedBox.shrink();
                      final v = totals[day] ?? 0;
                      return _DayCell(
                        day: day,
                        value: v,
                        level: heatLevel(v, steps),
                        future: day > today,
                        today: day == today,
                        selected: day == selected,
                        showAmount: settings.calendarAmounts,
                        height: week,
                        onPick: onPick,
                      );
                    }(),
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

class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.day,
    required this.value,
    required this.level,
    required this.future,
    required this.today,
    required this.selected,
    required this.showAmount,
    required this.height,
    required this.onPick,
  });

  final int day;
  final int value;
  final int level;
  final bool future;
  final bool today;
  final bool selected;
  final bool showAmount;
  final double height;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final dark = level >= 3;
    final bg = future
        ? mix(c.surface, c.bg, 0.45)
        : level == 0
            ? c.surface
            : c.heat[level - 1];
    final fg = future
        ? c.dim
        : dark
            ? c.onAccent
            : c.text;
    final badgeBg = selected
        ? const Color(0xFFFFFFFF)
        : today
            ? (dark ? c.onAccent : c.accent)
            : const Color(0x00000000);
    final badgeFg = selected
        ? c.onAccent
        : today
            ? (dark ? c.accent : c.onAccent)
            : fg;
    final ringed = selected && today;
    final hasAmount = showAmount && !future && value > 0;

    final badge = Container(
      width: ringed ? 22 : 26,
      height: ringed ? 22 : 26,
      margin: EdgeInsets.all(ringed ? 2 : 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: badgeBg,
        shape: BoxShape.circle,
        boxShadow: ringed
            ? [
                BoxShadow(
                  color: dark ? c.heat[1] : c.accent,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: _FitWidth(
        child: Text(
          '${dayOfMonth(day)}',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: AppText.tabular(
            AppText.dayTitle.copyWith(color: badgeFg),
          ),
        ),
      ),
    );

    final label = '${longDate(day)}'
        '${value > 0 ? ', ${fmt.format(value)} spent' : ''}';

    return Builder(
      builder: (context) => Pressable(
        onTap: future
            ? null
            : () {
                if (SwipeArea.swipedRecently(context)) return;
                onPick(day);
              },
        color: bg,
        borderRadius: BorderRadius.circular(12),
        semanticLabel: label,
        selected: selected,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: height,
            child: Column(
              mainAxisAlignment: hasAmount
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 4), child: badge),
                if (hasAmount)
                  Container(
                    height: 22,
                    width: double.infinity,
                    color: c.onAccent.withAlpha(0x8C),
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: 20,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _FitWidth(
                          child: Text(
                            fmt.short(value),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: AppText.tabular(
                              AppText.body.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                                color: const Color(0xFFFFFFFF),
                              ),
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
    );
  }
}

/// Centres [child] and, when it is wider than the room it is given, scales
/// it down to that width. Only the width counts: a line of large text is
/// taller than the box it sits in, and that is fine, so the height never
/// shrinks the text.
class _FitWidth extends StatelessWidget {
  const _FitWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => OverflowBox(
        maxHeight: double.infinity,
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.amounts});

  final bool amounts;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppText.caption.copyWith(color: c.text3);
    return ExcludeSemantics(
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            Expanded(
              child: amounts
                  ? Text(
                      'K = thousand',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    )
                  : const SizedBox.shrink(),
            ),
            Text('Less', style: style),
            const SizedBox(width: 8),
            for (final color in [c.surface, ...c.heat]) ...[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 4),
            ],
            const SizedBox(width: 4),
            Text('More', style: style),
          ],
        ),
      ),
    );
  }
}

/// The chosen day's card: the same card as Home's day cards, with the
/// expenses of that day and "Add expense on Oct 18".
class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.pocketId,
    required this.day,
    required this.total,
  });

  final int pocketId;
  final int day;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final today = ref.watch(todayProvider);
    final cats = ref.watch(categoriesByIdProvider);
    final month = ref.watch(
      expensesInRangeProvider((
        pocketId: pocketId,
        from: monthStartOfDay(day),
        to: monthEndOfDay(day),
      )),
    );
    final rows = [
      for (final e in month.value ?? const <Expense>[])
        if (e.day == day) e,
    ];
    final isToday = day == today;
    final label = dayLabel(day, today);
    final sub = day == today || day == today - 1
        ? weekdayName(day)
        : longMonthDay(day, currentYear: yearOfDay(today));

    return Semantics(
      container: true,
      label: '${weekdayName(day)}, ${longMonthDay(day)}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: c.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 60,
                color: c.surface2,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday ? c.accent : c.accentSoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        '${dayOfMonth(day)}',
                        style: AppText.badgeNumber.copyWith(
                          color: isToday ? c.onAccent : c.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(0, -1),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.dayTitle,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.sub.copyWith(color: c.text3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Transform.translate(
                      offset: const Offset(0, -1),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fmt.format(total),
                            style: AppText.dayTotal.copyWith(color: c.accent),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Total',
                            style: AppText.sub.copyWith(color: c.text3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          month.value == null && total > 0
                              ? ''
                              : 'Nothing spent on this day.',
                          style: AppText.body.copyWith(color: c.text3),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < rows.length; i++)
                            _ExpenseRow(
                              expense: rows[i],
                              category: cats[rows[i].categoryId],
                              divider: i < rows.length - 1,
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Pressable(
                  onTap: () => unawaited(context.push(Routes.add(day: day))),
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(16),
                  semanticLabel: 'Add expense on ${monthDay(day)}',
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Symbols.add_rounded, size: 20, color: c.accent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Add expense on ${monthDay(day)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({
    required this.expense,
    required this.category,
    required this.divider,
  });

  final Expense expense;
  final ExpenseCategory? category;
  final bool divider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final name = category?.name ?? '';
    final time = timeOfDay(expense.createdAt);
    final title = expense.note.isEmpty ? name : expense.note;
    final sub = expense.note.isEmpty ? time : '$name · $time';
    return Pressable(
      onTap: () => unawaited(context.push(Routes.expense(expense.id))),
      semanticLabel: '$title, $sub, ${fmt.format(expense.amount)}',
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            const SizedBox(width: 16),
            EmojiTile(emoji: category?.emoji ?? ''),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 68,
                margin: const EdgeInsets.only(right: 16),
                decoration: divider
                    ? BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.line)),
                      )
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.rowTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.sub.copyWith(color: c.text3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(fmt.format(expense.amount), style: AppText.rowAmount),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
