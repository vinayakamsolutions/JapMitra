import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Modes stored in preferences.
class FeedbackModes {
  static const vibOff = 'off';
  static const vibEvery = 'every';
  static const vibEvery10 = 'every10';
  static const vibMala = 'mala';

  static const soundOff = 'off';
  static const soundBell = 'bell';
  static const soundSoftBell = 'softbell';

  static const vibOptions = [vibOff, vibEvery, vibEvery10, vibMala];
  static const soundOptions = [soundOff, soundBell, soundSoftBell];
}

/// Debounced, non-blocking tactile/audio feedback for Jap taps.
///
/// Every call is fire-and-forget: feedback must never delay or gate the next
/// tap. All platform calls are guarded so simulator/test environments never
/// crash the counter.
class FeedbackService {
  const FeedbackService();

  /// Called once per physical tap with the *new* session count.
  Future<void> onJap({
    required String vibrationMode,
    required String soundMode,
    required int sessionCount,
    required int malaSize,
  }) async {
    try {
      final vib = _shouldVibrate(vibrationMode, sessionCount, malaSize);
      final sound = _shouldSound(soundMode, sessionCount, malaSize);
      if (vib) await _vibrate(malaSize: malaSize);
      if (sound) await _playSound(sessionCount, malaSize);
    } catch (_) {
      // Feedback is best-effort; never let it affect counting.
    }
  }

  Future<void> onMalaComplete() async {
    try {
      await _vibrate(malaSize: 108, strong: true);
      await _playSound(108, 108);
    } catch (_) {}
  }

  bool _shouldVibrate(String mode, int sessionCount, int malaSize) {
    switch (mode) {
      case FeedbackModes.vibEvery:
        return true;
      case FeedbackModes.vibEvery10:
        return sessionCount % 10 == 0;
      case FeedbackModes.vibMala:
        return sessionCount % malaSize == 0;
      default:
        return false;
    }
  }

  bool _shouldSound(String mode, int sessionCount, int malaSize) {
    switch (mode) {
      case FeedbackModes.soundBell:
        return true;
      case FeedbackModes.soundSoftBell:
        return sessionCount % 10 == 0;
      default:
        return false;
    }
  }

  Future<void> _vibrate({required int malaSize, bool strong = false}) async {
    if (kIsWeb) return;
    final has = await Vibration.hasVibrator();
    if (has != true) return;
    await Vibration.vibrate(
        duration: strong ? 120 : (malaSize == 108 ? 30 : 20));
  }

  Future<void> _playSound(int sessionCount, int malaSize) async {
    final full = (sessionCount % malaSize == 0);
    await SystemSound.play(
        full ? SystemSoundType.alert : SystemSoundType.click);
  }
}
