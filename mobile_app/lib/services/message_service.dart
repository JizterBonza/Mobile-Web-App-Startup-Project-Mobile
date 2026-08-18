import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/messageModel.dart';
import '../utils/api_endpoints.dart';
import 'api_service.dart';

/// Customer messaging API: conversations, thread, and send (JSON or multipart).
class MessageService extends ApiService {
  static const int maxBodyLength = 5000;
  static const int maxAttachments = 10;
  static const int maxAttachmentBytes = 20 * 1024 * 1024;
  static const Set<String> allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'mp4',
    'pdf',
    'docx',
  };

  Future<Map<String, String>?> _authHeaders({bool jsonContent = true}) async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) return null;
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    if (jsonContent) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  Map<String, dynamic> _unauthenticated() {
    return {
      'success': false,
      'message': 'Authentication required. Please login.',
      'data': null,
    };
  }

  dynamic _decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String _errorMessageFrom(dynamic responseData, String fallback) {
    if (responseData is Map) {
      if (responseData['message'] != null) {
        return responseData['message'].toString();
      }
      final errors = responseData['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
        return first.toString();
      }
    }
    return fallback;
  }

  void _debugLog(String label, int status, String body) {
    if (!kDebugMode) return;
    final preview = body.length > 800 ? '${body.substring(0, 800)}...' : body;
    debugPrint('DEBUG [MessageService] $label status=$status body=$preview');
  }

  Map<String, dynamic>? _validatePayload({
    String? body,
    required List<File> attachments,
    required bool requireContent,
  }) {
    final trimmed = body?.trim() ?? '';
    if (trimmed.length > maxBodyLength) {
      return {
        'success': false,
        'message': 'Message must not exceed $maxBodyLength characters',
        'data': null,
      };
    }
    if (requireContent && trimmed.isEmpty && attachments.isEmpty) {
      return {
        'success': false,
        'message': 'Message cannot be empty.',
        'data': null,
      };
    }
    if (attachments.length > maxAttachments) {
      return {
        'success': false,
        'message': 'You can attach up to $maxAttachments files',
        'data': null,
      };
    }
    for (final file in attachments) {
      if (!file.existsSync()) {
        return {
          'success': false,
          'message': 'Attachment not found: ${file.path.split(Platform.pathSeparator).last}',
          'data': null,
        };
      }
      final ext = file.path.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        return {
          'success': false,
          'message':
              'Unsupported file type .$ext. Allowed: ${allowedExtensions.join(', ')}',
          'data': null,
        };
      }
      final size = file.lengthSync();
      if (size > maxAttachmentBytes) {
        return {
          'success': false,
          'message':
              '${file.path.split(Platform.pathSeparator).last} exceeds the 20MB limit',
          'data': null,
        };
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _postJson({
    required String url,
    required Map<String, dynamic> payload,
    required String label,
    required Set<int> successCodes,
    required String successFallback,
    required String failureFallback,
  }) async {
    final headers = await _authHeaders();
    if (headers == null) return _unauthenticated();

    final response = await http
        .post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(payload),
        )
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            throw TimeoutException('Request timed out after 20 seconds');
          },
        );

    _debugLog(label, response.statusCode, response.body);
    final responseData = _decodeBody(response.body);

    if (successCodes.contains(response.statusCode)) {
      return {
        'success': true,
        'message': responseData is Map
            ? (responseData['message']?.toString() ?? successFallback)
            : successFallback,
        'data': ConversationThread.fromJson(responseData ?? {}),
      };
    }

    return {
      'success': false,
      'message': _errorMessageFrom(
        responseData,
        _fallbackForStatus(response.statusCode, failureFallback),
      ),
      'data': null,
      'statusCode': response.statusCode,
    };
  }

  String _fallbackForStatus(int statusCode, String fallback) {
    switch (statusCode) {
      case 403:
        return 'Customer account required';
      case 404:
        return 'Conversation not found';
      case 422:
        return 'Message cannot be empty.';
      default:
        return fallback;
    }
  }

  Future<Map<String, dynamic>> _postMultipart({
    required String url,
    String? body,
    required List<File> attachments,
    required String label,
    required Set<int> successCodes,
    required String successFallback,
    required String failureFallback,
  }) async {
    final headers = await _authHeaders(jsonContent: false);
    if (headers == null) return _unauthenticated();

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(headers);

    final trimmed = body?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      request.fields['body'] = trimmed;
    }

    for (final file in attachments) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'attachments[]',
          file.path,
          filename: file.path.split(Platform.pathSeparator).last,
        ),
      );
    }

    final streamed = await request.send().timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        throw TimeoutException('Upload timed out after 45 seconds');
      },
    );
    final response = await http.Response.fromStream(streamed);
    _debugLog(label, response.statusCode, response.body);
    final responseData = _decodeBody(response.body);

    if (successCodes.contains(response.statusCode)) {
      return {
        'success': true,
        'message': responseData is Map
            ? (responseData['message']?.toString() ?? successFallback)
            : successFallback,
        'data': ConversationThread.fromJson(responseData ?? {}),
      };
    }

    return {
      'success': false,
      'message': _errorMessageFrom(
        responseData,
        _fallbackForStatus(response.statusCode, failureFallback),
      ),
      'data': null,
      'statusCode': response.statusCode,
    };
  }

  /// GET /api/messages — customer's conversations, newest first.
  Future<Map<String, dynamic>> fetchConversations() async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return _unauthenticated();

      final response = await http
          .get(Uri.parse(ApiEndpoints.getConversations), headers: headers)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Request timed out after 15 seconds');
            },
          );

      _debugLog('GET conversations', response.statusCode, response.body);
      final responseData = _decodeBody(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Conversations fetched successfully',
          'data': ConversationListResponse.fromJson(responseData),
        };
      }

      return {
        'success': false,
        'message': _errorMessageFrom(
          responseData,
          _fallbackForStatus(
            response.statusCode,
            'Failed to fetch conversations',
          ),
        ),
        'data': null,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
        'data': null,
      };
    }
  }

  /// GET /api/messages/unread-count — `{ "unread_count": 1 }` for the chat badge.
  Future<Map<String, dynamic>> fetchUnreadCount() async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return _unauthenticated();

      final response = await http
          .get(Uri.parse(ApiEndpoints.getUnreadMessageCount), headers: headers)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Request timed out after 10 seconds');
            },
          );

      _debugLog('GET unread-count', response.statusCode, response.body);
      final responseData = _decodeBody(response.body);

      if (response.statusCode == 200) {
        int count = 0;
        if (responseData is Map) {
          final raw = responseData['unread_count'];
          if (raw is int) {
            count = raw;
          } else if (raw is num) {
            count = raw.toInt();
          } else {
            count = int.tryParse(raw?.toString() ?? '') ?? 0;
          }
        }
        return {
          'success': true,
          'message': 'Unread count fetched successfully',
          'data': count,
        };
      }

      return {
        'success': false,
        'message': _errorMessageFrom(
          responseData,
          _fallbackForStatus(
            response.statusCode,
            'Failed to fetch unread count',
          ),
        ),
        'data': null,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
        'data': null,
      };
    }
  }

  /// POST /api/shops/{shopId}/messages — start or resume a conversation.
  Future<Map<String, dynamic>> startConversation({
    required dynamic shopId,
    String? body,
    List<File> attachments = const [],
  }) async {
    try {
      final validation = _validatePayload(
        body: body,
        attachments: attachments,
        requireContent: false,
      );
      if (validation != null) return validation;

      final url = ApiEndpoints.startShopConversation
          .replaceAll('{shopId}', shopId.toString());

      if (attachments.isEmpty) {
        final payload = <String, dynamic>{};
        final trimmed = body?.trim() ?? '';
        if (trimmed.isNotEmpty) payload['body'] = trimmed;
        return await _postJson(
          url: url,
          payload: payload,
          label: 'POST start conversation',
          successCodes: {200, 201},
          successFallback: 'Conversation started',
          failureFallback: 'Failed to start conversation',
        );
      }

      return await _postMultipart(
        url: url,
        body: body,
        attachments: attachments,
        label: 'POST start conversation (multipart)',
        successCodes: {200, 201},
        successFallback: 'Conversation started',
        failureFallback: 'Failed to start conversation',
      );
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
        'data': null,
      };
    }
  }

  /// GET /api/messages/{conversationId}
  Future<Map<String, dynamic>> fetchConversation(dynamic conversationId) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return _unauthenticated();

      final url = ApiEndpoints.getConversation
          .replaceAll('{conversationId}', conversationId.toString());
      final response = await http.get(Uri.parse(url), headers: headers).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timed out after 15 seconds');
        },
      );

      _debugLog('GET conversation', response.statusCode, response.body);
      final responseData = _decodeBody(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Conversation loaded',
          'data': ConversationThread.fromJson(responseData ?? {}),
        };
      }

      return {
        'success': false,
        'message': _errorMessageFrom(
          responseData,
          _fallbackForStatus(
            response.statusCode,
            'Failed to load conversation',
          ),
        ),
        'data': null,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
        'data': null,
      };
    }
  }

  /// POST /api/messages/{conversationId} — send a message (body and/or files).
  Future<Map<String, dynamic>> sendMessage({
    required dynamic conversationId,
    String? body,
    List<File> attachments = const [],
  }) async {
    try {
      final validation = _validatePayload(
        body: body,
        attachments: attachments,
        requireContent: true,
      );
      if (validation != null) return validation;

      final url = ApiEndpoints.sendMessage
          .replaceAll('{conversationId}', conversationId.toString());

      if (attachments.isEmpty) {
        return await _postJson(
          url: url,
          payload: {'body': body!.trim()},
          label: 'POST send message',
          successCodes: {200, 201},
          successFallback: 'Message sent',
          failureFallback: 'Failed to send message',
        );
      }

      return await _postMultipart(
        url: url,
        body: body,
        attachments: attachments,
        label: 'POST send message (multipart)',
        successCodes: {200, 201},
        successFallback: 'Message sent',
        failureFallback: 'Failed to send message',
      );
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
        'data': null,
      };
    }
  }
}
