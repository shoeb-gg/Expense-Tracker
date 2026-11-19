// ignore_for_file: constant_identifier_names
import 'package:flutter/widgets.dart';

/// Every Material Symbols Rounded icon the app uses. Names and codepoints
/// match `package:material_symbols_icons` (`Symbols.<name>_rounded`), but the
/// glyphs come from the app's own copy of the font, which
/// `tool/icon_font.dart` trims to these icons and pads so Flutter's release
/// icon tree shaker cannot corrupt it (see FOUNDATION.md, "Icon font").
///
/// To add an icon: copy its line from the package's `lib/symbols.dart`
/// (keep `matchTextDirection`, drop `fontPackage`), run
/// `dart run tool/icon_font.dart`, then `flutter test test/tool`.
abstract final class Symbols {
  static const IconData account_balance_wallet_rounded = IconData(0xe850, fontFamily: 'MaterialSymbolsRounded');
  static const IconData add_circle_rounded = IconData(0xe990, fontFamily: 'MaterialSymbolsRounded');
  static const IconData add_rounded = IconData(0xe145, fontFamily: 'MaterialSymbolsRounded');
  static const IconData arrow_back_rounded = IconData(0xe5c4, fontFamily: 'MaterialSymbolsRounded', matchTextDirection: true);
  static const IconData arrow_upward_rounded = IconData(0xe5d8, fontFamily: 'MaterialSymbolsRounded');
  static const IconData backspace_rounded = IconData(0xe14a, fontFamily: 'MaterialSymbolsRounded', matchTextDirection: true);
  static const IconData bar_chart_rounded = IconData(0xe26b, fontFamily: 'MaterialSymbolsRounded');
  static const IconData calculate_rounded = IconData(0xea5f, fontFamily: 'MaterialSymbolsRounded');
  static const IconData calendar_month_rounded = IconData(0xebcc, fontFamily: 'MaterialSymbolsRounded');
  static const IconData category_rounded = IconData(0xe72c, fontFamily: 'MaterialSymbolsRounded');
  static const IconData check_rounded = IconData(0xe668, fontFamily: 'MaterialSymbolsRounded');
  static const IconData chevron_left_rounded = IconData(0xe5cb, fontFamily: 'MaterialSymbolsRounded', matchTextDirection: true);
  static const IconData chevron_right_rounded = IconData(0xe5cc, fontFamily: 'MaterialSymbolsRounded', matchTextDirection: true);
  static const IconData close_rounded = IconData(0xe5cd, fontFamily: 'MaterialSymbolsRounded');
  static const IconData cloud_done_rounded = IconData(0xe2bf, fontFamily: 'MaterialSymbolsRounded');
  static const IconData cloud_off_rounded = IconData(0xe2c1, fontFamily: 'MaterialSymbolsRounded');
  static const IconData cloud_upload_rounded = IconData(0xe2c3, fontFamily: 'MaterialSymbolsRounded');
  static const IconData content_copy_rounded = IconData(0xe14d, fontFamily: 'MaterialSymbolsRounded');
  static const IconData delete_rounded = IconData(0xe92e, fontFamily: 'MaterialSymbolsRounded');
  static const IconData description_rounded = IconData(0xe873, fontFamily: 'MaterialSymbolsRounded');
  static const IconData dialpad_rounded = IconData(0xe0bc, fontFamily: 'MaterialSymbolsRounded');
  static const IconData donut_small_rounded = IconData(0xe918, fontFamily: 'MaterialSymbolsRounded');
  static const IconData drag_indicator_rounded = IconData(0xe945, fontFamily: 'MaterialSymbolsRounded');
  static const IconData edit_rounded = IconData(0xf097, fontFamily: 'MaterialSymbolsRounded');
  static const IconData error_rounded = IconData(0xf8b6, fontFamily: 'MaterialSymbolsRounded');
  static const IconData expand_less_rounded = IconData(0xe5ce, fontFamily: 'MaterialSymbolsRounded');
  static const IconData expand_more_rounded = IconData(0xe5cf, fontFamily: 'MaterialSymbolsRounded');
  static const IconData folder_rounded = IconData(0xe2c7, fontFamily: 'MaterialSymbolsRounded');
  static const IconData hide_image_rounded = IconData(0xf022, fontFamily: 'MaterialSymbolsRounded');
  static const IconData history_rounded = IconData(0xe8b3, fontFamily: 'MaterialSymbolsRounded');
  static const IconData home_rounded = IconData(0xe9b2, fontFamily: 'MaterialSymbolsRounded');
  static const IconData image_rounded = IconData(0xe3f4, fontFamily: 'MaterialSymbolsRounded');
  static const IconData info_rounded = IconData(0xe88e, fontFamily: 'MaterialSymbolsRounded');
  static const IconData keyboard_rounded = IconData(0xe312, fontFamily: 'MaterialSymbolsRounded');
  static const IconData lock_rounded = IconData(0xe899, fontFamily: 'MaterialSymbolsRounded');
  static const IconData logout_rounded = IconData(0xe9ba, fontFamily: 'MaterialSymbolsRounded', matchTextDirection: true);
  static const IconData north_east_rounded = IconData(0xf1e1, fontFamily: 'MaterialSymbolsRounded');
  static const IconData notes_rounded = IconData(0xe26c, fontFamily: 'MaterialSymbolsRounded', matchTextDirection: true);
  static const IconData palette_rounded = IconData(0xe40a, fontFamily: 'MaterialSymbolsRounded');
  static const IconData photo_camera_rounded = IconData(0xe412, fontFamily: 'MaterialSymbolsRounded');
  static const IconData receipt_long_rounded = IconData(0xef6e, fontFamily: 'MaterialSymbolsRounded', matchTextDirection: true);
  static const IconData touch_app_rounded = IconData(0xe913, fontFamily: 'MaterialSymbolsRounded');
  static const IconData trending_down_rounded = IconData(0xe8e3, fontFamily: 'MaterialSymbolsRounded', matchTextDirection: true);
  static const IconData trending_flat_rounded = IconData(0xe8e4, fontFamily: 'MaterialSymbolsRounded', matchTextDirection: true);
  static const IconData trending_up_rounded = IconData(0xe8e5, fontFamily: 'MaterialSymbolsRounded', matchTextDirection: true);
  static const IconData tune_rounded = IconData(0xe429, fontFamily: 'MaterialSymbolsRounded');
  static const IconData upload_file_rounded = IconData(0xe9fc, fontFamily: 'MaterialSymbolsRounded');
  static const IconData visibility_off_rounded = IconData(0xe8f5, fontFamily: 'MaterialSymbolsRounded');
  static const IconData visibility_rounded = IconData(0xe8f4, fontFamily: 'MaterialSymbolsRounded');
  static const IconData zoom_in_rounded = IconData(0xe8ff, fontFamily: 'MaterialSymbolsRounded');
}
