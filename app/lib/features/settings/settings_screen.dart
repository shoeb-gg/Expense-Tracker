import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/days.dart';
import '../../router.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import '../data/data_parts.dart';
import 'settings_parts.dart';
import 'settings_sheets.dart';

/// The Settings tab (boards "Settings" and "Settings: the Pockets row").
/// Every change writes through the settings setters and shows at once.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader(title: 'Settings'),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  children: const [
                    _AppearanceCard(),
                    SizedBox(height: 12),
                    _HomeCalendarCard(),
                    SizedBox(height: 12),
                    _PocketsCard(),
                    SizedBox(height: 12),
                    _CategoriesCard(),
                    SizedBox(height: 12),
                    _NumbersCard(),
                    SizedBox(height: 12),
                    _DataCard(),
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

/// 1 px divider inside the 16 px row margins.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(height: 1, color: context.colors.line),
  );
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final today = ref.watch(todayProvider);
    final pocketId = ref.watch(currentPocketIdProvider);
    final fmt = ref.watch(amountFormatProvider);
    final ym = yearMonthOfDay(today);
    final spent = pocketId == null
        ? null
        : ref
              .watch(
                rangeTotalProvider((
                  pocketId: pocketId,
                  from: monthStart(ym.year, ym.month),
                  to: today,
                )),
              )
              .value;
    final previewStyle = AppText.label.copyWith(fontSize: 15, height: 28 / 15);
    return BandCard(
      title: 'Appearance',
      icon: Symbols.palette_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // No Light / System / Dark choice here until a light theme is
          // built: the app always renders dark (the stored value still loads).
          Padding(
            // 15 + the 1 px divider below = the board's 16 px.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlockHeader(title: 'Color theme', note: s.mood.label),
                const SizedBox(height: 12),
                MoodTiles(value: s.mood, onChanged: notifier.setMood),
              ],
            ),
          ),
          const _Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlockHeader(
                  title: 'Text size',
                  note: textScaleNames[s.textSizeIndex],
                ),
                const SizedBox(height: 10),
                TextSizeSlider(
                  index: s.textSizeIndex,
                  onChanged: notifier.setTextSizeIndex,
                ),
                const SizedBox(height: 10),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          spentInLabel(today),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: previewStyle.copyWith(
                            fontWeight: FontWeight.w500,
                            color: c.text2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        spent == null ? '' : fmt.format(spent),
                        maxLines: 1,
                        style: previewStyle.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Preview. The whole app uses this size.',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: c.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCalendarCard extends ConsumerWidget {
  const _HomeCalendarCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    Widget toggle(
      String title,
      String sub,
      bool value,
      ValueChanged<bool> set,
    ) => BottomHairline(
      child: ListRow(
        title: title,
        subtitle: sub,
        divider: false,
        wrap: true,
        onTap: () => set(!value),
        trailing: AppSwitch(value: value, onChanged: set, semanticLabel: title),
      ),
    );
    return BandCard(
      title: 'Home and calendar',
      icon: Symbols.calendar_month_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toggle(
            'Monthly total on Home',
            'The big number at the top of Home',
            s.showMonthlyTotal,
            n.setShowMonthlyTotal,
          ),
          toggle(
            'Privacy hide',
            'Mask the total until you tap the eye',
            s.privacyMask,
            n.setPrivacyMask,
          ),
          toggle(
            'Calendar button',
            'Shortcut to the calendar on Home',
            s.showCalendarButton,
            n.setShowCalendarButton,
          ),
          toggle(
            'Amounts in calendar days',
            'Show each day’s total in its cell',
            s.calendarAmounts,
            n.setCalendarAmounts,
          ),
          ListRow(
            title: 'First day of the week',
            divider: false,
            wrap: true,
            trailing: ValueChevron(text: s.firstDayOfWeek.label),
            onTap: () => pickFirstDayOfWeek(context, ref),
          ),
        ],
      ),
    );
  }
}

