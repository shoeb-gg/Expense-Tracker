import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../data/db.dart';
import '../../state/providers.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import '../charts/chart_parts.dart' show EmptyNote;
import 'reports_logic.dart';
import 'year_chart.dart';

/// Text styles of this board that the shared set does not have.
abstract final class ReportText {
  static final TextStyle stat = AppText.rowTitle.copyWith(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w800,
  );
  static final TextStyle big = AppText.rowTitle.copyWith(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );
  static final TextStyle rowDelta = AppText.tabular(
    AppText.rowTitle.copyWith(
      fontSize: 13,
      height: 16 / 13,
      fontWeight: FontWeight.w700,
    ),
  );
}

Color trendColor(AppColors c, Trend t) => switch (t) {
  Trend.down => c.good,
  Trend.up => c.bad,
  Trend.flat => c.text2,
};

IconData trendIcon(Trend t) => switch (t) {
  Trend.down => Symbols.trending_down_rounded,
  Trend.up => Symbols.trending_up_rounded,
  Trend.flat => Symbols.trending_flat_rounded,
};

/// The Reports tab (board "Reports"). Everything follows the pocket in use.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pocketId = ref.watch(currentPocketIdProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader(title: 'Reports'),
            Expanded(
              child: pocketId == null
                  ? const SizedBox.shrink()
                  : _ReportsBody(pocketId: pocketId),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsBody extends ConsumerStatefulWidget {
  const _ReportsBody({required this.pocketId});

  final int pocketId;

  @override
  ConsumerState<_ReportsBody> createState() => _ReportsBodyState();
}

class _ReportsBodyState extends ConsumerState<_ReportsBody> {
  int? _year;
  int? _month;

  @override
  void didUpdateWidget(covariant _ReportsBody old) {
    super.didUpdateWidget(old);
    if (old.pocketId != widget.pocketId) {
      _year = null;
      _month = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pocketId = widget.pocketId;
    final today = ref.watch(todayProvider);
    final curYear = yearOfDay(today);
    final span = ref.watch(daySpanProvider(pocketId)).value;
    if (span == null) return const SizedBox.shrink();
    final first = span.first != null && span.first! <= today
        ? span.first
        : null;
    final firstYear = first == null ? curYear : yearOfDay(first);
    final totalsList = ref
        .watch(
          monthTotalsProvider((
            pocketId: pocketId,
            from: yearStart(firstYear - 1),
            to: today,
          )),
        )
        .value;
    if (totalsList == null) return const SizedBox.shrink();
    final totals = totalsByMonth(totalsList);

    final years = [for (var y = firstYear; y <= curYear; y++) y];
    final year = _year != null && years.contains(_year) ? _year! : curYear;
    final months = monthsOfYear(
      year: year,
      totals: totals,
      today: today,
      firstDay: first,
    );
    var selected = _month;
    if (selected == null || !months[selected - 1].shown) {
      selected = year == curYear ? monthOfDay(today) : 12;
      if (!months[selected - 1].shown) {
        final shown = months.where((m) => m.shown);
        selected = shown.isEmpty ? selected : shown.last.month;
      }
    }

    // All time: full months from the first expense's month to the last
    // month that has ended.
    var allTotal = 0;
    final fullMonths = <int>[];
    if (first != null) {
      var ym = yearMonthOfDay(first);
      final cur = yearMonthOfDay(today);
      while (ym.year < cur.year ||
          (ym.year == cur.year && ym.month <= cur.month)) {
        final v = totals[(ym.year, ym.month)] ?? 0;
        allTotal += v;
        if (monthEnd(ym.year, ym.month) <= today) fullMonths.add(v);
        ym = addMonths(ym.year, ym.month, 1);
      }
    }
    final allAvg = fullMonths.isEmpty
        ? null
        : (fullMonths.fold<int>(0, (s, v) => s + v) / fullMonths.length)
              .round();

    int? prevOf(MonthCell m) {
      if (m.month > 1) {
        final p = months[m.month - 2];
        return p.beforeData ? null : p.value;
      }
      return year - 1 >= firstYear ? totals[(year - 1, 12)] ?? 0 : null;
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          _MonthlyStats(pocketId: pocketId, today: today),
          const SizedBox(height: 12),
          YearCard(
            years: years,
            year: year,
            months: months,
            selected: selected,
            previous: prevOf,
            onYear: (y) => setState(() {
              _year = y;
              _month = null;
            }),
            onMonth: (m) => setState(() => _month = m),
          ),
          const SizedBox(height: 12),
          _AllTime(first: first, total: allTotal, average: allAvg),
          const SizedBox(height: 12),
          _MonthByMonth(
            months: [
              for (final m in months.reversed)
                if (m.shown) m,
            ],
            selected: selected,
            previous: prevOf,
            onMonth: (m) => setState(() => _month = m),
          ),
        ],
      ),
    );
  }
}

