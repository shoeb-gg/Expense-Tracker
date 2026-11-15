// Kit pop-ups measured with the real app font against their boards
// (a 312 px card centred on a 360 px screen; PopMonth / PopDate have
// padding 16, so their content runs from x 40 to x 320).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/symbols.dart';
import 'package:spill_the_bills/theme/text.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/shots.dart' show loadShotFonts;
import 'pickers_test.dart' show pumpBare;

void main() {
  setUpAll(loadShotFonts);

  group('pop-up navigation row', () {
    testWidgets('month pop-up: the year arrows sit at the right content edge', (
      tester,
    ) async {
      final ctx = await pumpBare(tester);
      unawaited(showMonthPicker(ctx, year: 2026, month: 10));
      await tester.pumpAndSettle();

      final prev = tester.getRect(find.bySemanticsLabel('Previous year'));
      final next = tester.getRect(find.bySemanticsLabel('Next year'));
      expect(next.right, 320);
      expect(prev.right, next.left);
      expect(prev.left, 240);
    });

    testWidgets('date pop-up: the month name is shown in full', (
      tester,
    ) async {
      final ctx = await pumpBare(tester);
      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 12)));
      await tester.pumpAndSettle();

      final label = tester.renderObject<RenderParagraph>(
        find.text('October 2026'),
      );
      expect(label.didExceedMaxLines, isFalse);
      // PopDate draws the month name with proportional figures.
      expect(tester.widget<Text>(find.text('October 2026')).style!.fontFeatures,
          isNull);
      expect(tester.getRect(find.bySemanticsLabel('Next month')).right, 320);

      // The longest month name fits too.
      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 9, 12)));
      await tester.pumpAndSettle();
      final september = tester.renderObject<RenderParagraph>(
        find.text('September 2026'),
      );
      expect(september.didExceedMaxLines, isFalse);
    });
  });

  testWidgets('emoji tiles ask for the emoji font, not the app font', (
    tester,
  ) async {
    // Plus Jakarta Sans has a plain ▶ that would win over the colour ▶️.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Mood.aqua),
        home: const Center(child: EmojiTile(emoji: '▶️')),
      ),
    );
    final style = tester.widget<Text>(find.text('▶️')).style!;
    expect(style.fontFamily, kEmojiFontFamily);
    expect(AppText.emoji.fontFamily, kEmojiFontFamily);
  });

  testWidgets('not-found card: Home\'s empty card at the top of the body', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Mood.aqua),
        home: const Scaffold(
          body: Column(
            children: [
              Expanded(
                child: NotFoundCard(
                  thing: 'Pocket',
                  icon: Symbols.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Pocket not found'), findsOneWidget);
    expect(find.text('It may have been deleted.'), findsOneWidget);
    final card = tester.getRect(find.byType(MessageCard));
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    // Full width less the 16 px gutters, 2 px under the header, and only
    // as tall as its content (padding 24, tile 44, title, line).
    expect(card.left, 16);
    expect(card.right, width - 16);
    expect(card.top, 2);
    expect(card.height, 24 + 44 + 12 + 20 + 4 + 20 + 24);
    final tile = tester.getRect(find.byType(IconTile));
    expect(tile.size, const Size(44, 44));
    expect(tile.center.dx, card.center.dx);
    expect(tile.top, card.top + 24);
  });

  group('pop-up buttons', () {
    /// Pumps an empty app whose text is scaled by [scale] (the app's Text
    /// size setting does the same) and opens a dialog with [action].
    Future<void> open(WidgetTester tester, String action, double scale) async {
      tester.view.physicalSize = const Size(720, 1560);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(Mood.aqua),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(body: SizedBox.expand(key: Key('home'))),
          ),
        ),
      );
      unawaited(
        showAppDialog(
          tester.element(find.byKey(const Key('home'))),
          title: "Can't use this file",
          boldLine: 'receipt.pdf',
          actionLabel: action,
        ),
      );
      await tester.pumpAndSettle();
    }

    Rect button(WidgetTester tester, String label) => tester.getRect(
      find.ancestor(of: find.text(label), matching: find.byType(Pressable)).first,
    );

    /// The label is on one line, inside its button with at least 12 px on
    /// each side.
    void fits(WidgetTester tester, String label) {
      final text = find.text(label);
      expect(tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse);
      final box = button(tester, label);
      final ink = tester.getRect(text);
      expect(ink.left - box.left, greaterThanOrEqualTo(12), reason: label);
      expect(box.right - ink.right, greaterThanOrEqualTo(12), reason: label);
      expect(ink.height, lessThan(box.height), reason: label);
    }

    testWidgets('two equal columns when both labels fit (the boards)', (
      tester,
    ) async {
      await open(tester, 'Delete pocket', 1);
      final cancel = button(tester, 'Cancel');
      final action = button(tester, 'Delete pocket');
      expect(cancel.width, 130);
      expect(action.width, 130);
      expect(action.top, cancel.top);
      expect(action.height, 48);
      expect(action.left - cancel.right, 12);
      fits(tester, 'Delete pocket');
    });

    testWidgets('a long label gets the room it needs on the same row', (
      tester,
    ) async {
      await open(tester, 'Choose another', 1);
      final cancel = button(tester, 'Cancel');
      final action = button(tester, 'Choose another');
      expect(action.top, cancel.top);
      expect(action.height, 48);
      expect(action.width, greaterThan(cancel.width));
      expect(cancel.left, 44);
      expect(action.right, 316);
      expect(action.left - cancel.right, 12);
      fits(tester, 'Choose another');
      fits(tester, 'Cancel');
    });

    testWidgets('largest text size: nothing is clipped', (tester) async {
      await open(tester, 'Choose another', 19 / 15);
      // Too wide for one row: the action goes on top, Cancel under it.
      final cancel = button(tester, 'Cancel');
      final action = button(tester, 'Choose another');
      expect(action.width, 272);
      expect(cancel.width, 272);
      expect(cancel.top - action.bottom, 12);
      fits(tester, 'Choose another');
      fits(tester, 'Cancel');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // A shorter pair still shares the row, by need.
      await open(tester, 'Delete pocket', 19 / 15);
      expect(
        button(tester, 'Delete pocket').top,
        button(tester, 'Cancel').top,
      );
      fits(tester, 'Delete pocket');
      fits(tester, 'Cancel');
    });
  });

  group('dialog bold line', () {
    testWidgets('proportional figures by default (expense delete board)', (
      tester,
    ) async {
      final ctx = await pumpBare(tester);
      unawaited(
        showAppDialog(
          ctx,
          title: 'Delete this expense?',
          boldLine: 'Doctor visit · 1,180',
          actionLabel: 'Delete',
          destructive: true,
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.text('Doctor visit · 1,180');
      expect(tester.widget<Text>(finder).style!.fontFeatures, isNull);
    });

    testWidgets('tabular figures on request (pocket delete board)', (
      tester,
    ) async {
      final ctx = await pumpBare(tester);
      unawaited(
        showAppDialog(
          ctx,
          title: 'Delete Trip?',
          boldLine: 'Also deletes 12 expenses and photos',
          boldTabular: true,
          actionLabel: 'Delete pocket',
          destructive: true,
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.text('Also deletes 12 expenses and photos');
      expect(
        tester.widget<Text>(finder).style!.fontFeatures,
        const [FontFeature.tabularFigures()],
      );
    });
  });
}
