import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../models/vault_file.dart';
import '../storage/sync_preferences.dart';

abstract class GoogleDriveClient {
  Future<bool> signIn();
  Future<void> signOut();
  Future<bool> get isAuthenticated;
  Future<String?> get userEmail;

  /// Lists all files in the cloud vault folder recursively.
  Future<List<VaultFile>> listCloudFiles(String folderName);

  /// Uploads a local file to the cloud vault folder.
  Future<bool> uploadFile(String folderName, VaultFile file);

  /// Downloads a file from the cloud vault folder to a local path.
  Future<bool> downloadFile(String folderName, String relativePath, String localSavePath);

  /// Deletes a file from the cloud vault folder.
  Future<bool> deleteFile(String folderName, String relativePath);
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class MockGoogleDriveClient implements GoogleDriveClient {
  final String mockDriveRoot;
  bool _authenticated = false;
  String? _email;

  MockGoogleDriveClient(this.mockDriveRoot) {
    // Ensure the mock drive directory exists
    final dir = Directory(mockDriveRoot);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      // Create some default mock files on our mock cloud drive for demo purposes!
      _createMockCloudFiles();
    }
  }

  void _createMockCloudFiles() {
    try {
      final mockObsidianDir = Directory(p.join(mockDriveRoot, 'Obsidan'));
      if (!mockObsidianDir.existsSync()) {
        mockObsidianDir.createSync(recursive: true);
      }

      // Add a couple of mock cloud files that might be newer or missing locally
      final welcomeFile = File(p.join(mockObsidianDir.path, 'Welcome to SyncGo.md'));
      if (!welcomeFile.existsSync()) {
        welcomeFile.writeAsStringSync('# Welcome to SyncGo!\n\nThis is a mock cloud markdown note in your Google Drive folder.');
        // Set back its local modified date so it has a valid time
        welcomeFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));
      }

      final cloudNote = File(p.join(mockObsidianDir.path, 'Cloud Only Note.md'));
      if (!cloudNote.existsSync()) {
        cloudNote.writeAsStringSync('# Cloud Note\n\nThis note is only on Google Drive (Mock Mode). Run Sync Down to fetch it!');
        cloudNote.setLastModifiedSync(DateTime.now().subtract(const Duration(minutes: 10)));
      }
    } catch (e) {
      print('Error creating default mock cloud files: $e');
    }
  }

  @override
  Future<bool> signIn() async {
    await Future.delayed(const Duration(milliseconds: 600)); // Simulate network latency
    _authenticated = true;
    _email = 'explorer.pirate@gmail.com';
    return true;
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _authenticated = false;
    _email = null;
  }

  @override
  Future<bool> get isAuthenticated async => _authenticated;

  @override
  Future<String?> get userEmail async => _email;

  @override
  Future<List<VaultFile>> listCloudFiles(String folderName) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final List<VaultFile> files = [];

    final cloudFolderPath = p.join(mockDriveRoot, folderName);
    final cloudDir = Directory(cloudFolderPath);
    if (!cloudDir.existsSync()) {
      return [];
    }

    try {
      final entities = cloudDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          final relativePath = p.relative(entity.path, from: cloudFolderPath);
          final stat = entity.statSync();
          files.add(
            VaultFile(
              relativePath: relativePath,
              absolutePath: entity.path,
              size: stat.size,
              modifiedTime: stat.modified,
            ),
          );
        }
      }
    } catch (e) {
      print('Error listing mock cloud files: $e');
    }

    return files;
  }

  @override
  Future<bool> uploadFile(String folderName, VaultFile file) async {
    await Future.delayed(const Duration(milliseconds: 250));
    try {
      final destPath = p.join(mockDriveRoot, folderName, file.relativePath);
      final destFile = File(destPath);
      
      // Ensure parent directory exists
      final destDir = Directory(p.dirname(destPath));
      if (!destDir.existsSync()) {
        destDir.createSync(recursive: true);
      }

      // Copy file content
      final localFile = File(file.absolutePath);
      if (localFile.existsSync()) {
        destFile.writeAsBytesSync(localFile.readAsBytesSync());
        // Match the timestamp perfectly
        destFile.setLastModifiedSync(file.modifiedTime);
        return true;
      }
    } catch (e) {
      print('Error uploading file (mock): $e');
    }
    return false;
  }

  @override
  Future<bool> downloadFile(String folderName, String relativePath, String localSavePath) async {
    await Future.delayed(const Duration(milliseconds: 250));
    try {
      final srcPath = p.join(mockDriveRoot, folderName, relativePath);
      final srcFile = File(srcPath);
      final localFile = File(localSavePath);

      // Ensure local parent directory exists
      final localDir = Directory(p.dirname(localSavePath));
      if (!localDir.existsSync()) {
        localDir.createSync(recursive: true);
      }

      if (srcFile.existsSync()) {
        localFile.writeAsBytesSync(srcFile.readAsBytesSync());
        // Match the cloud modification time
        localFile.setLastModifiedSync(srcFile.lastModifiedSync());
        return true;
      }
    } catch (e) {
      print('Error downloading file (mock): $e');
    }
    return false;
  }

  @override
  Future<bool> deleteFile(String folderName, String relativePath) async {
    await Future.delayed(const Duration(milliseconds: 250));
    try {
      final srcPath = p.join(mockDriveRoot, folderName, relativePath);
      final srcFile = File(srcPath);
      if (srcFile.existsSync()) {
        srcFile.deleteSync();
        return true;
      }
    } catch (e) {
      print('Error deleting file (mock): $e');
    }
    return false;
  }
}

