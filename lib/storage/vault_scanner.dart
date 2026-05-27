import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/vault_file.dart';

class VaultScanner {
  /// Scans the given directory path recursively and returns a list of VaultFiles.
  static List<VaultFile> scanVault(String vaultPath) {
    final Directory dir = Directory(vaultPath);
    if (!dir.existsSync()) {
      return [];
    }

    final List<VaultFile> files = [];
    try {
      final List<FileSystemEntity> entities = dir.listSync(recursive: true, followLinks: false);

      for (final entity in entities) {
        if (entity is File) {
          final absolutePath = entity.path;
          final relativePath = p.relative(absolutePath, from: vaultPath);

          // Skip system/junk folders (like .git, .DS_Store, etc.)
          if (_shouldSkip(relativePath)) {
            continue;
          }

          final stat = entity.statSync();
          files.add(
            VaultFile(
              relativePath: relativePath,
              absolutePath: absolutePath,
              size: stat.size,
              modifiedTime: stat.modified,
            ),
          );
        }
      }
    } catch (e) {
      print('Error scanning vault: $e');
    }

    return files;
  }

  static bool _shouldSkip(String relativePath) {
    // Normalize path separators to forward slashes for uniform filtering
    final normalized = relativePath.replaceAll('\\', '/');
    final segments = normalized.split('/');

    for (final segment in segments) {
      // Skip git folders, build output folders, or lockfiles
      if (segment == '.git' || 
          segment == '.DS_Store' || 
          segment == 'thumbs.db' || 
          segment == 'desktop.ini') {
        return true;
      }
    }
    return false;
  }
}
