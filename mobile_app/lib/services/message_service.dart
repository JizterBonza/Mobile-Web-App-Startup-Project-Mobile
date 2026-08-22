import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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

  String _attachmentFilename(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    if (name.contains('.')) return name;

    final ext = file.path.split('.').last.toLowerCase();
    if (allowedExtensions.contains(ext)) {
      return '$name.$ext';
    }
    return '$name.jpg';
  }

  Future<MultipartFile> _dioAttachment(File file, int index) async {
    final filename = _attachmentFilename(file);
    if (!file.existsSync()) {
      throw Exception('Attachment not found: $filename');
    }

    final size = await file.length();
    if (size == 0) {
      throw Exception('Attachment is empty: $filename');
    }

    if (kDebugMode) {
      debugPrint(
        'DEBUG [MessageService] attachment[$index] '
        'path=${file.path} name=$filename bytes=$size',
      );
    }

    return MultipartFile.fromFile(
      file.path,
      filename: filename,
    );
  }

  Map<String, dynamic>? _validatePayload({
    String? body,
    required List<File> attachments,
    required bool requireContent,
    dynamic itemId,
  }) {
    final trimmed = body?.trim() ?? '';
    if (trimmed.length > maxBodyLength) {
      return {
        'success': false,
        'message': 'Message must not exceed $maxBodyLength characters',
        'data': null,
      };
    }
    if (requireContent &&
        trimmed.isEmpty &&
        attachments.isEmpty &&
        itemId == null) {
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
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) return _unauthenticated();

    final trimmed = body?.trim() ?? '';
    final formData = FormData();

    if (trimmed.isNotEmpty) {
      formData.fields.add(MapEntry('body', trimmed));
    }

    for (var i = 0; i < attachments.length; i++) {
      formData.files.add(
        MapEntry(
          'attachments[]',
          await _dioAttachment(attachments[i], i),
        ),
      );
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 45),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        validateStatus: (_) => true,
      ),
    );

    try {
      final response = await dio.post<dynamic>(url, data: formData);
      final status = response.statusCode ?? 0;
      final responseData = _normalizeResponseData(response.data);
      _debugLog(label, status, responseData?.toString() ?? '');

      if (successCodes.contains(status)) {
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
          _fallbackForStatus(status, failureFallback),
        ),
        'data': null,
        'statusCode': status,
      };
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final responseData = _normalizeResponseData(e.response?.data);
      _debugLog(
        label,
        status,
        responseData?.toString() ?? e.message ?? '',
      );
      return {
        'success': false,
        'message': _errorMessageFrom(
          responseData,
          e.message ?? failureFallback,
        ),
        'data': null,
        'statusCode': status,
      };
    }
  }

  dynamic _normalizeResponseData(dynamic data) {
    if (data == null) return null;
    if (data is Map || data is List) return data;
    if (data is String) return _decodeBody(data);
    return data;
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

  /// GET /api/shops/{shopId}/messages/products?search=
  Future<Map<String, dynamic>> fetchShopMessageProducts({
    required dynamic shopId,
    String? search,
  }) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return _unauthenticated();

      final uri = Uri.parse(
        ApiEndpoints.getShopMessageProducts.replaceAll(
          '{shopId}',
          shopId.toString(),
        ),
      ).replace(
        queryParameters: {
          if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
        },
      );

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timed out after 15 seconds');
        },
      );

      _debugLog('GET shop message products', response.statusCode, response.body);
      final responseData = _decodeBody(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Products fetched',
          'data': parseMessageProductList(responseData),
        };
      }

      return {
        'success': false,
        'message': _errorMessageFrom(
          responseData,
          _fallbackForStatus(
            response.statusCode,
            'Failed to load products',
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
    dynamic itemId,
  }) async {
    try {
      final validation = _validatePayload(
        body: body,
        attachments: attachments,
        requireContent: false,
        itemId: itemId,
      );
      if (validation != null) return validation;

      final url = ApiEndpoints.startShopConversation
          .replaceAll('{shopId}', shopId.toString());

      if (itemId != null) {
        return await _postJson(
          url: url,
          payload: {'item_id': itemId},
          label: 'POST start conversation (product)',
          successCodes: {200, 201},
          successFallback: 'Conversation started',
          failureFallback: 'Failed to start conversation',
        );
      }

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

  /// POST /api/messages/{conversationId} — send a message (body, files, or item).
  Future<Map<String, dynamic>> sendMessage({
    required dynamic conversationId,
    String? body,
    List<File> attachments = const [],
    dynamic itemId,
  }) async {
    try {
      final validation = _validatePayload(
        body: body,
        attachments: attachments,
        requireContent: true,
        itemId: itemId,
      );
      if (validation != null) return validation;

      final url = ApiEndpoints.sendMessage
          .replaceAll('{conversationId}', conversationId.toString());

      if (itemId != null) {
        return await _postJson(
          url: url,
          payload: {'item_id': itemId},
          label: 'POST send product',
          successCodes: {200, 201},
          successFallback: 'Message sent',
          failureFallback: 'Failed to send message',
        );
      }

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
