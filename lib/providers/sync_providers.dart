import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import '../drive/google_drive_client.dart';
import '../storage/sync_preferences.dart';
import '../sync/sync_engine.dart';

// Provider for SharedPreferences (initialized in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences has not been initialized yet.');
});

// Provider for local application directory (to store mock drive files)
final appDocumentsDirProvider = Provider<String>((ref) {
  throw UnimplementedError('App documents directory has not been initialized yet.');
});

// Provider for SyncPreferences
final syncPreferencesProvider = Provider<SyncPreferences>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncPreferences(prefs);
});

// Provider to watch the mock mode setting
final mockModeProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(syncPreferencesProvider);
  return prefs.useMockMode;
});

// Provider for active GoogleDriveClient
final googleDriveClientProvider = Provider<GoogleDriveClient>((ref) {
  final useMock = ref.watch(mockModeProvider);
  final prefs = ref.watch(syncPreferencesProvider);
  
  if (useMock) {
    // Store mock drive in a hidden folder inside our workspace or documents directory
    final appDir = ref.watch(appDocumentsDirProvider);
    final mockPath = p.join(appDir, '.syncgo_mock_drive');
    return MockGoogleDriveClient(mockPath);
  } else {
    return RealGoogleDriveClient(prefs);
  }
});

// Provider for active SyncEngine
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final client = ref.watch(googleDriveClientProvider);
  final prefs = ref.watch(syncPreferencesProvider);
  return SyncEngine(driveClient: client, preferences: prefs);
});

// Authentication state provider
class AuthState {
  final bool isAuthenticated;
  final String? email;
  final bool isLoading;

  AuthState({
    this.isAuthenticated = false,
    this.email,
    this.isLoading = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? email,
    bool? isLoading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final GoogleDriveClient _client;
  final SyncPreferences _prefs;

  AuthNotifier(this._client, this._prefs) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final authed = await _client.isAuthenticated;
      final email = await _client.userEmail;
      state = AuthState(isAuthenticated: authed, email: email, isLoading: false);
    } catch (e) {
      print('AuthNotifier: _init error: $e');
      state = AuthState(isAuthenticated: false, email: null, isLoading: false);
    }
  }

  Future<bool> signIn() async {
    state = state.copyWith(isLoading: true);
    try {
      final success = await _client.signIn();
      if (success) {
        final email = await _client.userEmail;
        await _prefs.setGoogleUserEmail(email);
        state = AuthState(isAuthenticated: true, email: email, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
      return success;
    } catch (e) {
      print('AuthNotifier: signIn error: $e');
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _client.signOut();
      await _prefs.setGoogleUserEmail(null);
      state = AuthState(isAuthenticated: false, email: null, isLoading: false);
    } catch (e) {
      print('AuthNotifier: signOut error: $e');
      state = state.copyWith(isLoading: false);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(googleDriveClientProvider);
  final prefs = ref.watch(syncPreferencesProvider);
  return AuthNotifier(client, prefs);
});

// Active Sync Operation State
class ActiveSyncState {
  final bool isSyncing;
  final String statusMessage;
  final List<String> liveLogs;
  final SyncStats? lastStats;

  ActiveSyncState({
    this.isSyncing = false,
    this.statusMessage = 'Idle',
    this.liveLogs = const [],
    this.lastStats,
  });

  ActiveSyncState copyWith({
    bool? isSyncing,
    String? statusMessage,
    List<String>? liveLogs,
    SyncStats? lastStats,
  }) {
    return ActiveSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      statusMessage: statusMessage ?? this.statusMessage,
      liveLogs: liveLogs ?? this.liveLogs,
      lastStats: lastStats ?? this.lastStats,
    );
  }
}

class StoragePermissionManager {
  static const _channel = MethodChannel('com.obsidian.syncgo/storage');

  static Future<bool> checkPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('checkStoragePermission');
      return hasPermission;
    } on PlatformException catch (e) {
      print('Failed to check storage permission: $e');
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestStoragePermission');
    } on PlatformException catch (e) {
      print('Failed to request storage permission: $e');
    }
  }
}

class ActiveSyncNotifier extends StateNotifier<ActiveSyncState> {
  final SyncEngine _engine;
  final SyncPreferences _prefs;

  ActiveSyncNotifier(this._engine, this._prefs) : super(ActiveSyncState());

  Future<void> performSyncUp() async {
    if (state.isSyncing) return;
    
    // Check permission first (only if not mock mode)
    if (!_prefs.useMockMode) {
      final hasPermission = await StoragePermissionManager.checkPermission();
      if (!hasPermission) {
        state = ActiveSyncState(
          isSyncing: false,
          statusMessage: 'Permission Denied',
          liveLogs: [
            '[Error] Storage permission not granted.',
            '[Info] SyncGo requires "All Files Access" to sync external Obsidian vaults on Android 11+ (Android 15).',
            '[Info] Opening storage permission settings...',
            '[Info] Please locate "SyncGo", enable "Allow access to manage all files", then return to the app and sync again.'
          ],
        );
        await StoragePermissionManager.requestPermission();
        return;
      }
    }
    
    state = ActiveSyncState(
      isSyncing: true,
      statusMessage: 'Syncing Up...',
      liveLogs: ['[Info] Starting Sync Up...'],
    );

    // Wait a brief moment to show smooth transition
    await Future.delayed(const Duration(milliseconds: 300));

    final stats = await _engine.syncUp();
    
    state = ActiveSyncState(
      isSyncing: false,
      statusMessage: stats.success ? 'Sync Up Success' : 'Sync Up Failed',
      liveLogs: [...state.liveLogs, ...stats.logs, '[Info] Finished Sync Up.'],
      lastStats: stats,
    );
  }

  Future<void> performSyncDown() async {
    if (state.isSyncing) return;

    // Check permission first (only if not mock mode)
    if (!_prefs.useMockMode) {
      final hasPermission = await StoragePermissionManager.checkPermission();
      if (!hasPermission) {
        state = ActiveSyncState(
          isSyncing: false,
          statusMessage: 'Permission Denied',
          liveLogs: [
            '[Error] Storage permission not granted.',
            '[Info] SyncGo requires "All Files Access" to sync external Obsidian vaults on Android 11+ (Android 15).',
            '[Info] Opening storage permission settings...',
            '[Info] Please locate "SyncGo", enable "Allow access to manage all files", then return to the app and sync again.'
          ],
        );
        await StoragePermissionManager.requestPermission();
        return;
      }
    }

    state = ActiveSyncState(
      isSyncing: true,
      statusMessage: 'Syncing Down...',
      liveLogs: ['[Info] Starting Sync Down...'],
    );

    await Future.delayed(const Duration(milliseconds: 300));

    final stats = await _engine.syncDown();
    
    state = ActiveSyncState(
      isSyncing: false,
      statusMessage: stats.success ? 'Sync Down Success' : 'Sync Down Failed',
      liveLogs: [...state.liveLogs, ...stats.logs, '[Info] Finished Sync Down.'],
      lastStats: stats,
    );
  }

  void clearLogs() {
    state = state.copyWith(liveLogs: []);
  }
}

final activeSyncProvider = StateNotifierProvider<ActiveSyncNotifier, ActiveSyncState>((ref) {
  final engine = ref.watch(syncEngineProvider);
  final prefs = ref.watch(syncPreferencesProvider);
  return ActiveSyncNotifier(engine, prefs);
});