class _PocketsCard extends ConsumerWidget {
  const _PocketsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pockets = ref.watch(pocketsProvider).value ?? const [];
    return BandCard(
      title: 'Pockets',
      icon: Symbols.account_balance_wallet_rounded,
      child: ListRow(
        title: 'Manage pockets',
        subtitle: 'Add, edit, delete',
        divider: false,
        wrap: true,
        trailing: PeekTiles(emojis: [for (final p in pockets.take(3)) p.emoji]),
        onTap: () => context.push(Routes.pockets),
      ),
    );
  }
}

class _CategoriesCard extends ConsumerWidget {
  const _CategoriesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider).value ?? const [];
    return BandCard(
      title: 'Categories',
      icon: Symbols.category_rounded,
      child: ListRow(
        title: 'Manage categories',
        subtitle: 'Add, edit, delete, reorder',
        divider: false,
        wrap: true,
        trailing: PeekTiles(
          emojis: [for (final cat in cats.take(2)) cat.emoji],
          more: cats.length > 2 ? cats.length - 2 : 0,
        ),
        onTap: () => context.push(Routes.categories),
      ),
    );
  }
}

class _NumbersCard extends ConsumerWidget {
  const _NumbersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return BandCard(
      title: 'Numbers',
      icon: Symbols.calculate_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomHairline(
            child: ListRow(
              title: 'Number format',
              divider: false,
              wrap: true,
              trailing: ValueChevron(
                text: s.numberStyle.sample(separator: s.thousandsSeparator),
                tabular: true,
              ),
              onTap: () => pickNumberFormat(context, ref),
            ),
          ),
          BottomHairline(
            child: ListRow(
              title: 'Thousands separator',
              divider: false,
              wrap: true,
              onTap: () => n.setThousandsSeparator(!s.thousandsSeparator),
              trailing: AppSwitch(
                value: s.thousandsSeparator,
                onChanged: n.setThousandsSeparator,
                semanticLabel: 'Thousands separator',
              ),
            ),
          ),
          ListRow(
            title: 'Calculator keys',
            divider: false,
            wrap: true,
            trailing: ValueChevron(text: s.calcKeys.label),
            onTap: () => pickCalcKeys(context, ref),
          ),
        ],
      ),
    );
  }
}

class _DataCard extends ConsumerWidget {
  const _DataCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return BandCard(
      title: 'Your data',
      icon: Symbols.folder_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomHairline(
            child: ListRow(
              title: 'Export',
              subtitle: 'Excel or CSV, for any date range',
              divider: false,
              wrap: true,
              trailing: const ValueChevron(),
              onTap: () => context.push(Routes.export),
            ),
          ),
          BottomHairline(
            child: ListRow(
              title: 'Import',
              subtitle: 'From a CSV, Excel or JSON file',
              divider: false,
              wrap: true,
              trailing: const ValueChevron(),
              onTap: () => context.push(Routes.importStart),
            ),
          ),
          BottomHairline(
            child: ListRow(
              title: 'Automatic backup',
              subtitle: 'Phone and Google Drive',
              divider: false,
              wrap: true,
              titleColor: c.text3,
              trailing: const ComingLaterPill(),
            ),
          ),
          BottomHairline(
            child: ListRow(
              title: 'Clear cache',
              subtitle: 'Frees up space. Your expenses stay.',
              divider: false,
              wrap: true,
              onTap: () => clearCacheNow(context, ref),
            ),
          ),
          ListRow(
            title: 'Delete all data',
            subtitle: 'This can’t be undone',
            titleStyle: AppText.rowTitle.copyWith(fontWeight: FontWeight.w700),
            titleColor: c.bad,
            divider: false,
            wrap: true,
            trailing: HangingIcon(
              icon: Symbols.delete_rounded,
              box: 18,
              color: c.bad,
            ),
            onTap: () => confirmDeleteAll(context, ref),
          ),
        ],
      ),
    );
  }
}
