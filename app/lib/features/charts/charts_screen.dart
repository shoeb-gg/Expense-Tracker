import 'dart:async';

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
import 'chart_data.dart';
import 'chart_model.dart';
import 'chart_parts.dart';
import 'column_chart.dart';
import 'range_popups.dart';
import 'ring_chart.dart';

/// Warm colour of "N% more than ..." (the mockup's own, not a token).
const Color _moreColor = Color(0xFFFF9A8F);

/// Charts (tab): Week / Month / Year / Custom, period tabs, the summary,
/// three charts (Categories ring, Top days ring, Over time columns) and the
/// ranked list of categories. Swiping across the screen moves to the
/// previous period (finger left to right) or the next one (right to left);
/// tapping the chosen period tab opens the date, month or year pop-up.
class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});

  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen> {
  PeriodKind _kind = PeriodKind.month;
  final Map<PeriodKind, int> _offsets = {
    for (final k in PeriodKind.values) k: 0,
  };
  ChartView _view = ChartView.categories;

  /// Selected slice or row: `c<id>`, `other`, `d<day>` or `dother`.
  String? _sel;

  /// Pinned column of the "Over time" chart.
  int? _pinned;
  bool _forward = true;
  int? _downPointer;
  int? _chartPointer;

  ({int from, int to}) _customRange(AppSettings s, int today) =>
      s.lastCustomRange ?? defaultCustomRange(today);

  ChartPeriod _period(int today, AppSettings s) => periodAt(
        _kind,
        _offsets[_kind]!,
        today: today,
        first: s.firstDayOfWeek,
        custom: _customRange(s, today),
      );

  /// The offsets the period tabs show. A period still to come (offset below
  /// 0) takes the first tab, where an old period goes too.
  List<int> _tabOffsets(PeriodKind kind, int selected) => selected < 0
      ? [selected, for (var o = tabCount(kind) - 2; o >= 0; o--) o]
      : tabOffsets(kind, selected);

  void _select(PeriodKind kind, int offset, {required bool forward}) =>
      setState(() {
        _forward = forward;
        _kind = kind;
        _offsets[kind] = offset;
        _sel = null;
        _pinned = null;
      });

  void _onSwipe(SwipeEvent e) {
    if (e.axis != Axis.horizontal) return;
    // A drag along the columns pins amounts; it does not change the period.
    if (_chartPointer != null && _chartPointer == _downPointer) return;
    if (_kind == PeriodKind.custom) return;
    // No end, back or forward: the first expense and today are not limits.
    final o = _offsets[_kind]!;
    _select(_kind, e.next ? o - 1 : o + 1, forward: e.next);
  }

  void _onKind(PeriodKind kind) {
    if (kind == PeriodKind.custom) {
      unawaited(_openCustom());
      return;
    }
    if (kind == _kind) return;
    _select(kind, _offsets[kind]!, forward: kind.index > _kind.index);
  }

  void _onTab(int offset) {
    if (_kind == PeriodKind.custom) {
      unawaited(_openCustom());
    } else if (offset != _offsets[_kind]) {
      _select(_kind, offset, forward: offset < _offsets[_kind]!);
    } else {
      unawaited(_openPicker());
    }
  }

  Future<void> _openCustom() async {
    final today = ref.read(todayProvider);
    final s = ref.read(settingsProvider);
    final range = await showCustomRange(
      context,
      initial: _customRange(s, today),
    );
    if (range == null || !mounted) return;
    await ref.read(settingsProvider.notifier).setLastCustomRange(range);
    if (!mounted) return;
    _select(PeriodKind.custom, 0, forward: _kind != PeriodKind.custom);
  }

  Future<void> _openPicker() async {
    final today = ref.read(todayProvider);
    final s = ref.read(settingsProvider);
    final p = _period(today, s);
    int? offset;
    switch (_kind) {
      case PeriodKind.week:
        final day = await showDayPicker(
          context,
          initialDay: p.offset == 0 ? today : p.from,
          label: 'Week to show',
        );
        if (day != null) {
          offset = offsetOfDay(
            PeriodKind.week,
            day,
            today: today,
            first: s.firstDayOfWeek,
          );
        }
      case PeriodKind.month:
        final ym = await showMonthPicker(
          context,
          year: yearOfDay(p.from),
          month: monthOfDay(p.from),
        );
        if (ym != null) {
          offset = offsetOfDay(
            PeriodKind.month,
            monthStart(ym.$1, ym.$2),
            today: today,
            first: s.firstDayOfWeek,
          );
        }
      case PeriodKind.year:
        final y = await showYearPicker(context, year: yearOfDay(p.from));
        if (y != null) offset = yearOfDay(today) - y;
      case PeriodKind.custom:
        return;
    }
    if (offset == null || !mounted) return;
    if (offset == _offsets[_kind]) return;
    _select(_kind, offset, forward: offset < _offsets[_kind]!);
  }

  void _toggle(String key) => setState(() => _sel = _sel == key ? null : key);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = ref.watch(todayProvider);
    final settings = ref.watch(settingsProvider);
    final pocketId = ref.watch(currentPocketIdProvider);
    final index = pocketId == null
        ? null
        : ref.watch(spendIndexProvider(pocketId)).value;
    final period = _period(today, settings);

    final tabs = [
      for (final o in _tabOffsets(_kind, _offsets[_kind]!))
        () {
          final p = _kind == PeriodKind.custom
              ? period
              : periodAt(
                  _kind,
                  o,
                  today: today,
                  first: settings.firstDayOfWeek,
                  custom: _customRange(settings, today),
                );
          return _TabSpec(
            label: periodTabLabel(p),
            on: _kind == PeriodKind.custom || o == _offsets[_kind],
            onTap: () => _onTab(o),
          );
        }(),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Listener(
          onPointerDown: (e) => _downPointer = e.pointer,
          child: SwipeArea(
            onSwipe: _onSwipe,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PageHeader(title: 'Charts'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Semantics(
                          label: 'Time range',
                          child: AppSegmented<PeriodKind>(
                            segments: [
                              for (final k in PeriodKind.values)
                                Segment<PeriodKind>(k, k.label),
                            ],
                            value: _kind,
                            onChanged: _onKind,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PeriodTabs(tabs: tabs),
                    ],
                  ),
                ),
                Expanded(
                  child: index == null
                      ? const SizedBox.shrink()
                      : SlideSwitcher(
                          pageKey: '${_kind.name}:${period.from}:${period.to}',
                          forward: _forward,
                          child: _ChartsBody(
                            key: ValueKey('${period.kind}:${period.from}'),
                            period: period,
                            index: index,
                            view: _view,
                            selected: _sel,
                            pinned: _pinned,
                            onView: (v) => setState(() {
                              _view = v;
                              _sel = null;
                              _pinned = null;
                            }),
                            onSelect: _toggle,
                            onRow: (key) => setState(() {
                              _view = ChartView.categories;
                              _pinned = null;
                              _sel = _sel == key ? null : key;
                            }),
                            onPin: (i) => setState(() => _pinned = i),
                            onChartDown: (e) => _chartPointer = e.pointer,
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

@immutable
class _TabSpec {
  const _TabSpec({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;
}

/// The period tabs: 44 px, left-aligned under the title, an accent underline
/// under the chosen one. Each tab reserves its bold width so nothing shifts.
class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.tabs});

  final List<_TabSpec> tabs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bold = AppText.label.copyWith(fontWeight: FontWeight.w800);
    final scaler = MediaQuery.textScalerOf(context);
    // Each tab is as wide as its label in bold, so choosing one never moves
    // the others.
    double boldWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: bold),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in tabs)
                  Semantics(
                    button: true,
                    selected: t.on,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: t.onTap,
                      child: SizedBox(
                        height: 44,
                        child: Stack(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                width: boldWidth(t.label),
                                height: 44,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    t.label,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: t.on
                                        ? bold.copyWith(color: c.text)
                                        : AppText.label.copyWith(
                                            color: c.text3,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 0,
                              height: 3,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: t.on
                                      ? c.accent
                                      : const Color(0x00000000),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
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
      ),
    );
  }
}

/// Everything under the header for one period (it slides as a whole).
class _ChartsBody extends ConsumerWidget {
  const _ChartsBody({
    super.key,
    required this.period,
    required this.index,
    required this.view,
    required this.selected,
    required this.pinned,
    required this.onView,
    required this.onSelect,
    required this.onRow,
    required this.onPin,
    required this.onChartDown,
  });

  final ChartPeriod period;
  final SpendIndex index;
  final ChartView view;
  final String? selected;
  final int? pinned;
  final ValueChanged<ChartView> onView;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRow;
  final ValueChanged<int?> onPin;
  final ValueChanged<PointerDownEvent> onChartDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final cats = ref.watch(categoriesByIdProvider);
    final summary = summaryOf(period, today, index);
    final ranked = [
      for (final e in index.byCategory(period.from, period.lastPast(today)))
        if (cats[e.categoryId] != null)
          (category: cats[e.categoryId]!, amount: e.amount),
    ];

    final Widget chart = switch (view) {
      ChartView.categories => _CategoriesRing(
          period: period,
          ranked: ranked,
          total: summary.total,
          selected: selected,
          onSelect: onSelect,
        ),
      ChartView.topDays => _TopDaysRing(
          period: period,
          index: index,
          total: summary.total,
          selected: selected,
          onSelect: onSelect,
        ),
      ChartView.overTime => _OverTime(
          period: period,
          index: index,
          summary: summary,
          pinned: pinned,
          onPin: onPin,
          onChartDown: onChartDown,
        ),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryCard(summary: summary),
          const SizedBox(height: 12),
          _ViewButtons(view: view, onView: onView),
          const SizedBox(height: 12),
          chart,
          const SizedBox(height: 12),
          _RankedList(
            ranked: ranked,
            total: summary.total,
            selected: view == ChartView.categories ? selected : null,
            onRow: onRow,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final delta = summary.delta;
    final Widget pill;
    if (delta == null) {
      pill = Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                nothingToCompare,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.overline.copyWith(color: c.text2),
              ),
            ),
          ],
        ),
      );
    } else {
      final color = switch (delta.trend) {
        Trend.up => _moreColor,
        Trend.down => c.good,
        Trend.flat => c.text2,
      };
      final icon = switch (delta.trend) {
        Trend.up => Symbols.trending_up_rounded,
        Trend.down => Symbols.trending_down_rounded,
        Trend.flat => Symbols.trending_flat_rounded,
      };
      pill = Container(
        height: 28,
        padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                delta.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.overline.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ChartCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(),
              1: IntrinsicColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TableRow(
                children: [
                  Text('Total spent', style: ChartText.label(c)),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      summary.averageLabel,
                      textAlign: TextAlign.right,
                      style: ChartText.label(c),
                    ),
                  ),
                ],
              ),
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      fmt.format(summary.total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ChartText.total,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: Text(
                      fmt.formatWhole(summary.average.round()),
                      textAlign: TextAlign.right,
                      style: ChartText.stat,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          pill,
        ],
      ),
    );
  }
}

