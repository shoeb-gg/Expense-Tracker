import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/symbols.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/shots.dart';

/// A bare screen with a [NowPill] at the right and a switch to show or hide
/// it. [taps] counts its taps.
class _Harness {
  final ValueNotifier<bool> visible = ValueNotifier<bool>(false);
  int taps = 0;

  Future<void> pump(
    WidgetTester tester, {
    bool initiallyVisible = false,
    double scale = 1,
    String label = 'This month',
  }) async {
    visible.value = initiallyVisible;
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Mood.aqua),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (context, on, _) => NowPill(
                  visible: on,
                  label: label,
                  semanticLabel: 'Back to this month',
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(NowPill),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

double _scale(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.descendant(
        of: find.byType(NowPill),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

void main() {
  setUpAll(loadShotFonts);

  testWidgets('hidden: nothing in the tree, no room taken', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    expect(find.text('This month'), findsNothing);
    expect(find.byType(Pill), findsNothing);
    expect(tester.getSize(find.byType(NowPill)), Size.zero);
  });

  testWidgets('fades and scales in over 200 ms, and out again', (tester) async {
    final h = _Harness();
    await h.pump(tester);

    h.visible.value = true;
    await tester.pump();
    expect(_opacity(tester), 0);
    expect(_scale(tester), closeTo(0.8, 0.001));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester), allOf(greaterThan(0.2), lessThan(1)));
    expect(_scale(tester), allOf(greaterThan(0.8), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester), 1);
    expect(_scale(tester), 1);
    expect(find.text('This month'), findsOneWidget);

    h.visible.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester), allOf(greaterThan(0), lessThan(1)));
    expect(find.text('This month'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('This month'), findsNothing);
    expect(tester.getSize(find.byType(NowPill)), Size.zero);
  });

  testWidgets('a tap calls onTap; it cannot be tapped while it fades out',
      (tester) async {
    final h = _Harness();
    await h.pump(tester, initiallyVisible: true);
    await tester.tap(find.text('This month'));
    await tester.pump();
    expect(h.taps, 1);

    h.visible.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('This month'), findsOneWidget);
    await tester.tap(find.text('This month'), warnIfMissed: false);
    await tester.pump();
    expect(h.taps, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('a screen reader finds it by its label, once', (tester) async {
    final handle = tester.ensureSemantics();
    final h = _Harness();
    await h.pump(tester, initiallyVisible: true);
    expect(find.semantics.byLabel('Back to this month'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Back to this month')),
      matchesSemantics(
        label: 'Back to this month',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: false,
      ),
    );

    // While it fades out and once it is gone, readers do not see it.
    h.visible.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.semantics.byLabel('Back to this month'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.semantics.byLabel('Back to this month'), findsNothing);
    handle.dispose();
  });

  testWidgets('an accent pill with a calendar icon', (tester) async {
    final h = _Harness();
    await h.pump(tester, initiallyVisible: true);
    await tester.pumpAndSettle();
    final pill = tester.widget<Pill>(find.byType(Pill));
    expect(pill.tone, PillTone.accent);
    expect(pill.height, 32);
    expect(find.byIcon(Symbols.calendar_month_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(Pill)).height, 32);
  });

  group('fits at every text size', () {
    for (final scale in textScaleSteps) {
      for (final label in ['Today', 'This week', 'This month', 'This year']) {
        testWidgets('"$label" at $scale', (tester) async {
          final h = _Harness();
          await h.pump(tester, initiallyVisible: true, scale: scale, label: label);
          await tester.pumpAndSettle();
          final text = tester.renderObject<RenderParagraph>(find.text(label));
          expect(text.didExceedMaxLines, isFalse);
          expect(
            text.size.width,
            greaterThanOrEqualTo(text.getMaxIntrinsicWidth(double.infinity)),
          );
          final pill = tester.getRect(find.byType(Pill));
          expect(pill.right, 360 - 16);
          expect(pill.left, greaterThan(180), reason: 'a small pill');
          expect(tester.getRect(find.text(label)).left, greaterThan(pill.left));
          expect(tester.getRect(find.text(label)).right, lessThan(pill.right));
        });
      }
    }
  });
}
