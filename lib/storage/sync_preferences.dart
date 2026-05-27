import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SyncPreferences {
  static const String _keyLocalVaultPath = 'local_vault_path';
  static const String _keyDriveFolderName = 'drive_folder_name';
  static const String _keyLastSyncTime = 'last_sync_time';
  static const String _keyLastSyncStatus = 'last_sync_status';
  static const String _keySyncHistory = 'sync_history';
  static const String _keyGoogleUserEmail = 'google_user_email';
  static const String _keyUseMockMode = 'use_mock_mode';
  static const String _keyGoogleClientId = 'google_client_id';

  final SharedPreferences _prefs;

  SyncPreferences(this._prefs);

  String? get localVaultPath => _prefs.getString(_keyLocalVaultPath);
  Future<void> setLocalVaultPath(String? value) async {
    if (value == null) {
      await _prefs.remove(_keyLocalVaultPath);
    } else {
      await _prefs.setString(_keyLocalVaultPath, value);
    }
  }

  String get driveFolderName => _prefs.getString(_keyDriveFolderName) ?? 'Obsidan';
  Future<void> setDriveFolderName(String value) async {
    await _prefs.setString(_keyDriveFolderName, value);
  }

  String? get lastSyncTime => _prefs.getString(_keyLastSyncTime);
  Future<void> setLastSyncTime(String? value) async {
    if (value == null) {
      await _prefs.remove(_keyLastSyncTime);
    } else {
      await _prefs.setString(_keyLastSyncTime, value);
    }
  }

  String? get lastSyncStatus => _prefs.getString(_keyLastSyncStatus);
  Future<void> setLastSyncStatus(String? value) async {
    if (value == null) {
      await _prefs.remove(_keyLastSyncStatus);
    } else {
      await _prefs.setString(_keyLastSyncStatus, value);
    }
  }

  String? get googleUserEmail => _prefs.getString(_keyGoogleUserEmail);
  Future<void> setGoogleUserEmail(String? value) async {
    if (value == null) {
      await _prefs.remove(_keyGoogleUserEmail);
    } else {
      await _prefs.setString(_keyGoogleUserEmail, value);
    }
  }

  bool get useMockMode => _prefs.getBool(_keyUseMockMode) ?? true;
  Future<void> setUseMockMode(bool value) async {
    await _prefs.setBool(_keyUseMockMode, value);
  }

  String? get googleClientId => _prefs.getString(_keyGoogleClientId);
  Future<void> setGoogleClientId(String? value) async {
    if (value == null) {
      await _prefs.remove(_keyGoogleClientId);
    } else {
      await _prefs.setString(_keyGoogleClientId, value);
    }
  }

  List<String> get syncHistory => _prefs.getStringList(_keySyncHistory) ?? [];
  
  Future<void> addSyncHistoryEntry(String log) async {
    final history = syncHistory;
    final timestamp = DateTime.now().toLocal().toString().substring(0, 19);
    history.insert(0, '[$timestamp] $log');
    
    // Cap history at 100 items
    if (history.length > 100) {
      history.removeRange(100, history.length);
    }
    await _prefs.setStringList(_keySyncHistory, history);
  }

  Future<void> clearSyncHistory() async {
    await _prefs.remove(_keySyncHistory);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
