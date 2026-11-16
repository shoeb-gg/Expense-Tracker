import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/settings_store.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/sample_data.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  late Directory temp;

  setUp(() {
    db = openTestDatabase();
    temp = Directory.systemTemp.createTempSync('stb_providers_');
    final cache = Directory('${temp.path}${Platform.pathSeparator}cache')
      ..createSync();
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(Clock.fixed(mockupNow)),
        documentsDirProvider.overrideWithValue(() async => temp),
        cacheDirProvider.overrideWithValue(() async => cache),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    temp.deleteSync(recursive: true);
  });

  Future<T> next<T>(ProviderListenable<AsyncValue<T>> p) async {
    for (var i = 0; i < 50; i++) {
      final v = container.read(p);
      if (v.hasValue) return v.requireValue;
      await pumpEventQueue();
    }
    throw StateError('no value');
  }

  test('current pocket falls back to the default pocket', () async {
    container.listen(pocketsProvider, (_, _) {});
    await next(pocketsProvider);
    final def = container.read(currentPocketProvider)!;
    expect(def.isDefault, isTrue);
    expect(container.read(currentPocketIdProvider), def.id);

    final trip = await container
        .read(pocketsRepoProvider)
        .add(name: 'Trip', emoji: '\u{1F3D6}\u{FE0F}');
    await container.read(settingsProvider.notifier).setCurrentPocketId(trip);
    await pumpEventQueue();
    expect(container.read(currentPocketIdProvider), trip);

    await container.read(pocketsRepoProvider).delete(trip);
    await pumpEventQueue();
    expect(container.read(currentPocketIdProvider), def.id);
  });

  test('settings write through and reload', () async {
    final n = container.read(settingsProvider.notifier);
    await n.setMood(Mood.coral);
    await n.setNumberStyle(NumberStyle.plain);
    await n.setTextSizeIndex(4);
    expect(container.read(settingsProvider).mood, Mood.coral);
    expect(container.read(amountFormatProvider).format(123456789), '1234567.89');
    final loaded = await AppSettings.load(SettingsStore(db));
    expect(loaded.mood, Mood.coral);
    expect(loaded.numberStyle, NumberStyle.plain);
    expect(loaded.textSizeIndex, 4);
  });

  test('range families give the mockup numbers', () async {
    final s = await fillSampleData(db);
    final oct = (pocketId: s.pocketId, from: dayOf(2026, 10, 1), to: sampleToday);
    container.listen(rangeTotalProvider(oct), (_, _) {});
    container.listen(categoryTotalsProvider(oct), (_, _) {});
    container.listen(expensesInRangeProvider(oct), (_, _) {});
    expect(await next(rangeTotalProvider(oct)), 3455500);
    final cats = await next(categoryTotalsProvider(oct));
    expect(cats.fold<int>(0, (a, c) => a + c.total), 3455500);
    final list = await next(expensesInRangeProvider(oct));
    expect(list.first.day, sampleToday);
    expect(container.read(todayProvider), sampleToday);
  });

  test('delete all data switches to the new default pocket', () async {
    container.listen(pocketsProvider, (_, _) {});
    await next(pocketsProvider);
    final old = container.read(currentPocketIdProvider);
    await container.read(dataActionsProvider).deleteAllData();
    await pumpEventQueue();
    final now = container.read(currentPocketIdProvider);
    expect(now, isNot(old));
    expect(container.read(settingsProvider).currentPocketId, now);
  });
}
