/// The mockup's sample data, ported from `kit()` in
/// design/mockup/project/NewCharts.dc.html (seeded random 20261018, today
/// 18 Oct 2026, 1 Jan 2025 to 18 Oct 2026). Screens filled with it show the
/// same numbers as the mockup boards: October 2026 = 34,555; Oct 18 = 1,180
/// (one Health expense, "Doctor visit"); 1266 expenses in all. Oct 17's
/// snack (135) has no title, as the Home boards draw it.
library;

import 'package:drift/drift.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/data/db.dart';

/// Today in the mockup.
final int sampleToday = dayOf(2026, 10, 18);

/// What [fillSampleData] inserted.
typedef SampleSummary = ({int pocketId, int count});

/// The mockup's seeded generator (mulberry32), exactly like the JS:
/// `a |= 0; a = a + 0x6D2B79F5 | 0; ...`.
class MockupRandom {
  MockupRandom([this._a = 20261018]);

  int _a;

  static int _imul(int x, int y) => (x * y).toSigned(32);
  static int _u(int x) => x.toUnsigned(32);

  double next() {
    _a = _a.toSigned(32);
    _a = (_a + 0x6D2B79F5).toSigned(32);
    var t = _imul(_a ^ (_u(_a) >> 15), 1 | _a);
    t = (t + _imul(t ^ (_u(t) >> 7), 61 | t)).toSigned(32) ^ t;
    return _u(t ^ (_u(t) >> 14)) / 4294967296;
  }
}

const Map<String, String> _catNames = {
  'groceries': 'Groceries',
  'snacks': 'Snacks',
  'transport': 'Transportation',
  'shopping': 'Shopping',
  'rent': 'House Rent',
  'electric': 'Electric Bill',
  'internet': 'Internet Bill',
  'phone': 'Phone',
  'gas': 'Gas',
  'health': 'Health',
  'gym': 'Gym',
  'selfcare': 'Self Care',
  'subs': 'Online Subscriptions',
  'gifts': 'Gifts',
  'misc': 'Miscellaneous',
};

const Map<String, List<String>> _notes = {
  'groceries': ['Weekly bazaar', 'Vegetables & fish', 'Supermarket run', 'Rice & lentils', ''],
  'snacks': ['Coffee', 'Tea & biscuits', 'Ice cream', 'Bakery', 'Chips & soda', ''],
  'transport': ['Ride to office', 'Ride home', 'Bus fare', ''],
  'shopping': ['New shoes', 'T-shirts', 'Kitchen stuff', ''],
  'selfcare': ['Haircut', 'Skincare', ''],
  'health': ['Pharmacy', 'Doctor visit', ''],
  'gifts': ['Birthday gift', 'Wedding gift'],
  'misc': ['Laundry', 'Stationery', ''],
};

/// One generated expense (whole units, like the mockup).
typedef SampleExpense = ({
  String catId,
  int amount,
  int day,
  String note,
  int hour,
  int minute,
});

/// Generates the mockup's expenses in the mockup's order.
List<SampleExpense> generateSampleExpenses() {
  final r = MockupRandom();
  final out = <SampleExpense>[];
  String pick(List<String> list) => list[(r.next() * list.length).floor()];
  void add(String catId, int amount, int day, String note) {
    final hour = 8 + (r.next() * 14).floor();
    final minute = (r.next() * 60).floor();
    out.add((
      catId: catId,
      amount: amount,
      day: day,
      // The Home boards draw yesterday's snack "as saved without a title,
      // to demonstrate that row style" (kit() itself picks "Chips & soda").
      note: catId == 'snacks' && day == sampleToday - 1 ? '' : note,
      hour: hour,
      minute: minute,
    ));
  }

  for (var n = dayOf(2025, 1, 1); n <= sampleToday; n++) {
    final t = dateOfDay(n);
    final d = t.day;
    final dow = t.weekday % 7; // JS getUTCDay(): 0 = Sunday
    final ml = monthName(t.month);
    if (d == 1) add('rent', 15000, n, '$ml rent');
    if (d == 3) add('gym', 1000, n, 'Membership');
    if (d == 5) add('internet', 1500, n, 'Broadband');
    if (d == 8) add('subs', 685, n, 'Streaming');
    if (d == 12) {
      add('electric', ((2300 + r.next() * 1400) / 10).round() * 10, n, '$ml bill');
    }
    if (d == 20) add('gas', 1150, n, 'Cooking gas');
    if (d == 2 || d == 16) add('phone', 500, n, 'Mobile recharge');
    if (r.next() < 0.72) {
      add('snacks', ((60 + r.next() * 380) / 5).round() * 5, n, pick(_notes['snacks']!));
    }
    if ((dow == 2 || dow == 5) && r.next() < 0.85) {
      add('groceries', ((450 + r.next() * 1800) / 10).round() * 10, n, pick(_notes['groceries']!));
    }
    if (dow >= 1 && dow <= 5 && r.next() < 0.7) {
      add('transport', ((40 + r.next() * 300) / 10).round() * 10, n, pick(_notes['transport']!));
    }
    if (r.next() < 0.05) {
      add('shopping', ((800 + r.next() * 3700) / 50).round() * 50, n, pick(_notes['shopping']!));
    }
    if (r.next() < 0.035) {
      add('selfcare', ((300 + r.next() * 900) / 50).round() * 50, n, pick(_notes['selfcare']!));
    }
    if (r.next() < 0.03) {
      add('health', ((200 + r.next() * 2300) / 10).round() * 10, n, pick(_notes['health']!));
    }
    if (r.next() < 0.015) {
      add('gifts', ((500 + r.next() * 2500) / 100).round() * 100, n, pick(_notes['gifts']!));
    }
    if (r.next() < 0.07) {
      add('misc', ((50 + r.next() * 550) / 10).round() * 10, n, pick(_notes['misc']!));
    }
  }
  return out;
}

/// Inserts the mockup's sample expenses into [pocketId] (the default pocket
/// when null). The database must have the 15 default categories.
Future<SampleSummary> fillSampleData(AppDatabase db, {int? pocketId}) async {
  final categories = await db.select(db.categories).get();
  final idByName = {for (final c in categories) c.name: c.id};
  final pocket = pocketId ??
      (await (db.select(db.pockets)..where((p) => p.isDefault.equals(true)))
              .getSingle())
          .id;
  final rows = generateSampleExpenses();
  await db.batch((b) {
    for (final x in rows) {
      final created = localDateTimeOfDay(x.day, hour: x.hour, minute: x.minute);
      b.insert(
        db.expenses,
        ExpensesCompanion.insert(
          pocketId: pocket,
          categoryId: idByName[_catNames[x.catId]]!,
          amount: x.amount * 100,
          day: x.day,
          note: Value(x.note),
          createdAt: Value(created),
          updatedAt: Value(created),
        ),
      );
    }
  });
  return (pocketId: pocket, count: rows.length);
}