class RealGoogleDriveClient implements GoogleDriveClient {
  final SyncPreferences preferences;
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  // Cache to map relative paths to Google Drive file IDs
  final Map<String, String> _cloudPathToIdMap = {};

  RealGoogleDriveClient(this.preferences);

  static const String _clientId = '979305955442-8b79eqmp05vo1c925p250ea45i7huisa.apps.googleusercontent.com';

  GoogleSignIn _getSignInInstance() {
    if (_googleSignIn == null) {
      _googleSignIn = GoogleSignIn(
        clientId: _clientId,
        serverClientId: _clientId,
        scopes: [drive.DriveApi.driveScope],
      );
    }
    return _googleSignIn!;
  }

  @override
  Future<bool> signIn() async {
    try {
      final signIn = _getSignInInstance();
      _currentUser = await signIn.signIn();

      if (_currentUser != null) {
        final auth = await _currentUser!.authentication;
        final authHeaders = {'Authorization': 'Bearer ${auth.accessToken}'};
        final client = GoogleAuthClient(authHeaders);
        _driveApi = drive.DriveApi(client);
        return true;
      }
    } catch (e) {
      print('RealGoogleDriveClient: Sign-In error: $e');
    }
    return false;
  }

  @override
  Future<void> signOut() async {
    try {
      await _getSignInInstance().signOut();
      _currentUser = null;
      _driveApi = null;
      _cloudPathToIdMap.clear();
    } catch (e) {
      print('RealGoogleDriveClient: Sign-Out error: $e');
    }
  }

  @override
  Future<bool> get isAuthenticated async {
    try {
      final signIn = _getSignInInstance();
      if (_currentUser == null) {
        _currentUser = await signIn.signInSilently();
      }

      if (_currentUser != null) {
        final auth = await _currentUser!.authentication;
        if (auth.accessToken != null) {
          final authHeaders = {'Authorization': 'Bearer ${auth.accessToken}'};
          final client = GoogleAuthClient(authHeaders);
          _driveApi = drive.DriveApi(client);
          return true;
        }
      }
    } catch (e) {
      print('RealGoogleDriveClient: isAuthenticated error: $e');
    }
    return false;
  }

  @override
  Future<String?> get userEmail async {
    return _currentUser?.email;
  }

