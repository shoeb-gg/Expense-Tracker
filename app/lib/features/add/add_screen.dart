import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show FileSystemException;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/calculator.dart';
import '../../core/days.dart';
import '../../core/format.dart';
import '../../core/type_to_add.dart';
import '../../data/db.dart';
import '../../data/photo_store.dart';
import '../../router.dart';
import '../../state/budgets.dart';
import '../../state/pocket_line.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import '../expense/photo_screen.dart';
import '../expense/receipt.dart';
import 'add_events.dart';
import 'add_logic.dart';
import 'category_grid.dart';
import 'keypad_panel.dart';
import 'photo_picker.dart';
import 'pocket_parts.dart';
import 'quick_area.dart';

/// Add expense (`/add?day=`) and Edit expense (`/expense/:id/edit`, with
/// [expenseId]). [day] preselects the date (Calendar's "Add expense on").
///
/// Add opens with nothing chosen: tap a category to get the keypad, or type
/// in the bar at the bottom ("coffee 120"). Edit opens on the keypad,
/// prefilled.
class AddScreen extends ConsumerStatefulWidget {
  const AddScreen({super.key, this.day, this.expenseId});

  final int? day;
  final int? expenseId;

  @override
  ConsumerState<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends ConsumerState<AddScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _note = TextEditingController();
  final TextEditingController _typed = TextEditingController();
  final FocusNode _noteFocus = FocusNode();
  final FocusNode _typedFocus = FocusNode();

  /// Makes the tile outlines flash twice, to show where to tap.
  late final AnimationController _flash;
  late final Animation<double> _flashLevel;

  late int _day;

  /// The day the screen opened on, to tell whether the user changed it.
  late final int _initialDay;

  /// Category of the keypad (null: the opening state with type to add).
  int? _picked;

  /// Category tapped on the grid for the typed expense.
  int? _quickPick;
  String _expr = '';

  /// Receipt photo file name.
  String? _photo;

  /// Pocket chosen with the pill (null: the pocket the user is in).
  int? _pocketId;

  /// The expense being edited.
  Expense? _original;
  bool _loading = false;
  bool _missing = false;
  bool _busy = false;
  bool _saved = false;

  /// The "Discard?" question is showing.
  bool _asking = false;

  /// Whether the last build found something entered (see [_dirty]).
  bool _wasDirty = false;

  /// How tall the opening state's bottom area (card and typing bar) really
  /// is, without the bottom inset: the card grows when its hint wraps in
  /// large text. 0 until the first layout.
  double _quickHeight = 0;

  /// Photos picked on this screen, removed again unless saved.
  final Set<String> _newPhotos = {};
  PhotoStore? _store;

