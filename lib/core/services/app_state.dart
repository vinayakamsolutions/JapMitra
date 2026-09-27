import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visual size presets for the mantra line, in logical pixels.
///
/// These are *visual* sizes only: no counting, progress, queueing or persistence
/// behaviour reads them, so changing one can never alter a stored count.
const List<double> kMantraFontSizes = <double>[22, 28, 36, 44];

/// Index of [kMantraFontSizes] used when nothing has been chosen yet.
const int kDefaultMantraFontSizeIndex = 1;

/// Clamps an arbitrary stored or user supplied index into a valid preset index.
int sanitizeMantraFontSizeIndex(int value) {
  if (value < 0) return 0;
  if (value >= kMantraFontSizes.length) return kMantraFontSizes.length - 1;
  return value;
}

class AppState {
  late SharedPreferences prefs;
  String languageCode = 'hi';
  String city = 'Varanasi';
  String selectedMantra = 'ॐ नमः शिवाय';
  bool onboardingDone = false;
  bool japReminderEnabled = false;
  int dailyGoal = 108;
  int japReminderHour = 6;
  int japReminderMinute = 0;
  bool japVibration = false;
  bool reminderVibration = true;
  bool reminderSound = true;
  String themeMode = 'system';
  String vibrationMode = 'off';
  String soundMode = 'off';
  DateTime? dob;

  /// Which preset from [kMantraFontSizes] the mantra line should use.
  int mantraFontSizeIndex = kDefaultMantraFontSizeIndex;

  /// Rashifal sign the user picked as their own, so the list can highlight it.
  String? rashiSign;

  /// Bumped by every mutation.
  ///
  /// [AppState] is a single long lived mutable object, so identity comparisons
  /// can never detect a change. Screens listen to this instead, which is what
  /// makes a setting such as the mantra font size take effect immediately
  /// everywhere, including on screens that are not the one that changed it.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _notify() => revision.value++;

  /// The resolved visual mantra size in logical pixels.
  double get mantraFontSize =>
      kMantraFontSizes[sanitizeMantraFontSizeIndex(mantraFontSizeIndex)];

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    languageCode = prefs.getString('lang') ?? 'hi';
    city = prefs.getString('city') ?? 'Varanasi';
    selectedMantra = prefs.getString('mantra') ?? 'ॐ नमः शिवाय';
    onboardingDone = prefs.getBool('onboarding') ?? false;
    dailyGoal = prefs.getInt('goal') ?? 108;
    japReminderEnabled = prefs.getBool('japReminderEnabled') ?? false;
    japReminderHour = prefs.getInt('japReminderHour') ?? 6;
    japReminderMinute = prefs.getInt('japReminderMinute') ?? 0;
    japVibration = prefs.getBool('japVibration') ?? false;
    reminderVibration = prefs.getBool('reminderVibration') ?? true;
    reminderSound = prefs.getBool('reminderSound') ?? true;
    themeMode = prefs.getString('themeMode') ?? 'system';
    vibrationMode = prefs.getString('vibrationMode') ?? 'off';
    soundMode = prefs.getString('soundMode') ?? 'off';
    mantraFontSizeIndex = sanitizeMantraFontSizeIndex(
      prefs.getInt('mantraFontSizeIndex') ?? kDefaultMantraFontSizeIndex,
    );
    rashiSign = prefs.getString('rashiSign');
    final d = prefs.getString('dob');
    if (d != null) dob = DateTime.tryParse(d);
    _notify();
  }

  Future<void> setLang(String v) async {
    languageCode = v;
    await prefs.setString('lang', v);
    _notify();
  }

  Future<void> setCity(String v) async {
    city = v;
    await prefs.setString('city', v);
    _notify();
  }

  Future<void> doneOnboarding() async {
    onboardingDone = true;
    await prefs.setBool('onboarding', true);
    _notify();
  }

  Future<void> setGoal(int v) async {
    dailyGoal = v;
    await prefs.setInt('goal', v);
    _notify();
  }

  Future<void> setMantra(String v) async {
    selectedMantra = v;
    await prefs.setString('mantra', v);
    _notify();
  }

  /// Stores the mantra line's visual size preset. Visual only: no other
  /// behaviour in the app reads this value.
  Future<void> setMantraFontSizeIndex(int index) async {
    final safe = sanitizeMantraFontSizeIndex(index);
    mantraFontSizeIndex = safe;
    await prefs.setInt('mantraFontSizeIndex', safe);
    _notify();
  }

  /// Remembers the sign the user chose as their own, or clears it with `null`.
  Future<void> setRashiSign(String? signKey) async {
    rashiSign = signKey;
    if (signKey == null || signKey.isEmpty) {
      await prefs.remove('rashiSign');
    } else {
      await prefs.setString('rashiSign', signKey);
    }
    _notify();
  }

  Future<void> setDob(DateTime? v) async {
    dob = v;
    if (v == null) {
      await prefs.remove('dob');
    } else {
      await prefs.setString('dob', v.toIso8601String());
    }
    _notify();
  }

  Future<void> setJapVibration(bool v) async {
    japVibration = v;
    await prefs.setBool('japVibration', v);
    _notify();
  }

  Future<void> setReminderVibration(bool v) async {
    reminderVibration = v;
    await prefs.setBool('reminderVibration', v);
    _notify();
  }

  Future<void> setReminderSound(bool v) async {
    reminderSound = v;
    await prefs.setBool('reminderSound', v);
    _notify();
  }

  Future<void> setThemeMode(String v) async {
    themeMode = v;
    await prefs.setString('themeMode', v);
    _notify();
  }

  Future<void> setVibrationMode(String v) async {
    vibrationMode = v;
    await prefs.setString('vibrationMode', v);
    _notify();
  }

  Future<void> setSoundMode(String v) async {
    soundMode = v;
    await prefs.setString('soundMode', v);
    _notify();
  }

  Future<void> setJapReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    japReminderEnabled = enabled;
    japReminderHour = hour;
    japReminderMinute = minute;
    await prefs.setBool('japReminderEnabled', enabled);
    await prefs.setInt('japReminderHour', hour);
    await prefs.setInt('japReminderMinute', minute);
    _notify();
  }
}