class _ViewButtons extends StatelessWidget {
  const _ViewButtons({required this.view, required this.onView});

  final ChartView view;
  final ValueChanged<ChartView> onView;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (final v in ChartView.values) ...[
          if (v.index > 0) const SizedBox(width: 8),
          Expanded(
            child: Pressable(
              onTap: () => onView(v),
              color: v == view ? c.accentSoft : c.surface,
              borderRadius: BorderRadius.circular(18),
              selected: v == view,
              semanticLabel: v.label,
              child: SizedBox(
                height: 36,
                child: Center(
                  child: Text(
                    v.label,
                    maxLines: 1,
                    softWrap: false,
                    style: AppText.segment.copyWith(
                      fontWeight: FontWeight.w700,
                      color: v == view ? c.accent : c.text2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

typedef _Ranked = ({ExpenseCategory category, int amount});

class _CategoriesRing extends ConsumerWidget {
  const _CategoriesRing({
    required this.period,
    required this.ranked,
    required this.total,
    required this.selected,
    required this.onSelect,
  });

  final ChartPeriod period;
  final List<_Ranked> ranked;
  final int total;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final top = ranked.take(5).toList();
    final rest = ranked.skip(5).toList();
    final restSum = rest.fold<int>(0, (s, e) => s + e.amount);
    final slices = [
      for (final r in top)
        RingSlice(
          key: 'c${r.category.id}',
          value: r.amount,
          color: Color(r.category.color),
          tag: r.category.emoji,
          isEmoji: true,
        ),
      if (restSum > 0)
        RingSlice(
          key: 'other',
          value: restSum,
          color: c.other,
          tag: '+${rest.length}',
          isEmoji: false,
        ),
    ];

    final sel = selected;
    String? ringSel;
    Widget center;
    if (sel == null) {
      center = RingCenter(
        title: 'Total',
        value: fmt.format(total),
        sub: total == 0 ? 'Nothing spent' : categoryCount(ranked.length),
      );
    } else if (sel == 'other') {
      ringSel = 'other';
      center = RingCenter(
        title: 'Other',
        value: fmt.format(restSum),
        sub: categoryCount(rest.length),
      );
    } else {
      final r = ranked.where((e) => 'c${e.category.id}' == sel).firstOrNull;
      if (r == null) {
        center = RingCenter(
          title: 'Total',
          value: fmt.format(total),
          sub: categoryCount(ranked.length),
        );
      } else {
        ringSel = top.contains(r) ? sel : 'other';
        center = RingCenter(
          title: r.category.name,
          value: fmt.format(r.amount),
          sub: '${shareText(r.amount, total, fmt)} of total',
          onDetails: () => unawaited(
            context.push(
              Routes.category(r.category.id, from: period.from, to: period.to),
            ),
          ),
        );
      }
    }

    return ChartCard(
      child: Column(
        children: [
          RingChart(
            slices: slices,
            selected: ringSel,
            onTap: onSelect,
            center: center,
          ),
          const SizedBox(height: 12),
          _Hint(
            total == 0
                ? 'Each category you spend on gets a slice.'
                : sel == null
                    ? 'Tap a slice or a category below to see its share.'
                    : 'Tap it again to go back to the total.',
          ),
        ],
      ),
    );
  }
}

class _TopDaysRing extends ConsumerWidget {
  const _TopDaysRing({
    required this.period,
    required this.index,
    required this.total,
    required this.selected,
    required this.onSelect,
  });

  final ChartPeriod period;
  final SpendIndex index;
  final int total;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final today = ref.watch(todayProvider);
    final days = index.topDays(period.from, period.lastPast(today));
    final top = days.take(5).toList();
    final rest = days.skip(5).toList();
    final topSum = top.fold<int>(0, (s, e) => s + e.amount);
    final restSum = rest.fold<int>(0, (s, e) => s + e.amount);

    final entries = <({String key, String tag, String name, int amount})>[
      for (var i = 0; i < top.length; i++)
        (
          key: 'd${top[i].day}',
          tag: '${i + 1}',
          name: weekdayMonthDay(top[i].day),
          amount: top[i].amount,
        ),
      if (restSum > 0)
        (
          key: 'dother',
          tag: '+${rest.length}',
          name: otherDays(rest.length),
          amount: restSum,
        ),
    ];
    final slices = [
      for (var i = 0; i < entries.length; i++)
        RingSlice(
          key: entries[i].key,
          value: entries[i].amount,
          color: entries[i].key == 'dother' ? c.other : c.ramp[i],
          tag: entries[i].tag,
          isEmoji: false,
        ),
    ];

    final chosen = entries.where((e) => e.key == selected).firstOrNull;
    final center = chosen == null
        ? RingCenter(
            title: top.isEmpty
                ? 'Top days'
                : top.length == 1
                    ? 'Top day'
                    : 'Top ${top.length} days',
            value: fmt.format(topSum),
            sub: total == 0
                ? 'Nothing spent'
                : '${shareText(topSum, total, fmt)} of total',
          )
        : RingCenter(
            title: chosen.name,
            value: fmt.format(chosen.amount),
            sub: '${shareText(chosen.amount, total, fmt)} of total',
          );

    final hint = total == 0
        ? 'Your five biggest days will show here.'
        : chosen != null
            ? 'Tap it again to go back to the total.'
            : top.length >= 5
                ? 'The five days you spent the most in this period.'
                : 'The days you spent the most in this period.';

    final rows = <Widget>[];
    for (var r = 0; r * 2 < entries.length; r++) {
      if (r > 0) rows.add(const SizedBox(height: 4));
      rows.add(
        Row(
          children: [
            for (var k = 0; k < 2; k++) ...[
              if (k > 0) const SizedBox(width: 8),
              Expanded(
                child: r * 2 + k < entries.length
                    ? _LegendItem(
                        tag: entries[r * 2 + k].tag,
                        name: entries[r * 2 + k].name,
                        amount: fmt.format(entries[r * 2 + k].amount),
                        on: entries[r * 2 + k].key == selected,
                        onTap: () => onSelect(entries[r * 2 + k].key),
                      )
                    : const SizedBox(height: 44),
              ),
            ],
          ],
        ),
      );
    }

    return ChartCard(
      child: Column(
        children: [
          RingChart(
            slices: slices,
            selected: chosen?.key,
            onTap: onSelect,
            center: center,
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            // The legend reaches 8 px into the card padding on both sides.
            SizedBox(
              width: double.infinity,
              height: ((entries.length + 1) ~/ 2) * 48 - 4,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -8,
                    right: -8,
                    top: 0,
                    child: Column(children: rows),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Hint(hint),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.tag,
    required this.name,
    required this.amount,
    required this.on,
    required this.onTap,
  });

  final String tag;
  final String name;
  final String amount;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      color: on ? c.wash : const Color(0x00000000),
      borderRadius: BorderRadius.circular(12),
      selected: on,
      semanticLabel: '$name, $amount',
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.tile,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(tag, style: rankTagStyle(tag, c.text)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sub.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      amount,
                      maxLines: 1,
                      style: AppText.tabular(
                        AppText.caption.copyWith(color: c.text3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverTime extends ConsumerWidget {
  const _OverTime({
    required this.period,
    required this.index,
    required this.summary,
    required this.pinned,
    required this.onPin,
    required this.onChartDown,
  });

  final ChartPeriod period;
  final SpendIndex index;
  final PeriodSummary summary;
  final int? pinned;
  final ValueChanged<int?> onPin;
  final ValueChanged<PointerDownEvent> onChartDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final today = ref.watch(todayProvider);
    final points = periodColumns(period, today, index);
    final byMonth = period.byMonth;
    final keyLine = summary.total == 0
        ? 'Nothing spent in this period.'
        : 'Dashed line = average ${fmt.formatWhole(summary.average.round())}';
    return ChartCard(
      child: Column(
        children: [
          ChartHeading(
            title: byMonth ? 'Monthly spending' : 'Daily spending',
            keyLine: keyLine,
          ),
          const SizedBox(height: 12),
          ColumnChart(
            points: points,
            average: summary.total == 0 ? 0 : summary.average,
            colors: ColumnColors(hi: c.accent, soft: c.barSoft, dim: c.barDim),
            pinned: pinned,
            onPin: onPin,
            onPointerDown: onChartDown,
            semanticLabel: byMonth
                ? 'Column chart of monthly spending'
                : 'Column chart of daily spending',
          ),
          const SizedBox(height: 12),
          _Hint(
            summary.total == 0
                ? emptyColumnsHint(byMonth: byMonth)
                : byMonth
                    ? 'Tap a column to see that month.'
                    : 'Tap a column to see that day.',
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: ChartText.hint(context.colors),
        ),
      );
}

class _RankedList extends ConsumerWidget {
  const _RankedList({
    required this.ranked,
    required this.total,
    required this.selected,
    required this.onRow,
  });

  final List<_Ranked> ranked;
  final int total;
  final String? selected;
  final ValueChanged<String> onRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final maxAmount = ranked.isEmpty ? 1 : ranked.first.amount;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: c.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 48,
              color: c.surface2,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      'By category',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      categoryCount(ranked.length),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sub.copyWith(color: c.text3),
                    ),
                  ),
                ],
              ),
            ),
            if (ranked.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: EmptyNote('Nothing spent in this period.'),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < ranked.length; i++)
                      _RankedRow(
                        category: ranked[i].category,
                        amount: fmt.format(ranked[i].amount),
                        share: shareText(ranked[i].amount, total, fmt),
                        fraction: ranked[i].amount / maxAmount,
                        color: i < 5
                            ? Color(ranked[i].category.color)
                            : c.other,
                        on: selected == 'c${ranked[i].category.id}',
                        divider: i < ranked.length - 1,
                        onTap: () => onRow('c${ranked[i].category.id}'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({
    required this.category,
    required this.amount,
    required this.share,
    required this.fraction,
    required this.color,
    required this.on,
    required this.divider,
    required this.onTap,
  });

  final ExpenseCategory category;
  final String amount;
  final String share;
  final double fraction;
  final Color color;
  final bool on;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      color: on ? c.wash : const Color(0x00000000),
      selected: on,
      semanticLabel: '${category.name}, $amount, $share',
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            const SizedBox(width: 16),
            EmojiTile(emoji: category.emoji),
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
                            category.name,
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
                      height: 16,
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
