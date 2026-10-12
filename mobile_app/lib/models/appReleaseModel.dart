class AppReleaseModel {
  final int id;
  final String versionName;
  final int versionCode;
  final String? releaseNotes;
  final int fileSize;
  final String? checksumSha256;
  final int? minSupportedVersionCode;
  final DateTime? publishedAt;
  final String? downloadUrl;

  AppReleaseModel({
    required this.id,
    required this.versionName,
    required this.versionCode,
    this.releaseNotes,
    this.fileSize = 0,
    this.checksumSha256,
    this.minSupportedVersionCode,
    this.publishedAt,
    this.downloadUrl,
  });

  factory AppReleaseModel.fromJson(Map<String, dynamic> json) {
    return AppReleaseModel(
      id: _parseInt(json['id']) ?? 0,
      versionName: json['version_name']?.toString() ?? '',
      versionCode: _parseInt(json['version_code']) ?? 0,
      releaseNotes: json['release_notes']?.toString(),
      fileSize: _parseInt(json['file_size']) ?? 0,
      checksumSha256: json['checksum_sha256']?.toString(),
      minSupportedVersionCode: _parseInt(json['min_supported_version_code']),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      downloadUrl: json['download_url']?.toString(),
    );
  }

  String get formattedFileSize {
    if (fileSize <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = fileSize.toDouble();
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class AppUpdateInfo {
  final bool updateAvailable;
  final bool forceUpdate;
  final AppReleaseModel? latest;

  AppUpdateInfo({
    required this.updateAvailable,
    required this.forceUpdate,
    this.latest,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final latestJson = json['latest'];
    return AppUpdateInfo(
      updateAvailable: json['update_available'] == true,
      forceUpdate: json['force_update'] == true,
      latest: latestJson is Map<String, dynamic>
          ? AppReleaseModel.fromJson(latestJson)
          : null,
    );
  }

  factory AppUpdateInfo.none() =>
      AppUpdateInfo(updateAvailable: false, forceUpdate: false);

  bool get hasUpdate => updateAvailable && latest != null;
  bool get isForced => hasUpdate && forceUpdate;
}
