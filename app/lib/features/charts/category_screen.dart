import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../data/db.dart';
import '../../router.dart';
import '../../state/pocket_line.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'chart_data.dart';
import 'chart_model.dart';
import 'chart_parts.dart';
import 'column_chart.dart';

/// Category drill-down (`/category/:id?from=&to=&pocket=`, opened from
/// "Details" on Charts and from "See all" on an expense). [from] and [to] are
/// inclusive day numbers (null: this month). [pocketId] is the pocket whose
/// expenses it shows (null: the pocket in use); an expense's own pocket may
/// not be the one in use. Summary (total, average, entries), a column chart
/// in the category's own colour and its expenses by amount or by date. The
/// month pill opens the month pop-up.
class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({
    super.key,
    required this.categoryId,
    this.from,
    this.to,
    this.pocketId,
  });

  final int categoryId;
  final int? from;
  final int? to;
  final int? pocketId;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

/// What kind of range the drill-down shows (decides columns and labels).
enum _RangeKind { week, month, year, other }

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  ({int from, int to})? _picked;
  bool _byDate = false;
  int? _pinned;

  ({int from, int to}) _range(int today) {
    final picked = _picked;
    if (picked != null) return picked;
    final from = widget.from;
    final to = widget.to;
    if (from != null && to != null && to >= from) return (from: from, to: to);
    return (from: monthStartOfDay(today), to: monthEndOfDay(today));
  }

  Future<void> _pickMonth(int from) async {
    final ym = await showMonthPicker(
      context,
      year: yearOfDay(from),
      month: monthOfDay(from),
    );
    if (ym == null || !mounted) return;
    setState(() {
      _picked = (from: monthStart(ym.$1, ym.$2), to: monthEnd(ym.$1, ym.$2));
      _pinned = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = ref.watch(todayProvider);
    final first = ref.watch(settingsProvider.select((s) => s.firstDayOfWeek));
    final currentPocketId = ref.watch(currentPocketIdProvider);
    final pocketId = widget.pocketId ?? currentPocketId;
    final categories = ref.watch(categoriesProvider).value;
    final category = categories
        ?.where((e) => e.id == widget.categoryId)
        .firstOrNull;

    if (categories != null && category == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SubHeader(title: 'Category'),
              Expanded(
                child: NotFoundCard(
                  thing: 'Category',
                  icon: Symbols.category_rounded,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (category == null || pocketId == null) {
      return Scaffold(backgroundColor: c.bg);
    }

    // The pocket shown (an expense's own one may not be the pocket in use),
    // under the name once there are two or more pockets.
    final pockets = ref.watch(pocketsProvider).value ?? const <Pocket>[];
    final shown = pockets.where((p) => p.id == pocketId).firstOrNull;
    final pocketLine = pocketLabel(pocketWhenSeveral(pockets, shown));

    final range = _range(today);
    final y = yearOfDay(range.from);
    final _RangeKind kind;
    if (range.from == yearStart(y) && range.to == yearEnd(y)) {
      kind = _RangeKind.year;
    } else if (range.from == monthStartOfDay(range.from) &&
        range.to == monthEndOfDay(range.from)) {
      kind = _RangeKind.month;
    } else if (range.to - range.from == 6 &&
        range.from == weekStart(range.from, first)) {
      kind = _RangeKind.week;
    } else {
      kind = _RangeKind.other;
    }
    final pill = switch (kind) {
      _RangeKind.year => '$y',
      _RangeKind.month => shortMonthYear(y, monthOfDay(range.from)),
      _ => dayRangeLabel(range.from, range.to),
    };

    // The monthly average counts from the pocket's first month with data
    // (the same rule as Charts and Reports), so a year waits for it.
    final span = ref.watch(daySpanProvider(pocketId)).value;
    final lastPast = math.min(range.to, today);
    final expenses = lastPast < range.from
        ? const <Expense>[]
        : ref
            .watch(
              categoryExpensesProvider((
                pocketId: pocketId,
                categoryId: category.id,
                from: range.from,
                to: lastPast,
              )),
            )
            .value;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              category: category,
              pocketLine: pocketLine,
              pill: pill,
              onPill: () => unawaited(_pickMonth(range.from)),
            ),
            Expanded(
              child: expenses == null || span == null
                  ? const SizedBox.shrink()
                  : _Body(
                      category: category,
                      range: range,
                      firstDay: span.first,
                      byYear: kind == _RangeKind.year,
                      ticks: switch (kind) {
                        _RangeKind.week => DayTicks.weekdays,
                        _RangeKind.month => DayTicks.monthDays,
                        _ => DayTicks.range,
                      },
                      expenses: expenses,
                      byDate: _byDate,
                      pinned: _pinned,
                      onSort: (v) => setState(() => _byDate = v),
                      onPin: (i) => setState(() => _pinned = i),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The smallest the category name in the header is scaled to before it ends
/// in "...". "Online Subscriptions" at the largest text size needs 0.68 even
/// without the emoji tile, so 0.65 keeps every default name whole.
const double _minTitleScale = 0.65;

class _Header extends StatelessWidget {
  const _Header({
    required this.category,
    required this.pocketLine,
    required this.pill,
    required this.onPill,
  });

  final ExpenseCategory category;

  /// "👛 Personal" under the name, or '' for none (a single pocket).
  final String pocketLine;
  final String pill;
  final VoidCallback onPill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const BackRoundButton(),
            const SizedBox(width: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // The name scales down to fit (to _minTitleScale at the most). The
                  // tile goes first when the name would need less than that
                  // with it, and altogether when there is no room for it.
                  const tileRoom = 28 + 8;
                  final natural = titleWidth(context, category.name, AppText.screenTitle);
                  var tile = box.maxWidth >= 64;
                  if (tile && (box.maxWidth - tileRoom) / natural < _minTitleScale) {
                    tile = false;
                  }
                  final name = Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (tile) ...[
                        EmojiTile(
                          emoji: category.emoji,
                          size: 28,
                          radius: 9,
                          emojiSize: 15,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: FitTitle(
                          category.name,
                          style: AppText.screenTitle,
                          minScale: _minTitleScale,
                          // As it was: the text is its own width here.
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ],
                  );
                  if (pocketLine.isEmpty) return name;
                  // Like the pocket line of Calendar, Charts and Reports: one
                  // line that scales down rather than wrapping.
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      name,
                      FitTitle(
                        pocketLine,
                        style: AppText.overline.copyWith(color: c.text3),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Pressable(
              onTap: onPill,
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: edgeBorder(c),
              shadows: liftShadows(c),
              semanticLabel: 'Choose month, $pill',
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pill,
                        style: AppText.label.copyWith(
                          fontSize: 13,
                          height: 20 / 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Symbols.expand_more_rounded,
                        size: 18,
                        color: c.text3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.category,
    required this.range,
    required this.firstDay,
    required this.byYear,
    required this.ticks,
    required this.expenses,
    required this.byDate,
    required this.pinned,
    required this.onSort,
    required this.onPin,
  });

  final ExpenseCategory category;
  final ({int from, int to}) range;

  /// The pocket's first day with an expense (null: none).
  final int? firstDay;
  final bool byYear;
  final DayTicks ticks;

  /// Expenses of the category in the range so far, newest first.
  final List<Expense> expenses;
  final bool byDate;
  final int? pinned;
  final ValueChanged<bool> onSort;
  final ValueChanged<int?> onPin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final today = ref.watch(todayProvider);
    final index = SpendIndex([
      for (final e in expenses.reversed)
        (day: e.day, categoryId: e.categoryId, amount: e.amount),
    ]);
    final period = ChartPeriod(
      kind: byYear ? PeriodKind.year : PeriodKind.custom,
      from: range.from,
      to: range.to,
    );
    final total = index.sum(range.from, period.lastPast(today));
    final average = periodAverage(period, today, index, firstDay: firstDay);
    final points = byYear
        ? monthColumns(yearOfDay(range.from), today, index.sum)
        : dayColumns(range.from, range.to, today, ticks, index.dayTotal);
    final color = context.categoryColor(category.color);

    final sorted = [...expenses]..sort((p, q) {
        if (byDate) {
          if (p.day != q.day) return q.day - p.day;
          return q.createdAt.compareTo(p.createdAt);
        }
        if (p.amount != q.amount) return q.amount - p.amount;
        if (p.day != q.day) return p.day - q.day;
        return p.createdAt.compareTo(q.createdAt);
      });
    final maxAmount = expenses.fold<int>(1, (m, e) => math.max(m, e.amount));
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 2, 16, 24 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChartCard(
            child: _SummaryTable(
              label: 'Spent on ${category.name}',
              averageLabel: byYear ? 'Monthly average' : 'Daily average',
              total: fmt.format(total),
              average: average == null
                  ? '—'
                  : fmt.formatWhole(average.round()),
              averageIsNa: average == null,
              entries: fmt.count(expenses.length),
            ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            child: Column(
              children: [
                ChartHeading(
                  title: byYear ? 'Monthly spending' : 'Daily spending',
                  keyLine: total == 0
                      ? 'Nothing spent in this period.'
                      : average == null
                          ? 'No full month yet in ${yearOfDay(range.from)}'
                          : 'Dashed line = average '
                              '${fmt.formatWhole(average.round())}',
                ),
                const SizedBox(height: 12),
                ColumnChart(
                  points: points,
                  average: total == 0 ? 0 : (average ?? 0),
                  colors: ColumnColors(
                    hi: color,
                    soft: mix(color, c.surface, 0.8),
                    dim: mix(color, c.surface, 0.5),
                  ),
                  pinned: pinned,
                  onPin: onPin,
                  padTop: ColumnChart.categoryPadTop,
                  plotHeight: ColumnChart.categoryPlotHeight,
                  semanticLabel: 'Column chart of '
                      '${byYear ? 'monthly' : 'daily'} spending on '
                      '${category.name}',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CenteredNote(
                    total == 0
                        ? emptyColumnsHint(byMonth: byYear)
                        : byYear
                            ? 'Tap a column to see that month.'
                            : 'Tap a column to see that day.',
                    style: ChartText.hint(c),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CardClip(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: c.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 56,
                    color: c.surface2,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Expenses', style: AppText.cardTitle),
                        ),
                        const SizedBox(width: 12),
                        AppSegmented<bool>(
                          segments: const [
                            Segment<bool>(false, 'By amount'),
                            Segment<bool>(true, 'By date'),
                          ],
                          value: byDate,
                          onChanged: onSort,
                          size: SegmentedSize.compact,
                          segmentWidth: 84,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: sorted.isEmpty
                        ? const EmptyNote('Nothing spent in this period.')
                        : Column(
                            children: [
                              for (var i = 0; i < sorted.length; i++)
                                _ExpenseRow(
                                  expense: sorted[i],
                                  title: sorted[i].note.isEmpty
                                      ? category.name
                                      : sorted[i].note,
                                  amount: fmt.format(sorted[i].amount),
                                  share: shareText(sorted[i].amount, total, fmt),
                                  fraction: sorted[i].amount / maxAmount,
                                  color: color,
                                  divider: i < sorted.length - 1,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The summary card's table: "Spent on X", the average and the entries over
/// the total, the average and the entry count. The first column takes what
/// the other two leave; a long category name wraps there instead of being
/// cut off, and when even its longest word does not fit, the average's label
/// wraps ("Daily / average") to give the name room.
class _SummaryTable extends StatelessWidget {
  const _SummaryTable({
    required this.label,
    required this.averageLabel,
    required this.total,
    required this.average,
    required this.averageIsNa,
    required this.entries,
  });

  final String label;
  final String averageLabel;
  final String total;
  final String average;

  /// The average is "—" (not available).
  final bool averageIsNa;
  final String entries;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scaler = MediaQuery.textScalerOf(context);
    final labelStyle = ChartText.label(c);
    double width(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    return LayoutBuilder(
      builder: (context, box) {
        // The other two columns are as wide as their label or value, plus a
        // 16 px gap; the first has the rest.
        double column(String head, String value) =>
            16 + math.max(width(head, labelStyle), width(value, ChartText.stat));
        final room = box.maxWidth -
            column(averageLabel, average) -
            column('Entries', entries);
        final widest = label
            .split(' ')
            .fold<double>(0, (m, word) => math.max(m, width(word, labelStyle)));
        final head = widest > room
            ? averageLabel.replaceFirst(' ', '\n')
            : averageLabel;
        return Table(
          columnWidths: const {
            0: FlexColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TableRow(
              children: [
                Text(label, style: labelStyle),
                _cell(Text(head, textAlign: TextAlign.right, style: labelStyle)),
                _cell(
                  Text('Entries', textAlign: TextAlign.right, style: labelStyle),
                ),
              ],
            ),
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    total,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ChartText.total,
                  ),
                ),
                _cell(
                  Text(
                    average,
                    textAlign: TextAlign.right,
                    style: averageIsNa
                        ? ChartText.stat.copyWith(color: c.text3)
                        : ChartText.stat,
                  ),
                  top: 2,
                ),
                _cell(
                  Text(entries, textAlign: TextAlign.right, style: ChartText.stat),
                  top: 2,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _cell(Widget child, {double top = 0}) => Padding(
        padding: EdgeInsets.only(left: 16, top: top),
        child: child,
      );
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.title,
    required this.amount,
    required this.share,
    required this.fraction,
    required this.color,
    required this.divider,
  });

  final Expense expense;
  final String title;
  final String amount;
  final String share;
  final double fraction;
  final Color color;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => unawaited(context.push(Routes.expense(expense.id))),
      semanticLabel: '$title, ${mediumDate(expense.day)}, $amount',
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.tile,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${dayOfMonth(expense.day)}',
                    style: AppText.tabular(
                      AppText.dayTitle.copyWith(
                        fontSize: 16,
                        height: 18 / 16,
                      ),
                    ),
                  ),
                  Text(
                    weekdayShortName(expense.day),
                    style: AppText.caption.copyWith(
                      fontSize: 10.5,
                      height: 13 / 10.5,
                      fontWeight: FontWeight.w600,
                      color: c.text3,
                    ),
                  ),
                ],
              ),
            ),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.rowTitle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(amount, style: AppText.rowAmount),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      // 16 px; larger with larger text, so the share is
                      // not cut off.
                      height: MediaQuery.textScalerOf(context).scale(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ShareBar(fraction: fraction, color: color),
                          ),
                          const SizedBox(width: 8),
                          // At least 44 px; "100.0%" widens it and the
                          // bar gives way, so the right edge never moves.
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 44),
                            child: Text(
                              share,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              softWrap: false,
                              style: ChartText.share(c),
                            ),
                          ),
                        ],
                      ),
                    ),
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