  bool get _isEdit => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _flashLevel = TweenSequence<double>([
      for (var i = 0; i < 2; i++) ...[
        TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 1),
        TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 1),
      ],
    ]).animate(_flash);
    _noteFocus.addListener(_onNoteFocus);
    _note.addListener(_onNoteChanged);
    _day = widget.day ?? ref.read(todayProvider);
    _initialDay = _day;
    if (_isEdit) {
      _loading = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final id = widget.expenseId ?? -1;
    final expense = id < 0 ? null : await ref.read(expensesRepoProvider).get(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (expense == null) {
        _missing = true;
        return;
      }
      _original = expense;
      _picked = expense.categoryId;
      _expr = minorToKeypad(expense.amount);
      _note.text = expense.note;
      _day = expense.day;
      _photo = expense.photoPath;
      _pocketId = expense.pocketId;
    });
  }

  @override
  void dispose() {
    final store = _store;
    if (store != null) {
      final keep = _saved ? _photo : null;
      for (final name in _newPhotos) {
        if (name != keep) unawaited(_quietly(store.delete(name)));
      }
    }
    _noteFocus.removeListener(_onNoteFocus);
    _note.removeListener(_onNoteChanged);
    _flash.dispose();
    _note.dispose();
    _typed.dispose();
    _noteFocus.dispose();
    _typedFocus.dispose();
    super.dispose();
  }

  void _onQuickHeight(double height) {
    if (mounted && height != _quickHeight) setState(() => _quickHeight = height);
  }

  /// The title field gained or lost focus: the keys fold away or come back.
  void _onNoteFocus() {
    if (mounted) setState(() {});
  }

  /// Typing a title starts or ends "something entered" without another
  /// screen update, so Back needs one to know.
  void _onNoteChanged() {
    if (mounted && !_loading && _dirty != _wasDirty) setState(() {});
  }

  /// Whether leaving now would lose something the user entered or changed.
  bool get _dirty {
    if (_isEdit && _original == null) return false;
    return hasUnsavedInput(
      original: _original,
      expr: _expr,
      title: _note.text,
      categoryId: _picked,
      photo: _photo,
      day: _day,
      initialDay: _initialDay,
      pocketId: _pocketId,
      currentPocketId: ref.read(currentPocketIdProvider),
      typed: _typed.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = _isEdit ? 'Edit expense' : 'Add expense';
    final categories = ref.watch(categoriesProvider).value ?? const <ExpenseCategory>[];
    if (_loading || _missing || (_isEdit && categories.isEmpty)) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _EditorHeader(title: title, onCancel: _close),
              Expanded(child: _missing ? const MissingExpense() : const SizedBox.expand()),
            ],
          ),
        ),
      );
    }
    final byId = {for (final cat in categories) cat.id: cat};
    final learned = ref.watch(learnedWordsProvider).value ?? const <String, int>{};
    final fmt = ref.watch(amountFormatProvider);
    final today = ref.watch(todayProvider);
    final fourKeys = ref.watch(settingsProvider.select((s) => s.calcKeys)) == CalcKeys.allFour;
    final pockets = ref.watch(pocketsProvider).value ?? const <Pocket>[];
    final currentPocket = ref.watch(currentPocketProvider);

    final keypadCategory = _picked == null ? null : byId[_picked];
    final keypadMode = keypadCategory != null;
    final parsed = parseTypeToAdd(
      _typed.text,
      categories: [for (final cat in categories) (id: cat.id, name: cat.name)],
      learned: learned,
      format: fmt,
    );
    final quick = quickView(
      text: _typed.text,
      parsed: parsed,
      validIds: byId.keys.toSet(),
      manualPick: _quickPick,
    );
    final quickCategory = quick.categoryId == null ? null : byId[quick.categoryId];
    final unknown = !keypadMode && quick.stage == QuickStage.unknown;
    final hint = keypadMode || quickCategory == null ? null : quick.hint(quickCategory.name);
    final dateLabel = shortDayLabel(_day, today);

    final targetId = _pocketId ?? currentPocket?.id;
    Pocket? target;
    for (final p in pockets) {
      if (p.id == targetId) target = p;
    }
    final pill = pocketWhenSeveral(pockets, target);
    // Rings show the pocket this expense goes into, in the month of its date.
    final budgets = targetId == null
        ? const <int, BudgetUse>{}
        : ref.watch(
            budgetUsesProvider((pocketId: targetId, monthStart: monthStartOfDay(_day))),
          );

    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final navInset = keyboard > 0 ? 0.0 : mq.viewPadding.bottom;
    // Typing the title on the keypad: the keys fold away, so the panel sits
    // on the keyboard without covering the header.
    final typingTitle = keypadMode && keyboard > 0 && _noteFocus.hasFocus;
    double reserveFor(double collapse) =>
        (keypadMode
            ? KeypadPanel.height - KeypadPanel.keysHeight * collapse
            // The card grows by its "Next time" line, or by the prompt of
            // a typed word that has no category yet; and, in large text,
            // by a hint that wraps (the measured height, when it is more).
            : math.max(hint == null && !unknown ? 162.0 : 198.0, _quickHeight)) +
        navInset +
        keyboard;

    final grid = AnimatedBuilder(
      animation: _flashLevel,
      builder: (context, _) {
        final base = unknown ? 0x73 / 0xFF : 0.0;
        return CategoryGrid(
          categories: categories,
          selectedId: keypadMode ? _picked : quick.categoryId,
          outline: base + (1 - base) * _flashLevel.value,
          budgets: budgets,
          onTap: (cat) => _onTile(cat, quick),
          onManage: () => unawaited(context.push(Routes.categories)),
        );
      },
    );

    Widget buildContent(double reserve) => LayoutBuilder(
      builder: (context, box) {
        final rows = ((categories.length + 1) / CategoryGrid.columns).ceil();
        final height = 8 + rows * 84;
        // When everything fits, nothing scrolls, so the glow of a selected
        // tile in the first row may spread past the top, as on the board.
        final fits = height + reserve <= box.maxHeight + 0.5;
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            clipBehavior: fits ? Clip.none : Clip.hardEdge,
            padding: EdgeInsets.only(bottom: reserve),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [grid]),
          ),
        );
      },
    );

    Widget buildKeypad(ExpenseCategory category, double collapse) {
      return KeypadPanel(
        key: const ValueKey('keypad'),
        category: category,
        view: keypadView(_expr, fmt),
        note: _note,
        noteFocus: _noteFocus,
        photoButtons: [
          if (_photo == null)
            RoundIconButton(
              icon: Symbols.photo_camera_rounded,
              semanticLabel: 'Take a receipt photo',
              background: Colors.transparent,
              color: c.text2,
              onTap: () => unawaited(_pickPhoto(PhotoSource.camera)),
            )
          else
            _thumbButton(Colors.transparent),
          RoundIconButton(
            icon: Symbols.image_rounded,
            semanticLabel: 'Attach a photo from the gallery',
            background: Colors.transparent,
            color: c.text2,
            onTap: () => unawaited(_pickPhoto(PhotoSource.gallery)),
          ),
        ],
        fourKeys: fourKeys,
        dateLabel: dateLabel,
        onChip: _onChip,
        onKey: _onKey,
        onClear: () => setState(() => _expr = ''),
        onDate: () => unawaited(_pickDate()),
        onSave: () => unawaited(_saveKeypad()),
        bottomInset: navInset,
        collapse: collapse,
      );
    }

    final Widget card = switch (quick.stage) {
      QuickStage.empty => const GuideCard(
        icon: Symbols.touch_app_rounded,
        title: 'Select a category',
        subtitle: 'Tap one above, or just type below',
        joinLastWords: true,
      ),
      QuickStage.wordOnly => GuideCard(
        icon: Symbols.dialpad_rounded,
        title: 'Now add the amount',
        subtitle: 'Like “${_typed.text.trim()} 120”',
      ),
      QuickStage.matched || QuickStage.unknown => PreviewCard(
        category: quickCategory,
        subtitle: parsed.title.isEmpty ? dateLabel : '${parsed.title} · $dateLabel',
        amount: fmt.formatExact(parsed.amount ?? 0),
        onCategoryTap: _pointAtGrid,
        word: parsed.title.toLowerCase(),
        hint: hint,
      ),
    };
    final Widget quickBottom = QuickArea(
      key: const ValueKey('quick'),
      card: card,
      bottomInset: navInset,
      onHeight: _onQuickHeight,
      bar: TypingBar(
        controller: _typed,
        focusNode: _typedFocus,
        onChanged: _onTyped,
        photoButton: _photo == null
            ? RoundIconButton(
                icon: Symbols.photo_camera_rounded,
                semanticLabel: 'Take a receipt photo',
                background: c.surface2,
                color: c.text2,
                onTap: () => unawaited(_pickPhoto(PhotoSource.camera)),
              )
            : _thumbButton(c.surface2),
        addState: _typed.text.trim().isEmpty
            ? AddButtonState.hidden
            : quick.stage == QuickStage.matched
            ? AddButtonState.ready
            : AddButtonState.waiting,
        onAdd: () => unawaited(_addTyped(quick)),
      ),
    );

    final dirty = _dirty;
    _wasDirty = dirty;
    return PopScope(
      canPop: _saved || !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: c.bg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: typingTitle ? 1 : 0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, collapse, _) => Stack(
              children: [
                Column(
                  children: [
                    _EditorHeader(
                      title: title,
                      onCancel: _close,
                      pill: pill == null
                          ? null
                          : PocketPill(
                              pocket: pill,
                              semanticLabel: _isEdit
                                  ? 'This expense is in the pocket ${pill.name}. '
                                        'Tap to move it to another pocket'
                                  : 'This expense will be saved in the pocket ${pill.name}. '
                                        'Tap to choose another pocket',
                              onTap: () => unawaited(_choosePocket(pockets, pill.id)),
                            ),
                    ),
                    Expanded(child: buildContent(reserveFor(collapse))),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: keyboard,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.bottomCenter, children: [...previous, ?current]),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.12),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: keypadCategory == null
                        ? quickBottom
                        : buildKeypad(keypadCategory, collapse),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The receipt thumbnail in place of the camera button.
  Widget _thumbButton(Color background) {
    final name = _photo;
    if (name == null) return const SizedBox.shrink();
    return SizedBox.square(
      dimension: 40,
      child: Pressable(
        onTap: () => unawaited(_openPhotoSheet()),
        semanticLabel: 'Receipt photo attached, tap to view or replace',
        color: background,
        borderRadius: BorderRadius.circular(20),
        child: Center(child: ReceiptThumb(fileName: name, size: 28, radius: 8)),
      ),
    );
  }

  void _onTyped(String text) {
    setState(() {
      if (text.trim().isEmpty) _quickPick = null;
    });
  }

  void _onTile(ExpenseCategory cat, QuickView quick) {
    setState(() {
      if (_isEdit) {
        _picked = cat.id;
        return;
      }
      if (_picked != null) {
        // Keypad: another tile switches, the same tile goes back to the
        // opening state.
        _picked = _picked == cat.id ? null : cat.id;
        return;
      }
      switch (quick.stage) {
        case QuickStage.matched || QuickStage.unknown:
          _quickPick = cat.id;
        case QuickStage.wordOnly:
          // Words but no amount: carry the words over as the title and
          // finish on the keypad.
          if (_note.text.trim().isEmpty) _note.text = quick.parsed.title;
          _typed.clear();
          _quickPick = null;
          _picked = cat.id;
          _typedFocus.unfocus();
        case QuickStage.empty:
          _picked = cat.id;
          _typedFocus.unfocus();
      }
    });
  }

  void _onChip() {
    if (_isEdit) {
      _pointAtGrid();
    } else {
      setState(() => _picked = null);
    }
  }

  /// Hides the keyboard and flashes the tile outlines.
  void _pointAtGrid() {
    FocusScope.of(context).unfocus();
    unawaited(_flash.forward(from: 0));
  }

  void _onKey(String key) => setState(() => _expr = applyKeypadKey(_expr, key));

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final day = await showDayPicker(context, initialDay: _day);
    if (day != null && mounted) setState(() => _day = day);
  }

  Future<void> _choosePocket(List<Pocket> pockets, int current) async {
    FocusScope.of(context).unfocus();
    final id = await showPocketSheet(context, pockets: pockets, current: current, move: _isEdit);
    if (id != null && mounted) setState(() => _pocketId = id);
  }

  double get _toastBottom => _picked != null ? 386 : 178;

  Future<void> _pickPhoto(PhotoSource source) async {
    FocusScope.of(context).unfocus();
    final picker = ref.read(photoPickerProvider);
    final store = ref.read(photoStoreProvider);
    _store = store;
    String? path;
    try {
      path = await picker.pick(source);
    } on Object {
      if (mounted) {
        showToast(
          context,
          source == PhotoSource.camera ? "Couldn't open the camera" : "Couldn't open the gallery",
          bottom: _toastBottom,
        );
      }
      return;
    }
    if (path == null) return;
    final String name;
    try {
      name = await store.savePicked(path);
    } on Object {
      if (mounted) showToast(context, "Couldn't save the photo", bottom: _toastBottom);
      return;
    }
    if (!mounted) {
      unawaited(_quietly(store.delete(name)));
      return;
    }
    setState(() => _setPhoto(name));
  }

  void _setPhoto(String? name) {
    final old = _photo;
    final store = _store;
    if (old != null && _newPhotos.remove(old) && store != null) {
      unawaited(_quietly(store.delete(old)));
    }
    _photo = name;
    if (name != null) _newPhotos.add(name);
  }

  Future<void> _openPhotoSheet() async {
    final name = _photo;
    if (name == null) return;
    FocusScope.of(context).unfocus();
    final action = await showReceiptSheet(context, fileName: name);
    if (action == null || !mounted) return;
    switch (action) {
      case ReceiptAction.view:
        await _viewPhoto(name);
      case ReceiptAction.camera:
        await _pickPhoto(PhotoSource.camera);
      case ReceiptAction.gallery:
        await _pickPhoto(PhotoSource.gallery);
      case ReceiptAction.remove:
        setState(() => _setPhoto(null));
    }
  }

  Future<void> _viewPhoto(String name) {
    final fmt = ref.read(amountFormatProvider);
    final categories = ref.read(categoriesByIdProvider);
    int amount;
    String title;
    if (_picked != null) {
      amount = keypadView(_expr, fmt).amount ?? evaluateExpression(_expr) ?? 0;
      title = _note.text.trim();
      title = title.isNotEmpty ? title : (categories[_picked]?.name ?? '');
    } else {
      final parsed = parseTypeToAdd(
        _typed.text,
        categories: [for (final cat in categories.values) (id: cat.id, name: cat.name)],
        learned: ref.read(learnedWordsProvider).value ?? const <String, int>{},
        format: fmt,
      );
      amount = parsed.amount ?? 0;
      final cat = _quickPick ?? parsed.categoryId;
      title = parsed.title.isNotEmpty ? parsed.title : (categories[cat]?.name ?? '');
    }
    return openPhotoViewer(
      context,
      fileName: name,
      title: title,
      caption: photoCaption(_day, amount, fmt),
    );
  }

  Future<void> _saveKeypad() async {
    final amount = keypadView(_expr, ref.read(amountFormatProvider)).amount;
    final category = _picked;
    if (amount == null || category == null) return;
    await _commit(categoryId: category, amount: amount, note: _note.text.trim());
  }

  Future<void> _addTyped(QuickView quick) async {
    if (quick.stage == QuickStage.unknown) {
      _pointAtGrid();
      return;
    }
    final category = quick.categoryId;
    final amount = quick.parsed.amount;
    if (quick.stage != QuickStage.matched || category == null || amount == null) return;
    await _commit(
      categoryId: category,
      amount: amount,
      note: quick.parsed.title,
      learn: quick.wordsToLearn,
    );
  }

  Future<void> _commit({
    required int categoryId,
    required int amount,
    required String note,
    List<String> learn = const [],
  }) async {
    if (_busy) return;
    _busy = true;
    final repo = ref.read(expensesRepoProvider);
    final words = ref.read(learnedWordsRepoProvider);
    final photos = ref.read(photoStoreProvider);
    final events = ref.read(lastSavedExpenseProvider.notifier);
    final pockets = ref.read(pocketsProvider).value ?? const <Pocket>[];
    final currentPocketId = ref.read(currentPocketIdProvider);
    String pocketName(int id) {
      for (final p in pockets) {
        if (p.id == id) return p.name;
      }
      return '';
    }

    try {
      final original = _original;
      if (original != null) {
        final pocketId = _pocketId ?? original.pocketId;
        await repo.update(
          original.copyWith(
            categoryId: categoryId,
            amount: amount,
            note: note,
            day: _day,
            pocketId: pocketId,
            photoPath: Value(_photo),
          ),
        );
        final oldPhoto = original.photoPath;
        if (oldPhoto != null && oldPhoto != _photo) unawaited(_quietly(photos.delete(oldPhoto)));
        _saved = true;
        events.saved((id: original.id, pocketId: pocketId, day: _day));
        if (!mounted) return;
        if (pocketId != original.pocketId) {
          final id = original.id;
          final from = original.pocketId;
          showToast(
            context,
            'Moved to ${pocketName(pocketId)}',
            onUndo: () => unawaited(repo.moveToPocket(id, from)),
          );
        }
      } else {
        final pocketId = _pocketId ?? currentPocketId;
        if (pocketId == null) return;
        final id = await repo.add(
          pocketId: pocketId,
          categoryId: categoryId,
          amount: amount,
          day: _day,
          note: note,
          photoPath: _photo,
        );
        if (learn.isNotEmpty) await words.learnAll(learn, categoryId);
        _saved = true;
        events.saved((id: id, pocketId: pocketId, day: _day));
        if (!mounted) return;
        if (pocketId != currentPocketId) {
          showToast(context, 'Saved in ${pocketName(pocketId)}');
        }
      }
      _leave();
    } finally {
      _busy = false;
    }
  }

  /// Takes focus off the text field that has it, and makes the screen forget
  /// that it had it.
  ///
  /// `FocusScope.of(context).unfocus()` would not do: it only clears the
  /// history of the scope above this screen's, so when a dialog or sheet
  /// closes again the screen's own scope puts focus back on the field, and
  /// the keyboard opens again.
  void _dropFocus() => FocusManager.instance.primaryFocus?.unfocus();

  /// Cancel and Back: asks first when something was entered or changed (a
  /// saved expense never asks).
  ///
  /// Focus goes before the question, so "Keep editing" brings the screen back
  /// exactly as it was, with the keyboard down.
  Future<void> _close() async {
    _dropFocus();
    if (_saved || !_dirty) {
      _leave();
      return;
    }
    if (_asking) return;
    _asking = true;
    final bool discard;
    try {
      discard = await showAppDialog(
        context,
        title: _isEdit ? 'Discard changes?' : 'Discard this expense?',
        quietLine: 'What you entered will be lost.',
        actionLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
    } finally {
      _asking = false;
    }
    if (discard && mounted) _leave();
  }

  /// Closes the screen without asking.
  void _leave() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final original = _original;
    context.go(original == null ? Routes.home : Routes.expense(original.id));
  }
}

