import 'dart:io';
import 'package:path/path.dart' as p;
import '../drive/google_drive_client.dart';
import '../models/vault_file.dart';
import '../storage/vault_scanner.dart';
import '../storage/sync_preferences.dart';

class SyncStats {
  int filesScanned = 0;
  int filesUploaded = 0;
  int filesDownloaded = 0;
  int filesSkipped = 0;
  List<String> logs = [];
  bool success = false;
  String message = '';

  @override
  String toString() {
    return 'SyncStats(scanned: $filesScanned, uploaded: $filesUploaded, downloaded: $filesDownloaded, skipped: $filesSkipped)';
  }
}

class SyncEngine {
  final GoogleDriveClient driveClient;
  final SyncPreferences preferences;

  SyncEngine({
    required this.driveClient,
    required this.preferences,
  });

  /// Performs a "Sync Up" operation: Local Vault ───► Google Drive
  Future<SyncStats> syncUp() async {
    final stats = SyncStats();
    stats.logs.add('Starting Sync Up operation...');

    final localPath = preferences.localVaultPath;
    if (localPath == null || localPath.isEmpty) {
      stats.message = 'Local vault path is not configured.';
      stats.logs.add('Error: ${stats.message}');
      return stats;
    }

    final driveFolder = preferences.driveFolderName;

    try {
      // 1. Scan Local Vault
      stats.logs.add('Scanning local vault folder: $localPath');
      final localFiles = VaultScanner.scanVault(localPath);
      stats.filesScanned = localFiles.where((f) => !p.split(f.relativePath).any((seg) => seg.startsWith('.'))).length;
      stats.logs.add('Found ${localFiles.length} files locally.');

      // 2. Scan Google Drive Files
      stats.logs.add('Reading cloud vault metadata from Google Drive / $driveFolder...');
      final cloudFiles = await driveClient.listCloudFiles(driveFolder);
      stats.logs.add('Found ${cloudFiles.length} files in the cloud.');

      // Create a map of cloud files by relative path for O(1) lookups
      final cloudFileMap = {for (var f in cloudFiles) f.relativePath: f};

      // 3. Compare and Upload
      for (final localFile in localFiles) {
        final cloudFile = cloudFileMap[localFile.relativePath];

        if (cloudFile == null) {
          // File does not exist on Drive -> Upload
          stats.logs.add('Uploading missing cloud file: ${localFile.relativePath}');
          final success = await driveClient.uploadFile(driveFolder, localFile);
          if (success) {
            stats.filesUploaded++;
          } else {
            stats.logs.add('Failed to upload: ${localFile.relativePath}');
          }
        } else {
          // File exists on both, compare timestamps
          // We use a small threshold (e.g. 2 seconds) to account for filesystem precision variances
          final timeDiff = localFile.modifiedTime.difference(cloudFile.modifiedTime).inSeconds;

          if (timeDiff > 2) {
            // Local file is newer -> Upload
            stats.logs.add('Uploading newer local file: ${localFile.relativePath}');
            final success = await driveClient.uploadFile(driveFolder, localFile);
            if (success) {
              stats.filesUploaded++;
            } else {
              stats.logs.add('Failed to upload: ${localFile.relativePath}');
            }
          } else {
            // File is unchanged or cloud is newer/same -> Skip
            stats.filesSkipped++;
          }
        }
      }

      // 4. Handle local deletions (Cloud files that don't exist locally)
      final localFileMap = {for (var f in localFiles) f.relativePath: f};
      for (final cloudFile in cloudFiles) {
        if (!localFileMap.containsKey(cloudFile.relativePath)) {
          stats.logs.add('Local deletion detected: ${cloudFile.relativePath}');
          final success = await driveClient.deleteFile(driveFolder, cloudFile.relativePath);
          if (success) {
            stats.logs.add('Deleted cloud file: ${cloudFile.relativePath}');
          } else {
            stats.logs.add('Failed to delete cloud file: ${cloudFile.relativePath}');
          }
        }
      }

      stats.success = true;
      stats.message = 'Sync Up Completed. Scanned: ${stats.filesScanned}, Uploaded: ${stats.filesUploaded}, Skipped: ${stats.filesSkipped}';
      stats.logs.add('Sync Up finished successfully.');

      // Save sync status to preferences
      await preferences.setLastSyncTime(DateTime.now().toIso8601String());
      await preferences.setLastSyncStatus(stats.message);
      await preferences.addSyncHistoryEntry('Sync Up: Uploaded ${stats.filesUploaded} files, Skipped ${stats.filesSkipped}');
    } catch (e) {
      stats.message = 'Sync Up Failed: $e';
      stats.logs.add('Error during Sync Up: $e');
      await preferences.addSyncHistoryEntry('Sync Up Failed: $e');
    }

    return stats;
  }

