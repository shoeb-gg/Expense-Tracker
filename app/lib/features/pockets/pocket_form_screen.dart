import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_wrap.dart';
import '../../data/db.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'pocket_emojis.dart';

/// Longest pocket name the field takes.
const int pocketNameMaxLength = 40;

/// Add pocket (`/pockets/new`) and Edit pocket (`/pockets/:id`, with
/// [pocketId]): the PocketAdd and PocketEdit boards. A name, an emoji from
/// four groups or from the keyboard, and Save in the header.
class PocketFormScreen extends ConsumerStatefulWidget {
  const PocketFormScreen({super.key, this.pocketId});

  final int? pocketId;

  @override
  ConsumerState<PocketFormScreen> createState() => _PocketFormScreenState();
}

class _PocketFormScreenState extends ConsumerState<PocketFormScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _emojiInput = TextEditingController();
  final FocusNode _emojiFocus = FocusNode();
  String? _emoji;
  Pocket? _editing;
  bool _ready = false;
  bool _saving = false;

  bool get _isAdd => widget.pocketId == null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _emojiInput.dispose();
    _emojiFocus.dispose();
    super.dispose();
  }

  /// Fills the form once the pockets have loaded.
  void _prepare(List<Pocket> pockets) {
    if (_ready) return;
    _ready = true;
    if (_isAdd) {
      _emoji = firstUnusedEmoji(pockets.map((p) => p.emoji));
      return;
    }
    for (final p in pockets) {
      if (p.id == widget.pocketId) {
        _editing = p;
        _emoji = p.emoji;
        _name.text = p.name;
      }
    }
  }

  void _onEmojiTyped(String text) {
    final emoji = lastEmoji(text);
    _emojiInput.clear();
    if (emoji == null) return;
    setState(() => _emoji = emoji);
    _emojiFocus.unfocus();
  }

  void _openEmojiKeyboard() {
    if (_emojiFocus.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _emojiFocus.requestFocus();
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final emoji = _emoji;
    if (name.isEmpty || emoji == null || _saving) return;
    _saving = true;
    try {
      final repo = ref.read(pocketsRepoProvider);
      final editing = _editing;
      if (await repo.nameExists(name, exceptId: editing?.id)) {
        if (mounted) {
          showToast(
            context,
            'You already have a pocket called $name',
            bottom: 24,
          );
        }
        return;
      }
      if (editing == null) {
        final id = await repo.add(name: name, emoji: emoji);
        if (!mounted) return;
        if (await _askToSwitch(name: name, emoji: emoji)) {
          await _leaveAndSwitch(id, name);
          return;
        }
      } else {
        await repo.update(editing.copyWith(name: name, emoji: emoji));
      }
      if (mounted) await Navigator.of(context).maybePop();
    } finally {
      _saving = false;
    }
  }

  /// The new pocket is saved; asks whether to move to it. True for "Switch
  /// to"; "Stay in" and closing the pop-up (outside tap or Back) are false.
  Future<bool> _askToSwitch({
    required String name,
    required String emoji,
  }) async {
    final current = ref.read(currentPocketProvider)?.name;
    // Put the keyboard away so it does not cover the pop-up's buttons.
    FocusManager.instance.primaryFocus?.unfocus();
    final switchNow = await showAppDialog(
      context,
      title: 'Pocket added',
      boldLine: 'Switch to $emoji $name now?',
      cancelLabel: current == null ? 'Stay' : 'Stay in $current',
      actionLabel: 'Switch to $name',
    );
    return switchNow && mounted;
  }

  /// Leaves the form, then makes the new pocket the one in use. The switch
  /// waits for the screen underneath to wake up (one frame): changing what
  /// it watches while it sleeps under this form would make it rebuild its
  /// providers in the middle of the route transition.
  Future<void> _leaveAndSwitch(int id, String name) async {
    final actions = ref.read(dataActionsProvider);
    showToast(context, 'Switched to $name');
    unawaited(Navigator.of(context).maybePop());
    await WidgetsBinding.instance.endOfFrame;
    await actions.switchPocket(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pockets = ref.watch(pocketsProvider).value;
    if (pockets != null) _prepare(pockets);
    final title = _isAdd ? 'Add pocket' : 'Edit pocket';
    final notFound = !_isAdd && _ready && _editing == null;
    final canSave =
        _ready && !notFound && _name.text.trim().isNotEmpty && _emoji != null;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notFound)
              SubHeader(title: title)
            else
              SubHeader.form(
                title: title,
                onCancel: () => Navigator.of(context).maybePop(),
                onSave: canSave ? _save : null,
              ),
            Expanded(
              child: !_ready
                  ? const SizedBox.shrink()
                  : notFound
                  ? const _NotFound()
                  : _form(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final c = context.colors;
    final emoji = _emoji ?? '';
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          2,
          16,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                EmojiTile(emoji: emoji, size: 56, radius: 18, emojiSize: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _name,
                      autofocus: false,
                      cursorColor: c.accent,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(pocketNameMaxLength),
                      ],
                      onSubmitted: (_) {
                        if (_name.text.trim().isNotEmpty) _save();
                      },
                      style: AppText.bodyStrong.copyWith(
                        fontSize: 16,
                        height: 24 / 16,
                        color: c.text,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        filled: false,
                        hintText: 'Pocket name',
                        hintStyle: AppText.bodyStrong.copyWith(
                          fontSize: 16,
                          height: 24 / 16,
                          color: c.text3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BandCard(
            title: 'Emoji',
            bodyPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in pocketEmojiGroups) ...[
                  Text(
                    group.title,
                    style: AppText.overline.copyWith(color: c.text3),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final e in group.emojis)
                        _EmojiCell(
                          emoji: e,
                          selected: e == _emoji,
                          onTap: () => setState(() => _emoji = e),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  height: 44,
                  child: Pressable(
                    onTap: _openEmojiKeyboard,
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Symbols.keyboard_rounded,
                          size: 20,
                          color: c.text3,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Pick any emoji from your keyboard',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.segment.copyWith(color: c.text2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Receives the emoji typed on the keyboard; never seen.
                SizedBox(
                  height: 0,
                  child: OverflowBox(
                    maxHeight: 1,
                    child: Opacity(
                      opacity: 0,
                      child: SizedBox(
                        width: 1,
                        height: 1,
                        child: TextField(
                          controller: _emojiInput,
                          focusNode: _emojiFocus,
                          onChanged: _onEmojiTyped,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          decoration: const InputDecoration.collapsed(
                            hintText: '',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isAdd) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                keepLastWordsTogether(
                  'A new pocket starts empty. Your categories and settings '
                  'are already in it.',
                ),
                style: AppText.body.copyWith(
                  fontSize: 13,
                  height: 20 / 13,
                  color: c.text2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmojiCell extends StatelessWidget {
  const _EmojiCell({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 44,
      height: 44,
      child: Pressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: emoji,
        color: selected ? c.accentSoft : c.tile,
        borderRadius: BorderRadius.circular(14),
        border: selected ? Border.all(color: c.accent, width: 2) : null,
        child: ExcludeSemantics(
          child: Center(
            child: Text(emoji, style: AppText.emoji.copyWith(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}

/// Edit pocket for a pocket that no longer exists (not drawn in the
/// mockup): the app's shared "not found" card.
class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) => const NotFoundCard(
    thing: 'Pocket',
    icon: Symbols.account_balance_wallet_rounded,
  );
}
