import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../router.dart';
import '../../state/providers.dart';
import '../../widgets/kit.dart';

/// Home (tab). PLACEHOLDER: the Home feature replaces this file.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pocket = ref.watch(currentPocketProvider);
    final today = ref.watch(todayProvider);
    final fmt = ref.watch(amountFormatProvider);
    final ym = yearMonthOfDay(today);
    final lines = <String>[];
    if (pocket != null) {
      final total = ref
          .watch(
            rangeTotalProvider((
              pocketId: pocket.id,
              from: monthStart(ym.year, ym.month),
              to: today,
            )),
          )
          .value;
      final day = ref
          .watch(
            rangeTotalProvider((pocketId: pocket.id, from: today, to: today)),
          )
          .value;
      lines
        ..add('Pocket: ${pocket.emoji} ${pocket.name}')
        ..add('Spent in ${monthName(ym.month)}: ${total == null ? '…' : fmt.format(total)}')
        ..add('Today: ${day == null ? '…' : fmt.format(day)}');
    }
    return PlaceholderScreen(
      title: 'Home',
      tab: true,
      lines: lines,
      header: PageHeader(
        title: 'Home',
        actions: [
          RoundIconButton(
            icon: Symbols.calendar_month_rounded,
            semanticLabel: 'Calendar',
            onTap: () => context.push(Routes.calendar()),
          ),
        ],
      ),
    );
  }
}