  /// Performs a "Sync Down" operation: Google Drive ───► Local Vault
  Future<SyncStats> syncDown() async {
    final stats = SyncStats();
    stats.logs.add('Starting Sync Down operation...');

    final localPath = preferences.localVaultPath;
    if (localPath == null || localPath.isEmpty) {
      stats.message = 'Local vault path is not configured.';
      stats.logs.add('Error: ${stats.message}');
      return stats;
    }

    final driveFolder = preferences.driveFolderName;

    try {
      // 1. Scan Local Vault
      stats.logs.add('Scanning local vault folder: $localPath');
      final localFiles = VaultScanner.scanVault(localPath);
      stats.logs.add('Found ${localFiles.length} files locally.');

      // Create a map of local files by relative path for O(1) lookups
      final localFileMap = {for (var f in localFiles) f.relativePath: f};

      // 2. Scan Google Drive Files
      stats.logs.add('Reading cloud vault metadata from Google Drive / $driveFolder...');
      final cloudFiles = await driveClient.listCloudFiles(driveFolder);
      stats.filesScanned = cloudFiles.where((f) => !p.split(f.relativePath).any((seg) => seg.startsWith('.'))).length;
      stats.logs.add('Found ${cloudFiles.length} files in the cloud.');

      // 3. Compare and Download
      for (final cloudFile in cloudFiles) {
        final localFile = localFileMap[cloudFile.relativePath];
        final destLocalPath = p.join(localPath, cloudFile.relativePath);

        if (localFile == null) {
          // File does not exist locally -> Download
          stats.logs.add('Downloading missing local file: ${cloudFile.relativePath}');
          final success = await driveClient.downloadFile(driveFolder, cloudFile.relativePath, destLocalPath);
          if (success) {
            stats.filesDownloaded++;
          } else {
            stats.logs.add('Failed to download: ${cloudFile.relativePath}');
          }
        } else {
          // File exists on both, compare timestamps
          final timeDiff = cloudFile.modifiedTime.difference(localFile.modifiedTime).inSeconds;

          if (timeDiff > 2) {
            // Cloud file is newer -> Download
            stats.logs.add('Downloading newer cloud file: ${cloudFile.relativePath}');
            final success = await driveClient.downloadFile(driveFolder, cloudFile.relativePath, destLocalPath);
            if (success) {
              stats.filesDownloaded++;
            } else {
              stats.logs.add('Failed to download: ${cloudFile.relativePath}');
            }
          } else {
            // File is unchanged or local is newer/same -> Skip
            stats.filesSkipped++;
          }
        }
      }

      // 4. Handle remote deletions (Local files that don't exist in the cloud)
      final cloudFileMap = {for (var f in cloudFiles) f.relativePath: f};
      for (final localFile in localFiles) {
        if (!cloudFileMap.containsKey(localFile.relativePath)) {
          stats.logs.add('Remote deletion detected: ${localFile.relativePath}');
          try {
            final f = File(localFile.absolutePath);
            if (f.existsSync()) {
              f.deleteSync();
              stats.logs.add('Deleted local file: ${localFile.relativePath}');
              _deleteEmptyParentDirs(f.parent, Directory(localPath));
            }
          } catch (e) {
            stats.logs.add('Failed to delete local file: $e');
          }
        }
      }

      stats.success = true;
      stats.message = 'Sync Down Completed. Scanned: ${stats.filesScanned}, Downloaded: ${stats.filesDownloaded}, Skipped: ${stats.filesSkipped}';
      stats.logs.add('Sync Down finished successfully.');

      // Save sync status to preferences
      await preferences.setLastSyncTime(DateTime.now().toIso8601String());
      await preferences.setLastSyncStatus(stats.message);
      await preferences.addSyncHistoryEntry('Sync Down: Downloaded ${stats.filesDownloaded} files, Skipped ${stats.filesSkipped}');
    } catch (e) {
      stats.message = 'Sync Down Failed: $e';
      stats.logs.add('Error during Sync Down: $e');
      await preferences.addSyncHistoryEntry('Sync Down Failed: $e');
    }

    return stats;
  }

  void _deleteEmptyParentDirs(Directory dir, Directory limit) {
    if (dir.path == limit.path) return;
    try {
      if (dir.existsSync() && dir.listSync().isEmpty) {
        dir.deleteSync();
        _deleteEmptyParentDirs(dir.parent, limit);
      }
    } catch (e) {
      // Ignore directory delete errors
    }
  }
}
