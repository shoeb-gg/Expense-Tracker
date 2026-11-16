// A wrapped quiet text (a row's subtitle, a centred note, a hint) never leaves
// one word alone on its last line, at the largest text size and at any width
// the widget can have. The real font; the text is swept from a narrow to a
// wide column.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/features/data/data_parts.dart' show ChoiceRow;
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/symbols.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/shots.dart' show loadShotFonts;
import '../support/text_cut.dart';

void main() {
  setUpAll(loadShotFonts);

  /// [child] in a column [width] wide, at the largest text size.
  Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Mood.aqua),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScaleSteps.last)),
          child: app!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Sweeps [build] over column widths and checks the last line of [text].
  Future<void> expectNoLoneLastWord(
    WidgetTester tester,
    String text,
    Widget Function() build, {
    double from = 200,
    double to = 328,
  }) async {
    var wrapped = 0;
    for (var width = from; width <= to; width += 4) {
      await pumpAt(tester, width, build());
      final words = lastLineWords(tester, noteText(text));
      expect(words.length, greaterThanOrEqualTo(2), reason: '"$text" at $width wide: last line $words');
      if (tester.getSize(noteText(text)).height > 30) wrapped++;
    }
    // The sweep did reach widths where the text wraps.
    expect(wrapped, greaterThan(3), reason: '"$text" never wrapped');
  }

  testWidgets('a centred note', (tester) async {
    const text = 'Nothing leaves this phone unless you share it.';
    await expectNoLoneLastWord(
      tester,
      text,
      () => const CenteredNote(text, style: TextStyle(fontSize: 13, height: 20 / 13)),
      from: 160,
    );
  });

  testWidgets('a wrapping list row: the subtitle', (tester) async {
    const text = 'Frees up space. Your expenses stay.';
    await expectNoLoneLastWord(
      tester,
      text,
      () => const ListRow(title: 'Clear photos', subtitle: text, wrap: true, divider: false),
    );
  });

  testWidgets('a list row that does not wrap keeps its text as it is', (tester) async {
    const text = 'Frees up space. Your expenses stay.';
    await pumpAt(tester, 300, const ListRow(title: 'Clear photos', subtitle: text, divider: false));
    expect(find.text(text), findsOneWidget);
  });

  testWidgets('a choice row: the subtitle', (tester) async {
    for (final text in ['Plain text, opens in almost any app', 'Opens in Excel and Google Sheets']) {
      await expectNoLoneLastWord(
        tester,
        text,
        () => ChoiceRow(title: 'CSV (.csv)', subtitle: text, selected: false, onTap: () {}),
      );
    }
  });

  testWidgets('a message card: the message', (tester) async {
    const text = 'Swipe or pick another month.';
    await expectNoLoneLastWord(
      tester,
      text,
      () => const MessageCard(
        icon: Symbols.receipt_long_rounded,
        title: 'Nothing spent in September',
        message: text,
      ),
    );
  });

  testWidgets('a docked bar: the hint', (tester) async {
    const text = 'Nothing is added until the last step.';
    await expectNoLoneLastWord(
      tester,
      text,
      () => const DockedBar(hint: text, child: SizedBox(height: 52)),
    );
  });

  testWidgets('two long words are not joined', (tester) async {
    // The last two words together are longer than 18 characters, so they may
    // split, and a long word is never pushed into a line it does not fit.
    const text = 'Your spending categories uncategorised transactions';
    await pumpAt(tester, 200, const CenteredNote(text, style: TextStyle(fontSize: 13, height: 20 / 13)));
    expect(tester.takeException(), isNull);
    expect(find.text(text), findsOneWidget);
  });
}
