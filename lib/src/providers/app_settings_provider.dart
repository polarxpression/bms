import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bms/src/data/models/app_settings.dart';

const _settingsKey = 'app_settings';

/// Manages loading and saving of user-configurable application settings.
class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  late SharedPreferences _prefs;

  @override
  Future<AppSettings> build() async {
    _prefs = await SharedPreferences.getInstance();
    final settingsString = _prefs.getString(_settingsKey);

    if (settingsString != null) {
      final settingsJson = jsonDecode(settingsString) as Map<String, dynamic>;
      return AppSettings.fromJson(settingsJson);
    } else {
      // Return default settings if no saved settings are found
      return const AppSettings();
    }
  }

  Future<void> _saveSettings(AppSettings settings) async {
    final settingsString = jsonEncode(settings.toJson());
    await _prefs.setString(_settingsKey, settingsString);
  }

  /// Updates the default gondola capacity and persists the change.
  Future<void> updateGondolaCapacity(int capacity) async {
    final oldSettings = state.value ?? const AppSettings();
    final newSettings = oldSettings.copyWith(gondolaCapacity: capacity);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }

  /// Updates the visibility of discontinued batteries and persists the change.
  Future<void> toggleShowDiscontinued(bool show) async {
    final oldSettings = state.value ?? const AppSettings();
    final newSettings = oldSettings.copyWith(showDiscontinuedBatteries: show);
    state = AsyncValue.data(newSettings);
    await _saveSettings(newSettings);
  }
}

/// Provider to expose the AppSettingsNotifier.
final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
      AppSettingsNotifier.new,
    );
