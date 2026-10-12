import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/appReleaseModel.dart';
import '../utils/api_endpoints.dart';
import 'api_service.dart';

/// Service for checking, downloading and installing app releases.
class AppReleaseService {
  static const String _apkMimeType = 'application/vnd.android.package-archive';

  /// GET /api/app-releases/latest?version_code=N
  Future<Map<String, dynamic>> checkLatest() async {
    if (!Platform.isAndroid) {
      return {
        'success': true,
        'message': 'Updates are only supported on Android',
        'data': AppUpdateInfo.none(),
      };
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final uri = Uri.parse(ApiEndpoints.getLatestAppRelease).replace(
        queryParameters: {'version_code': packageInfo.buildNumber},
      );

      final response = await http
          .get(uri, headers: await _headers())
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds');
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': responseData['success'] == true ||
              responseData['success'] == null,
          'message': 'Latest release fetched successfully',
          'data': AppUpdateInfo.fromJson(responseData),
        };
      }

      String errorMessage = 'Failed to check for updates';
      try {
        final responseData = jsonDecode(response.body);
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'].toString();
        }
      } catch (_) {}

      return {
        'success': false,
        'message': errorMessage,
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// GET /api/app-releases/{release}/download
  ///
  /// Returns the downloaded APK in `data` once its checksum is verified.
  Future<Map<String, dynamic>> downloadApk(
    AppReleaseModel release, {
    void Function(double progress)? onProgress,
  }) async {
    File? file;
    try {
      final directory = await getTemporaryDirectory();
      file = File('${directory.path}/klasmeyt-${release.versionName}.apk');

      if (await file.exists() &&
          await verifyChecksum(file, release.checksumSha256)) {
        onProgress?.call(1);
        return {
          'success': true,
          'message': 'Update already downloaded',
          'data': file,
        };
      }

      final url = ApiEndpoints.downloadAppRelease
          .replaceAll('{release}', '${release.id}');

      await Dio().download(
        url,
        file.path,
        options: Options(
          headers: await _headers(accept: _apkMimeType),
          receiveTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: (received, total) {
          final expected = total > 0 ? total : release.fileSize;
          if (expected > 0) {
            onProgress?.call((received / expected).clamp(0.0, 1.0));
          }
        },
      );

      if (!await verifyChecksum(file, release.checksumSha256)) {
        await file.delete();
        return {
          'success': false,
          'message': 'The downloaded update is corrupted. Please try again.',
          'data': null,
        };
      }

      return {
        'success': true,
        'message': 'Update downloaded successfully',
        'data': file,
      };
    } catch (e) {
      if (file != null && await file.exists()) {
        await file.delete();
      }
      return {
        'success': false,
        'message': 'Download failed: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Compares the file's SHA-256 with [expected]. Passes when the backend
  /// did not provide a checksum.
  Future<bool> verifyChecksum(File file, String? expected) async {
    if (expected == null || expected.isEmpty) return true;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase() == expected.trim().toLowerCase();
  }

  /// Hands the APK to the Android package installer.
  Future<Map<String, dynamic>> installApk(File file) async {
    final result = await OpenFilex.open(file.path, type: _apkMimeType);
    final success = result.type == ResultType.done;
    return {
      'success': success,
      'message': success ? 'Installer opened' : result.message,
      'data': null,
    };
  }

  Future<String> getCurrentVersionName() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<Map<String, String>> _headers({
    String accept = 'application/json',
  }) async {
    final token = await ApiService.getToken();
    return {
      'Accept': accept,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}