  @override
  Future<List<VaultFile>> listCloudFiles(String folderName) async {
    if (_driveApi == null) {
      final authed = await isAuthenticated;
      if (!authed || _driveApi == null) {
        throw Exception('Not authenticated with Google Drive.');
      }
    }

    _cloudPathToIdMap.clear();
    final List<VaultFile> vaultFiles = [];

    try {
      final rootFolderId = await _getOrCreateFolderId(folderName, 'root');
      if (rootFolderId == null) {
        throw Exception('Failed to get or create root sync folder on Google Drive.');
      }

      await _listFolderRecursively(_driveApi!, rootFolderId, '', vaultFiles);
    } catch (e) {
      print('RealGoogleDriveClient: listCloudFiles error: $e');
      rethrow;
    }

    return vaultFiles;
  }

  @override
  Future<bool> uploadFile(String folderName, VaultFile file) async {
    if (_driveApi == null) {
      final authed = await isAuthenticated;
      if (!authed || _driveApi == null) {
        return false;
      }
    }

    try {
      final rootFolderId = await _getOrCreateFolderId(folderName, 'root');
      if (rootFolderId == null) return false;

      final localFile = File(file.absolutePath);
      if (!localFile.existsSync()) return false;

      final parentRelativePath = p.dirname(file.relativePath);
      String parentFolderId = rootFolderId;
      if (parentRelativePath != '.') {
        final resolvedParentId = await _resolveSubfolderId(rootFolderId, parentRelativePath);
        if (resolvedParentId == null) return false;
        parentFolderId = resolvedParentId;
      }

      final filename = p.basename(file.relativePath);
      final media = drive.Media(localFile.openRead(), localFile.lengthSync());

      String? existingFileId = _cloudPathToIdMap[file.relativePath];
      if (existingFileId == null) {
        existingFileId = await _findFileIdInFolder(parentFolderId, filename);
      }

      if (existingFileId != null) {
        final fileMetadata = drive.File()..modifiedTime = file.modifiedTime.toUtc();
        await _driveApi!.files.update(fileMetadata, existingFileId, uploadMedia: media);
        _cloudPathToIdMap[file.relativePath] = existingFileId;
      } else {
        final fileMetadata = drive.File()
          ..name = filename
          ..parents = [parentFolderId]
          ..modifiedTime = file.modifiedTime.toUtc();
        final created = await _driveApi!.files.create(fileMetadata, uploadMedia: media);
        if (created.id != null) {
          _cloudPathToIdMap[file.relativePath] = created.id!;
        }
      }
      return true;
    } catch (e) {
      print('RealGoogleDriveClient: uploadFile error ($file): $e');
      return false;
    }
  }

  @override
  Future<bool> downloadFile(String folderName, String relativePath, String localSavePath) async {
    if (_driveApi == null) {
      final authed = await isAuthenticated;
      if (!authed || _driveApi == null) {
        return false;
      }
    }

    try {
      String? fileId = _cloudPathToIdMap[relativePath];
      if (fileId == null) {
        final rootFolderId = await _getOrCreateFolderId(folderName, 'root');
        if (rootFolderId == null) return false;

        final parentRelativePath = p.dirname(relativePath);
        String parentFolderId = rootFolderId;
        if (parentRelativePath != '.') {
          final resolvedParentId = await _resolveSubfolderId(rootFolderId, parentRelativePath);
          if (resolvedParentId == null) return false;
          parentFolderId = resolvedParentId;
        }

        final filename = p.basename(relativePath);
        fileId = await _findFileIdInFolder(parentFolderId, filename);
      }

      if (fileId == null) {
        print('RealGoogleDriveClient: File not found in cloud: $relativePath');
        return false;
      }

      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final localFile = File(localSavePath);
      if (!localFile.parent.existsSync()) {
        localFile.parent.createSync(recursive: true);
      }

      final ioSink = localFile.openWrite();
      await response.stream.pipe(ioSink);
      await ioSink.close();

      final meta = await _driveApi!.files.get(
        fileId,
        $fields: 'modifiedTime',
      ) as drive.File;
      if (meta.modifiedTime != null) {
        localFile.setLastModifiedSync(meta.modifiedTime!.toLocal());
      }

      return true;
    } catch (e) {
      print('RealGoogleDriveClient: downloadFile error ($relativePath): $e');
      return false;
    }
  }

