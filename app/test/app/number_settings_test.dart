import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/data/settings_store.dart';
import 'package:spill_the_bills/state/settings.dart';

import '../support/test_db.dart';

/// Stored number settings: what older versions saved still loads.
void main() {
  AppSettings from(Map<String, String> entries) =>
      AppSettings.fromEntries(entries);

  group('show decimals', () {
    test('on by default, as before', () {
      expect(const AppSettings().showDecimals, isTrue);
      expect(from(const {}).showDecimals, isTrue);
      expect(const AppSettings().amountFormat, const AmountFormat());
    });

    test('stored as text and read back', () {
      const off = AppSettings(showDecimals: false);
      expect(off.toEntries()[AppSettings.kShowDecimals], 'false');
      expect(from(off.toEntries()).showDecimals, isFalse);
      expect(from({AppSettings.kShowDecimals: 'true'}).showDecimals, isTrue);
      expect(from(const {AppSettings.kShowDecimals: 'false'}), off);
    });

    test('the amount format carries style and switch', () {
      const s = AppSettings(numberStyle: NumberStyle.lakh, showDecimals: false);
      expect(
        s.amountFormat,
        const AmountFormat(style: NumberStyle.lakh, showDecimals: false),
      );
      expect(s.amountFormat.format(123456789), '12,34,568');
      expect(s.copyWith(showDecimals: true).amountFormat.format(123456789),
          '12,34,567.89');
    });

    test('the switch and the style are independent settings', () {
      // An old "separator off" file does not turn the decimals off.
      expect(
        from({AppSettings.kLegacyThousandsSeparator: 'false'}).showDecimals,
        isTrue,
      );
    });

    test('write through to the table and reload', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final store = SettingsStore(db);
      await store.write(AppSettings.kShowDecimals, 'false');
      expect((await AppSettings.load(store)).showDecimals, isFalse);
    });
  });

  group('number style migration', () {
    test('missing keys give the defaults', () {
      expect(from(const {}).numberStyle, NumberStyle.comma);
      expect(const AppSettings().numberStyle, NumberStyle.comma);
    });

    test('the current styles load as they are', () {
      for (final style in NumberStyle.values) {
        expect(from({AppSettings.kNumberStyle: style.name}).numberStyle, style);
      }
    });

    test('the old switch off means the no-grouping style', () {
      for (final old in [
        'comma',
        'dotComma',
        'spaceDot',
        'spaceComma',
        'lakh',
      ]) {
        expect(
          from({
            AppSettings.kNumberStyle: old,
            AppSettings.kLegacyThousandsSeparator: 'false',
          }).numberStyle,
          NumberStyle.plain,
          reason: '$old with the separator off',
        );
      }
      expect(
        from({AppSettings.kLegacyThousandsSeparator: 'false'}).numberStyle,
        NumberStyle.plain,
        reason: 'the style key was never saved',
      );
    });

    test('the old switch on changes nothing', () {
      expect(
        from({
          AppSettings.kNumberStyle: 'lakh',
          AppSettings.kLegacyThousandsSeparator: 'true',
        }).numberStyle,
        NumberStyle.lakh,
      );
    });

    test('the removed dot-comma style becomes 1,234,567.89', () {
      expect(
        from({AppSettings.kNumberStyle: 'dotComma'}).numberStyle,
        NumberStyle.comma,
      );
    });

    test('the removed space-comma style becomes 1 234 567.89', () {
      expect(
        from({AppSettings.kNumberStyle: 'spaceComma'}).numberStyle,
        NumberStyle.spaceDot,
      );
    });

    test('unknown values give the default and never crash', () {
      expect(from({AppSettings.kNumberStyle: 'weird'}).numberStyle,
          NumberStyle.comma);
      expect(from({AppSettings.kNumberStyle: ''}).numberStyle, NumberStyle.comma);
      expect(
        from({
          AppSettings.kNumberStyle: 'weird',
          AppSettings.kLegacyThousandsSeparator: 'banana',
        }).numberStyle,
        NumberStyle.comma,
      );
    });

    test('the old key is not written any more', () {
      final entries = const AppSettings(numberStyle: NumberStyle.plain).toEntries();
      expect(entries.containsKey(AppSettings.kLegacyThousandsSeparator), isFalse);
      expect(entries[AppSettings.kNumberStyle], 'plain');
    });

    test('loading writes the migrated style back and drops the old key', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final store = SettingsStore(db);
      await store.write(AppSettings.kNumberStyle, 'dotComma');
      await store.write(AppSettings.kLegacyThousandsSeparator, 'false');
      expect((await AppSettings.load(store)).numberStyle, NumberStyle.plain);
      var saved = await store.load();
      expect(saved[AppSettings.kNumberStyle], 'plain');
      expect(saved.containsKey(AppSettings.kLegacyThousandsSeparator), isFalse);

      // A style picked later is not overruled by the old key.
      await store.write(AppSettings.kNumberStyle, 'comma');
      expect((await AppSettings.load(store)).numberStyle, NumberStyle.comma);

      await store.write(AppSettings.kNumberStyle, 'spaceComma');
      expect((await AppSettings.load(store)).numberStyle, NumberStyle.spaceDot);
      saved = await store.load();
      expect(saved[AppSettings.kNumberStyle], 'spaceDot');
    });
  });
}
