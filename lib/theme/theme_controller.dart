import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// saves light/dark mode
class ThemeController {
  static const String boxName = 'settings';
  static const String _key = 'theme_mode';

  final Box<String> _box;
  late ValueNotifier<ThemeMode> mode;

  ThemeController(this._box) {
    mode = ValueNotifier(_parse(_box.get(_key)));
  }

  static Future<ThemeController> open() async {
    final box = await Hive.openBox<String>(boxName);
    return ThemeController(box);
  }

  void setMode(ThemeMode newMode) {
    mode.value = newMode;
    _box.put(_key, newMode.name);
  }

  static ThemeMode _parse(String? raw) {
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }
}