  @override
  Future<bool> deleteFile(String folderName, String relativePath) async {
    if (_driveApi == null) {
      final authed = await isAuthenticated;
      if (!authed || _driveApi == null) {
        return false;
      }
    }

    try {
      String? fileId = _cloudPathToIdMap[relativePath];
      if (fileId == null) {
        final rootFolderId = await _getOrCreateFolderId(folderName, 'root');
        if (rootFolderId == null) return false;

        final parentRelativePath = p.dirname(relativePath);
        String parentFolderId = rootFolderId;
        if (parentRelativePath != '.') {
          final resolvedParentId = await _resolveSubfolderId(rootFolderId, parentRelativePath);
          if (resolvedParentId == null) return false;
          parentFolderId = resolvedParentId;
        }

        final filename = p.basename(relativePath);
        fileId = await _findFileIdInFolder(parentFolderId, filename);
      }

      if (fileId == null) {
        print('RealGoogleDriveClient: File to delete not found in cloud: $relativePath');
        return false;
      }

      await _driveApi!.files.delete(fileId);
      _cloudPathToIdMap.remove(relativePath);
      return true;
    } catch (e) {
      print('RealGoogleDriveClient: deleteFile error ($relativePath): $e');
      return false;
    }
  }

  // --- Helper Methods ---

  Future<String?> _getOrCreateFolderId(String name, String parentId) async {
    if (_driveApi == null) return null;
    try {
      final query = "name = '$name' and mimeType = 'application/vnd.google-apps.folder' and '$parentId' in parents and trashed = false";
      final list = await _driveApi!.files.list(q: query, spaces: 'drive', $fields: 'files(id)');
      if (list.files != null && list.files!.isNotEmpty) {
        return list.files!.first.id;
      }

      final folderMetadata = drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentId];
      final created = await _driveApi!.files.create(folderMetadata);
      return created.id;
    } catch (e) {
      print('RealGoogleDriveClient: _getOrCreateFolderId error ($name): $e');
      return null;
    }
  }

  Future<String?> _resolveSubfolderId(String rootId, String relativePath) async {
    final segments = p.split(relativePath);
    String currentParentId = rootId;
    for (final segment in segments) {
      if (segment == '.' || segment == '/') continue;
      final id = await _getOrCreateFolderId(segment, currentParentId);
      if (id == null) return null;
      currentParentId = id;
    }
    return currentParentId;
  }

  Future<String?> _findFileIdInFolder(String parentId, String filename) async {
    if (_driveApi == null) return null;
    try {
      final query = "name = '$filename' and mimeType != 'application/vnd.google-apps.folder' and '$parentId' in parents and trashed = false";
      final list = await _driveApi!.files.list(q: query, spaces: 'drive', $fields: 'files(id)');
      if (list.files != null && list.files!.isNotEmpty) {
        return list.files!.first.id;
      }
    } catch (e) {
      print('RealGoogleDriveClient: _findFileIdInFolder error ($filename): $e');
    }
    return null;
  }

  Future<void> _listFolderRecursively(
    drive.DriveApi driveApi,
    String parentId,
    String currentRelativePath,
    List<VaultFile> results,
  ) async {
    final query = "'$parentId' in parents and trashed = false";
    final list = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name, mimeType, modifiedTime, size)',
    );

    if (list.files == null) return;

    for (final file in list.files!) {
      if (file.name == null || file.id == null) continue;

      final relativePath = currentRelativePath.isEmpty ? file.name! : p.join(currentRelativePath, file.name!);

      if (file.mimeType == 'application/vnd.google-apps.folder') {
        await _listFolderRecursively(driveApi, file.id!, relativePath, results);
      } else {
        _cloudPathToIdMap[relativePath] = file.id!;

        results.add(
          VaultFile(
            relativePath: relativePath,
            absolutePath: file.id!,
            size: int.tryParse(file.size ?? '0') ?? 0,
            modifiedTime: file.modifiedTime?.toLocal() ?? DateTime.now(),
          ),
        );
      }
    }
  }
}
