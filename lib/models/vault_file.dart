class VaultFile {
  final String relativePath;
  final String absolutePath;
  final int size;
  final DateTime modifiedTime;

  VaultFile({
    required this.relativePath,
    required this.absolutePath,
    required this.size,
    required this.modifiedTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'relativePath': relativePath,
      'absolutePath': absolutePath,
      'size': size,
      'modifiedTime': modifiedTime.toIso8601String(),
    };
  }

  factory VaultFile.fromJson(Map<String, dynamic> json) {
    return VaultFile(
      relativePath: json['relativePath'] as String,
      absolutePath: json['absolutePath'] as String,
      size: json['size'] as int,
      modifiedTime: DateTime.parse(json['modifiedTime'] as String),
    );
  }

  @override
  String toString() {
    return 'VaultFile($relativePath, size: $size, modified: $modifiedTime)';
  }
}
