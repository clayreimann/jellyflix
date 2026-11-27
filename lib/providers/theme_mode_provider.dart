import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/providers/database_provider.dart';
import 'package:material_ui/material_ui.dart';

/// Light, dark, or follow the system (the default). Saved in the settings
/// box under [themeModeKey].
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const themeModeKey = 'themeMode';

  @override
  ThemeMode build() {
    final saved = ref.read(databaseProvider('settings')).get(themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(databaseProvider('settings')).put(themeModeKey, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