/// Card 1: this month so far, the daily average, the same days of last
/// month, and the biggest category.
class _MonthlyStats extends ConsumerWidget {
  const _MonthlyStats({required this.pocketId, required this.today});

  final int pocketId;
  final int today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final ym = yearMonthOfDay(today);
    final from = monthStart(ym.year, ym.month);
    final days = today - from + 1;
    final spent = ref
        .watch(rangeTotalProvider((pocketId: pocketId, from: from, to: today)))
        .value;
    final prevWin = previousSameDays(today);
    final prev = ref
        .watch(
          rangeTotalProvider((
            pocketId: pocketId,
            from: prevWin.from,
            to: prevWin.to,
          )),
        )
        .value;
    final cats = ref
        .watch(
          categoryTotalsProvider((pocketId: pocketId, from: from, to: today)),
        )
        .value;
    final byId = ref.watch(categoriesByIdProvider);
    final top = cats == null || cats.isEmpty ? null : cats.first;
    final ExpenseCategory? topCat = top == null ? null : byId[top.categoryId];

    final delta = spent == null ? null : deltaOf(spent, prev);
    final String cmpText;
    final Color cmpColor;
    if (spent == null || prev == null) {
      cmpText = '';
      cmpColor = c.text3;
    } else if (delta == null) {
      cmpText = '—';
      cmpColor = c.text3;
    } else if (delta.trend == Trend.flat) {
      cmpText = 'Same';
      cmpColor = c.text2;
    } else {
      cmpText =
          '${delta.percent}% ${delta.trend == Trend.down ? 'less' : 'more'}';
      cmpColor = trendColor(c, delta.trend);
    }
    final label = AppText.sub.copyWith(color: c.text3);
    Widget stat(String l, String v, CrossAxisAlignment align, {Color? color}) =>
        Column(
          crossAxisAlignment: align,
          children: [
            Text(l, maxLines: 1, style: label),
            const SizedBox(height: 2),
            Text(
              v,
              maxLines: 1,
              softWrap: false,
              style: ReportText.stat.copyWith(color: color ?? c.text),
            ),
          ],
        );
    final prevName = monthShortName(monthOfDay(prevWin.from));
    return BandCard(
      title: 'Monthly statistics',
      trailingText: monthYear(ym.year, ym.month),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: stat(
                    'Spent so far',
                    spent == null ? '' : fmt.formatWhole(spent),
                    CrossAxisAlignment.start,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: stat(
                    'Daily average',
                    spent == null
                        ? ''
                        : fmt.formatWhole((spent / days).round()),
                    CrossAxisAlignment.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: stat(
                    'vs $prevName 1–${prevWin.days}',
                    cmpText,
                    CrossAxisAlignment.end,
                    color: cmpColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 68,
            child: Row(
              children: [
                const SizedBox(width: 16),
                if (topCat != null)
                  EmojiTile(emoji: topCat.emoji)
                else
                  IconTile(icon: Symbols.category_rounded, iconColor: c.text3),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    foregroundDecoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Biggest category', style: label),
                              const SizedBox(height: 2),
                              Text(
                                topCat?.name ?? 'Nothing spent yet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.rowTitle.copyWith(
                                  color: topCat == null ? c.text3 : c.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (top != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            fmt.formatWhole(top.total),
                            style: AppText.rowAmount,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card 3: all time and the average full month.
class _AllTime extends ConsumerWidget {
  const _AllTime({
    required this.first,
    required this.total,
    required this.average,
  });

  final int? first;
  final int total;
  final int? average;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final label = AppText.sub.copyWith(color: c.text3);
    final caption = AppText.caption.copyWith(color: c.text3);
    final since = first == null
        ? 'No expenses yet'
        : 'Since ${monthYear(yearOfDay(first!), monthOfDay(first!))}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All time', style: label),
                const SizedBox(height: 2),
                Text(
                  fmt.formatWhole(total),
                  maxLines: 1,
                  softWrap: false,
                  style: ReportText.big,
                ),
                const SizedBox(height: 2),
                Text(since, maxLines: 1, style: caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Average month', style: label),
              const SizedBox(height: 2),
              Text(
                average == null ? '—' : fmt.formatWhole(average!),
                maxLines: 1,
                style: ReportText.big.copyWith(
                  color: average == null ? c.text3 : c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text('Full months only', style: caption),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card 4: the shown year's months, latest first, with the change from the
/// month before (green down, rose up). Tapping a row selects that month.
class _MonthByMonth extends ConsumerWidget {
  const _MonthByMonth({
    required this.months,
    required this.selected,
    required this.previous,
    required this.onMonth,
  });

  final List<MonthCell> months;
  final int selected;
  final int? Function(MonthCell) previous;
  final ValueChanged<int> onMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final head = AppText.caption.copyWith(
      fontWeight: FontWeight.w600,
      color: c.text3,
    );
    Widget grid(Widget a, Widget b, Widget d) => Row(
      children: [
        Expanded(child: a),
        SizedBox(width: 88, child: b),
        SizedBox(width: 80, child: d),
      ],
    );
    if (months.isEmpty) {
      // No headings over nothing: a quiet line, like Charts' empty
      // "By category" card (and its "Each month you spend in gets a
      // column." under the empty chart).
      return const BandCard(
        title: 'Month by month',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: EmptyNote('Each month you spend in gets a row.'),
        ),
      );
    }
    return BandCard(
      title: 'Month by month',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              foregroundDecoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.line)),
              ),
              alignment: Alignment.center,
              child: grid(
                Text('Month', style: head),
                Text('Spent', textAlign: TextAlign.right, style: head),
                Text('vs previous', textAlign: TextAlign.right, style: head),
              ),
            ),
            for (final (i, m) in months.indexed)
              _MonthRow(
                cell: m,
                selected: m.month == selected,
                divider: i < months.length - 1,
                amount: fmt.formatWhole(m.value),
                delta: m.partial ? null : deltaOf(m.value, previous(m)),
                onTap: () => onMonth(m.month),
                grid: grid,
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.cell,
    required this.selected,
    required this.divider,
    required this.amount,
    required this.delta,
    required this.onTap,
    required this.grid,
  });

  final MonthCell cell;
  final bool selected;
  final bool divider;
  final String amount;
  final Delta? delta;
  final VoidCallback onTap;
  final Widget Function(Widget, Widget, Widget) grid;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = delta;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '${monthName(cell.month)} ${cell.year}',
      color: selected ? c.wash : Colors.transparent,
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        foregroundDecoration: divider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: c.line)),
              )
            : null,
        alignment: Alignment.center,
        child: grid(
          Row(
            children: [
              Flexible(
                child: Text(
                  monthName(cell.month),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowTitle,
                ),
              ),
              if (cell.partial) ...[
                const SizedBox(width: 8),
                Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'so far',
                    style: AppText.navLabel.copyWith(color: c.text2),
                  ),
                ),
              ],
            ],
          ),
          Text(
            amount,
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
            style: AppText.rowAmount,
          ),
          d == null
              ? Text(
                  '—',
                  textAlign: TextAlign.right,
                  style: ReportText.rowDelta.copyWith(color: c.text3),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      trendIcon(d.trend),
                      size: 18,
                      color: trendColor(c, d.trend),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${d.percent}%',
                      style: ReportText.rowDelta.copyWith(
                        color: trendColor(c, d.trend),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
