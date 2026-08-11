// Tema tercihini yönetir ve kaydeder.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Uygulama görünüm seçenekleri
enum VibeAppearance { dark, light }

// Tema durumunu tutan ve dinleyicilere bildiren sınıf
class ThemeController extends ChangeNotifier {
  static const _storageKey = 'vibe_appearance'; // Yerel depolama anahtarı

  VibeAppearance _appearance = VibeAppearance.dark; // Varsayılan koyu tema

  VibeAppearance get appearance => _appearance;

  ThemeMode get themeMode =>
      _appearance == VibeAppearance.dark ? ThemeMode.dark : ThemeMode.light;

  bool get isDark => _appearance == VibeAppearance.dark;

  // Kayıtlı temayı SharedPreferences'tan okur
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved == VibeAppearance.light.name) {
      _appearance = VibeAppearance.light;
    } else {
      _appearance = VibeAppearance.dark;
    }
    notifyListeners();
  }

  // Temayı değiştirir ve kalıcı olarak kaydeder
  Future<void> setAppearance(VibeAppearance value) async {
    if (_appearance == value) return;
    _appearance = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value.name);
  }
}

// Alt widget'lara ThemeController erişimi sağlar
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope bulunamadı');
    return scope!.notifier!;
  }
}
