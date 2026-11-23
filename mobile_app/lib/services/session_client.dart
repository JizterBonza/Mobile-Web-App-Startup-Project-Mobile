import 'package:http/http.dart' as http;

import '../utils/session_guard.dart';
import 'api_service.dart';

/// Watches bearer responses and ends the session when the server rejects it.
class SessionClient extends http.BaseClient {
  SessionClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;
  var _closed = false;

  static const _credentialPaths = [
    '/api/login',
    '/api/register',
    '/api/refresh',
    '/api/logout',
    '/api/auth/google/token',
    '/api/forgot-password',
    '/api/reset-password',
  ];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _send(request, allowRetry: true);
  }

  Future<http.StreamedResponse> _send(
    http.BaseRequest request, {
    required bool allowRetry,
  }) async {
    final token = _bearerToken(request);
    final response = await _inner.send(request);
    if (!allowRetry ||
        token == null ||
        response.statusCode != 401 ||
        _isCredentialRequest(request.url)) {
      return response;
    }

    final refreshed = await ApiService.refreshAccessToken();
    if (!refreshed) {
      await SessionGuard.forceLogout();
      return response;
    }

    final nextToken = await ApiService.getToken();
    final retry = nextToken == null ? null : _clone(request, nextToken);
    if (retry == null) return response;

    final second = await _send(retry, allowRetry: false);
    if (second.statusCode == 401) {
      await SessionGuard.forceLogout();
    }
    return second;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _inner.close();
  }

  static String? _bearerToken(http.BaseRequest request) {
    final raw = request.headers['authorization'];
    if (raw == null) return null;
    final match =
        RegExp(r'^Bearer\s+(.+)$', caseSensitive: false).firstMatch(raw.trim());
    final token = match?.group(1)?.trim();
    if (token == null || token.isEmpty || token == 'null') return null;
    return token;
  }

  static bool _isCredentialRequest(Uri uri) {
    final path = uri.path;
    return _credentialPaths.any(path.endsWith);
  }

  static http.BaseRequest? _clone(http.BaseRequest request, String token) {
    if (request is http.Request) {
      final copy = http.Request(request.method, request.url)
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection
        ..bodyBytes = request.bodyBytes;
      copy.headers.addAll(request.headers);
      copy.headers['Authorization'] = 'Bearer $token';
      return copy;
    }
    if (request is http.MultipartRequest) {
      final copy = http.MultipartRequest(request.method, request.url)
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection
        ..fields.addAll(request.fields)
        ..files.addAll(request.files);
      copy.headers.addAll(request.headers);
      copy.headers['Authorization'] = 'Bearer $token';
      return copy;
    }
    return null;
  }
}
