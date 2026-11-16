import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';

import 'test_db.dart';

/// A paragraph that is cut, in words: ended with "..." or by the line limit
/// (`didExceedMaxLines`), or with letters past its right edge (clipped).
/// Null when the whole text shows.
String? cutReason(RenderParagraph paragraph) {
  final plain = paragraph.text.toPlainText();
  if (paragraph.didExceedMaxLines) {
    return '"$plain" went past its line limit (shown cut)';
  }
  for (var i = 0; i < plain.length; i++) {
    if (plain[i].trim().isEmpty) continue;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (boxes.any((b) => b.right > paragraph.size.width + 0.5)) {
      return '"$plain" has letters past its right edge (clipped)';
    }
  }
  return null;
}

/// Every cut text under [within] (the whole screen when null).
List<String> cutTexts(WidgetTester tester, {Finder? within}) {
  final all = within == null
      ? find.byType(RichText)
      : find.descendant(of: within, matching: find.byType(RichText));
  return <String>[
    for (final element in all.evaluate())
      if (element.renderObject case final RenderParagraph p)
        if (cutReason(p) case final String why) why,
  ];
}

/// The texts under [within] that paint outside [bounds] (their box, after any
/// scaling, is wider or taller than the room). [slack] px of rounding.
List<String> textsOutside(
  WidgetTester tester,
  Finder within,
  Rect bounds, {
  double slack = 0.5,
}) {
  final out = <String>[];
  final room = bounds.inflate(slack);
  for (final element in find
      .descendant(of: within, matching: find.byType(RichText))
      .evaluate()) {
    final p = element.renderObject;
    if (p is! RenderParagraph) continue;
    final rect = MatrixUtils.transformRect(
      p.getTransformTo(null),
      Offset.zero & p.size,
    );
    if (!room.contains(rect.topLeft) || !room.contains(rect.bottomRight)) {
      out.add('"${p.text.toPlainText()}" at $rect is outside $bounds');
    }
  }
  return out;
}

/// A pocket (the default one, id 1) holding one expense on the first of each
/// month, so the screens show big, exact figures. [spent] is October 2026
/// (to the 18th, the mockup's today) and [spentCents] the cents on it;
/// [before] is September 2026's first; [monthly], if given, the amount for
/// every month from January 2025 to August 2026. In whole currency units.
Future<AppDatabase> bigSpendDatabase(
  WidgetTester tester, {
  required int spent,
  required int before,
  int? monthly,
  int spentCents = 0,
}) async {
  final db = openTestDatabase();
  await tester.runAsync(() async {
    ExpenseDraft draft(int year, int month, int whole, [int cents = 0]) => ExpenseDraft(
      pocketId: 1,
      categoryId: 1,
      amount: whole * 100 + cents,
      day: dayOf(year, month, 1),
      createdAt: localDateTimeOfDay(dayOf(year, month, 1), hour: 9, minute: 0),
    );
    final drafts = <ExpenseDraft>[
      if (monthly != null)
        for (var i = 0; i < 20; i++)
          draft(2025 + (i ~/ 12), 1 + i % 12, monthly),
      draft(2026, 9, before),
      draft(2026, 10, spent, spentCents),
    ];
    await ExpensesRepo(db).addAll(drafts);
  });
  return db;
}
