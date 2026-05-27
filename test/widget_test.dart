import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncgo/drive/google_drive_client.dart';
import 'package:syncgo/storage/sync_preferences.dart';
import 'package:syncgo/storage/vault_scanner.dart';
import 'package:syncgo/sync/sync_engine.dart';

void main() {
  late Directory tempDir;
  late String localVaultPath;
  late String mockDrivePath;
  late SyncPreferences syncPreferences;

  setUp(() async {
    // 1. Create a isolated temp directory for testing files
    tempDir = Directory.systemTemp.createTempSync('syncgo_test_');
    localVaultPath = p.join(tempDir.path, 'LocalVault');
    mockDrivePath = p.join(tempDir.path, 'MockDrive');

    Directory(localVaultPath).createSync();
    Directory(mockDrivePath).createSync();

    // 2. Initialize in-memory SharedPreferences for the unit test
    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();
    syncPreferences = SyncPreferences(sharedPrefs);

    // Save configurations
    await syncPreferences.setLocalVaultPath(localVaultPath);
    await syncPreferences.setDriveFolderName('Obsidan');
  });

  tearDown(() {
    // Clean up temporary testing directories
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Sync Engine - Sync Up (Local to Drive)', () async {
    // Create a local note file
    final noteFile = File(p.join(localVaultPath, 'Note1.md'));
    noteFile.writeAsStringSync('# Title\nLocal note content.');
    final originalTime = DateTime.now().subtract(const Duration(minutes: 5));
    noteFile.setLastModifiedSync(originalTime);

    // Scan vault to verify VaultScanner
    final scanned = VaultScanner.scanVault(localVaultPath);
    expect(scanned.length, 1);
    expect(scanned.first.relativePath, 'Note1.md');

    // Setup Mock Drive client
    final driveClient = MockGoogleDriveClient(mockDrivePath);
    final syncEngine = SyncEngine(driveClient: driveClient, preferences: syncPreferences);

    // Perform Sync Up
    final stats = await syncEngine.syncUp();

    expect(stats.success, true);
    expect(stats.filesScanned, 1);
    expect(stats.filesUploaded, 1);
    expect(stats.filesSkipped, 0);

    // Verify file exists on the mock drive
    final driveFile = File(p.join(mockDrivePath, 'Obsidan', 'Note1.md'));
    expect(driveFile.existsSync(), true);
    expect(driveFile.readAsStringSync(), '# Title\nLocal note content.');

    // Match the modified timestamp
    final driveTimeDiff = driveFile.lastModifiedSync().difference(originalTime).inSeconds.abs();
    expect(driveTimeDiff <= 2, true); // within 2 seconds
  });

  test('Sync Engine - Sync Down (Drive to Local)', () async {
    // Create a note on the mock cloud drive directly
    final driveFolder = p.join(mockDrivePath, 'Obsidan');
    Directory(driveFolder).createSync(recursive: true);
    
    final cloudNote = File(p.join(driveFolder, 'CloudNote.md'));
    cloudNote.writeAsStringSync('# Cloud Title\nCloud content.');
    final cloudTime = DateTime.now().subtract(const Duration(seconds: 10));
    cloudNote.setLastModifiedSync(cloudTime);

    // Setup Mock Drive client
    final driveClient = MockGoogleDriveClient(mockDrivePath);
    final syncEngine = SyncEngine(driveClient: driveClient, preferences: syncPreferences);

    // Perform Sync Down
    final stats = await syncEngine.syncDown();

    expect(stats.success, true);
    expect(stats.filesScanned, 1); // 1 custom file added
    expect(stats.filesDownloaded, 1);

    // Verify it exists in local vault now
    final localFile = File(p.join(localVaultPath, 'CloudNote.md'));
    expect(localFile.existsSync(), true);
    expect(localFile.readAsStringSync(), '# Cloud Title\nCloud content.');
  });
}
