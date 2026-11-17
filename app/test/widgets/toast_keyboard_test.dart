import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/toast.dart';

/// A toast shown while the keyboard is up must sit above the keyboard, not
/// behind it (phone test 2026-11-17: "You already have a pocket called
/// personal" was hidden, so Save seemed to do nothing).
void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AppColors.of(Mood.aqua)]),
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    return ctx;
  }

  testWidgets('with the keyboard up the toast sits above it', (tester) async {
    tester.view.physicalSize = const Size(720, 1582);
    tester.view.devicePixelRatio = 2;
    // A 300 dp keyboard and a 48 dp three-button bar.
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    tester.view.viewPadding = const FakeViewPadding(bottom: 96);
    tester.view.padding = const FakeViewPadding(bottom: 0);
    addTearDown(tester.view.reset);
    final ctx = await pumpHost(tester);
    showToast(ctx, 'You already have a pocket called personal');
    await tester.pumpAndSettle();
    final toast = tester.getRect(find.text('You already have a pocket called personal'));
    const keyboardTop = 791 - 300;
    expect(toast.bottom, lessThan(keyboardTop));
    hideToast();
    await tester.pump();
  });

  testWidgets('without a keyboard it stays just above the bottom bar', (tester) async {
    tester.view.physicalSize = const Size(720, 1582);
    tester.view.devicePixelRatio = 2;
    tester.view.viewPadding = const FakeViewPadding(bottom: 96);
    addTearDown(tester.view.reset);
    final ctx = await pumpHost(tester);
    showToast(ctx, 'Saved');
    await tester.pumpAndSettle();
    final toast = tester.getRect(find.ancestor(of: find.text('Saved'), matching: find.byType(Container)).first);
    // 88 above the 48 dp bar, as before.
    expect(toast.bottom, closeTo(791 - 48 - 88, 0.5));
    hideToast();
    await tester.pump();
  });
}
