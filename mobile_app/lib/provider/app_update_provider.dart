import 'dart:io';
import 'package:flutter/material.dart';
import '../models/appReleaseModel.dart';
import '../services/app_release_service.dart';

/// Provider for app update state from `/api/app-releases/latest`.
class AppUpdateProvider with ChangeNotifier {
  static const Duration _minCheckInterval = Duration(minutes: 5);

  final AppReleaseService _service = AppReleaseService();

  AppUpdateInfo? _info;
  String? _currentVersionName;
  bool _isChecking = false;
  bool _isDownloading = false;
  double _progress = 0;
  String? _error;
  DateTime? _lastCheckedAt;

  AppUpdateInfo? get info => _info;
  AppReleaseModel? get latest => _info?.latest;
  String? get currentVersionName => _currentVersionName;
  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  double get progress => _progress;
  String? get error => _error;
  bool get hasUpdate => _info?.hasUpdate ?? false;
  bool get isForced => _info?.isForced ?? false;
  bool get hasOptionalUpdate => hasUpdate && !isForced;

  Future<void> checkForUpdate({bool force = false}) async {
    if (_isChecking || _isDownloading) return;
    if (!force &&
        _lastCheckedAt != null &&
        DateTime.now().difference(_lastCheckedAt!) < _minCheckInterval) {
      return;
    }

    _isChecking = true;
    if (force) _error = null;
    notifyListeners();

    try {
      _currentVersionName ??= await _service.getCurrentVersionName();
      final result = await _service.checkLatest();
      if (result['success'] == true && result['data'] is AppUpdateInfo) {
        _info = result['data'] as AppUpdateInfo;
        _lastCheckedAt = DateTime.now();
        _error = null;
      } else if (force) {
        _error = result['message']?.toString();
      }
    } catch (e) {
      if (force) _error = e.toString();
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Downloads, verifies and opens the installer for the latest release.
  Future<void> startUpdate() async {
    final release = latest;
    if (release == null || _isDownloading) return;

    _isDownloading = true;
    _progress = 0;
    _error = null;
    notifyListeners();

    try {
      final download = await _service.downloadApk(
        release,
        onProgress: (value) {
          if ((value * 100).floor() == (_progress * 100).floor()) return;
          _progress = value;
          notifyListeners();
        },
      );

      if (download['success'] != true || download['data'] is! File) {
        _error = download['message']?.toString() ?? 'Download failed';
        return;
      }

      final install = await _service.installApk(download['data'] as File);
      if (install['success'] != true) {
        _error = install['message']?.toString() ?? 'Could not open installer';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }
}
