import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The expense that Add or Edit expense saved last.
typedef SavedExpense = ({int id, int pocketId, int day});

/// Holds the last saved expense, so Home can switch to that expense's month
/// ("Saving switches Home to that expense's month"): `HomeMonthNotifier`
/// (features/home/home_state.dart) listens and shows `day`'s month.
class LastSavedExpense extends Notifier<SavedExpense?> {
  @override
  SavedExpense? build() => null;

  void saved(SavedExpense expense) => state = expense;
}

final lastSavedExpenseProvider = NotifierProvider<LastSavedExpense, SavedExpense?>(
  LastSavedExpense.new,
);
