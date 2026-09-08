import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small wrapper around the one flag the app needs before any alarm/DB
/// logic runs: whether the permission-onboarding flow has been completed.
/// Kept separate from [AlarmRepository] deliberately — this is app-level
/// settings, not alarm data.
class AppPrefs {
  static const _onboardingCompleteKey = 'onboarding_complete';

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, value);
  }
}

final appPrefsProvider = Provider<AppPrefs>((ref) => AppPrefs());