/// Runs a clean-up file operation; a file that cannot be removed now is
/// left for Clear cache and the start-up clean-up.
Future<void> _quietly(Future<void> work) async {
  try {
    await work;
  } on FileSystemException {
    // Left for later.
  }
}

/// The 60 px header of Add and Edit expense: Cancel, the title, and the
/// pocket pill when there are two or more pockets.
///
/// The side columns are 88 px wide (100 px with the pill) and grow only when
/// Cancel or the pill needs more room (large text), so nothing moves at the
/// default text size. The title takes what is left and scales down to fit:
/// "Add expense" is never cut.
class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.title, required this.onCancel, this.pill});

  final String title;
  final VoidCallback onCancel;
  final Widget? pill;

  /// The widest a side column grows (the pocket pill's largest width).
  static const double _sideMax = PocketPill.largestMaxWidth;

  @override
  Widget build(BuildContext context) {
    final side = pill == null ? 88.0 : 100.0;
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: side, maxWidth: _sideMax),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Pill(label: 'Cancel', onTap: onCancel),
              ),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Padding(
                  // Room between the title and Cancel or the pill when
                  // large text makes the title scale down to fit.
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FitTitle(title, style: AppText.screenTitle),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: side, maxWidth: _sideMax),
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: 1,
                child: pill ?? const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
