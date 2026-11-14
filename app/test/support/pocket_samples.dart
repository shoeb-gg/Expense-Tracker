import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';

/// Ids of the two extra pockets the Pockets boards show.
typedef MockupPockets = ({int business, int trip});

// Seeded category ids (insertion order of the 15 defaults).
const int _groceries = 1;
const int _snacks = 2;
const int _transport = 3;
const int _shopping = 4;
const int _internet = 7;
const int _phone = 8;
const int _gifts = 14;
const int _misc = 15;

/// Adds the mockup's other pockets next to "Personal":
/// * 💼 Business: 214 expenses, 18,240 in October 2026;
/// * 🏖️ Family trip: 37 expenses, 6,300 in October 2026.
///
/// In widget tests call it inside `tester.runAsync`.
Future<MockupPockets> addMockupPockets(AppDatabase db) async {
  final pockets = PocketsRepo(db);
  final expenses = ExpensesRepo(db);
  final business = await pockets.add(name: 'Business', emoji: '💼');
  final trip = await pockets.add(name: 'Family trip', emoji: '🏖️');

  ExpenseDraft draft(
    int pocketId,
    int categoryId,
    int whole,
    int day,
    String note,
    int minute,
  ) => ExpenseDraft(
    pocketId: pocketId,
    categoryId: categoryId,
    amount: whole * 100,
    day: day,
    note: note,
    createdAt: localDateTimeOfDay(day, hour: 9, minute: minute),
  );

  final drafts = <ExpenseDraft>[];

  // Business, October 2026: 10 expenses = 18,240.
  const businessOctober = <(int, int, int, String)>[
    (17, _shopping, 4500, 'Office chairs'),
    (16, _internet, 3200, 'Office broadband'),
    (15, _misc, 2750, 'Printer repair'),
    (13, _transport, 1980, 'Client visit'),
    (12, _phone, 1640, 'Work phone'),
    (9, _shopping, 1250, 'Stationery'),
    (7, _snacks, 980, 'Team lunch'),
    (5, _transport, 840, 'Courier'),
    (3, _snacks, 650, 'Tea for the office'),
    (1, _misc, 450, ''),
  ];
  for (final (d, cat, whole, note) in businessOctober) {
    drafts.add(draft(business, cat, whole, dayOf(2026, 10, d), note, d));
  }
  // Business, before October: 204 more, two or three a week back to 2025.
  final businessCats = [_shopping, _transport, _phone, _internet, _snacks];
  var day = dayOf(2026, 9, 29);
  for (var i = 0; i < 204; i++) {
    drafts.add(
      draft(
        business,
        businessCats[i % businessCats.length],
        300 + (i * 137) % 2200,
        day,
        i % 4 == 0 ? '' : 'Work expense ${i + 1}',
        i % 60,
      ),
    );
    day -= 2 + i % 2;
  }

  // Family trip, October 2026: 4 expenses = 6,300.
  const tripOctober = <(int, int, int, String)>[
    (11, _transport, 3000, 'Train tickets'),
    (11, _groceries, 600, 'Picnic food'),
    (10, _shopping, 1800, 'Beach gear'),
    (10, _gifts, 900, 'Souvenirs'),
  ];
  var minute = 0;
  for (final (d, cat, whole, note) in tripOctober) {
    drafts.add(draft(trip, cat, whole, dayOf(2026, 10, d), note, minute++));
  }
  // Family trip, before October: 33 more in August and September.
  day = dayOf(2026, 9, 28);
  for (var i = 0; i < 33; i++) {
    drafts.add(
      draft(
        trip,
        [_transport, _groceries, _shopping][i % 3],
        200 + (i * 91) % 1500,
        day,
        'Trip expense ${i + 1}',
        i,
      ),
    );
    day -= 1 + i % 3;
  }

  await expenses.addAll(drafts);
  return (business: business, trip: trip);
}
