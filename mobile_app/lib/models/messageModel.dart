import '../utils/url.dart';

String _readString(Map json, List<String> keys, [String fallback = '']) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') continue;
    return text;
  }
  return fallback;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

bool _parseBool(dynamic value) {
  return value == true || value == 1 || value == '1' || value == 'true';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

/// Conversation row from GET /api/messages (`conversations` array).
class ConversationModel {
  final dynamic id;
  final dynamic shopId;
  final String shopName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool unread;

  ConversationModel({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.lastMessage,
    this.lastMessageAt,
    this.unread = false,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'],
      shopId: json['shop_id'],
      shopName: _readString(json, ['shop_name']),
      lastMessage: _readString(json, ['last_message']),
      lastMessageAt: _parseDate(json['last_message_at']),
      unread: _parseBool(json['unread']),
    );
  }

  ConversationModel copyWith({
    dynamic id,
    dynamic shopId,
    String? shopName,
    String? lastMessage,
    DateTime? lastMessageAt,
    bool? unread,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unread: unread ?? this.unread,
    );
  }
}

/// `conversation` object on thread responses (customer header, not the shop).
class ConversationHeader {
  final dynamic id;
  final String name;
  final String? avatarUrl;
  final String lastSeen;

  ConversationHeader({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.lastSeen,
  });

  factory ConversationHeader.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar_url'];
    return ConversationHeader(
      id: json['id'],
      name: _readString(json, ['name']),
      avatarUrl: avatar == null || avatar.toString() == 'null'
          ? null
          : avatar.toString(),
      lastSeen: _readString(json, ['last_seen']),
    );
  }
}

/// `shop` object on thread responses.
class MessageShopInfo {
  final dynamic id;
  final String shopName;

  MessageShopInfo({required this.id, required this.shopName});

  factory MessageShopInfo.fromJson(Map<String, dynamic> json) {
    return MessageShopInfo(
      id: json['id'],
      shopName: _readString(json, ['shop_name', 'name']),
    );
  }
}

/// File attached to a message (when the API includes attachments / urls).
class MessageAttachmentModel {
  final dynamic id;
  final String url;
  final String name;
  final String mimeType;
  final int? size;

  MessageAttachmentModel({
    this.id,
    required this.url,
    required this.name,
    required this.mimeType,
    this.size,
  });

  factory MessageAttachmentModel.fromJson(Map<String, dynamic> json) {
    final url = _readString(
      json,
      ['url', 'path', 'file_url', 'file_path', 'src', 'original_url'],
    );
    var name = _readString(
      json,
      ['name', 'file_name', 'filename', 'original_name'],
    );
    if (name.isEmpty && url.isNotEmpty) {
      name = url.split('/').last.split('?').first;
    }

    return MessageAttachmentModel(
      id: json['id'],
      url: url,
      name: name,
      mimeType: _readString(
        json,
        ['mime_type', 'mimeType', 'content_type'],
      ),
      size: _parseInt(json['size'] ?? json['file_size']),
    );
  }

  String get resolvedUrl {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = Url.getUrl().replaceAll(RegExp(r'/+$'), '');
    final path = url.startsWith('/') ? url : '/$url';
    return '$base$path';
  }

  bool get isImage {
    final mime = mimeType.toLowerCase();
    final haystack = '${name.toLowerCase()} ${url.toLowerCase()}';
    if (mime.startsWith('image/')) return true;
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp']
        .any((ext) => haystack.contains(ext));
  }
}

/// Thread item: date separator (`type: date`) or a chat bubble (`type: text`).
class MessageModel {
  final dynamic id;
  final String type;
  final String side;
  final String time;
  final String sentBy;
  final String status;
  final String body;
  final String label;
  final List<MessageAttachmentModel> attachments;

  MessageModel({
    required this.id,
    required this.type,
    required this.side,
    required this.time,
    required this.sentBy,
    required this.status,
    required this.body,
    required this.label,
    this.attachments = const [],
  });

  bool get isDate => type == 'date';
  bool get isOutgoing => side == 'outgoing';

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final type = _readString(json, ['type'], 'text');
    final attachments = <MessageAttachmentModel>[];

    final rawAttachments = json['attachments'] ?? json['files'] ?? json['media'];
    if (rawAttachments is List) {
      for (final item in rawAttachments) {
        if (item is Map) {
          attachments.add(
            MessageAttachmentModel.fromJson(Map<String, dynamic>.from(item)),
          );
        } else if (item is String) {
          attachments.add(
            MessageAttachmentModel(
              url: item,
              name: item.split('/').last,
              mimeType: '',
            ),
          );
        }
      }
    }

    final directUrl = _readString(json, ['url', 'file_url', 'path']);
    if (directUrl.isNotEmpty && attachments.isEmpty) {
      attachments.add(
        MessageAttachmentModel(
          url: directUrl,
          name: _readString(json, ['file_name', 'filename', 'name']),
          mimeType: _readString(json, ['mime_type']),
        ),
      );
    }

    return MessageModel(
      id: json['id'],
      type: type.isEmpty ? 'text' : type,
      side: _readString(json, ['side']),
      time: _readString(json, ['time']),
      sentBy: _readString(json, ['sent_by']),
      status: _readString(json, ['status']),
      body: _readString(json, ['body']),
      label: _readString(json, ['label']),
      attachments: attachments,
    );
  }
}

/// Payload from start / get / send: `conversation` + `messages` + optional `shop`.
class ConversationThread {
  final ConversationHeader conversation;
  final List<MessageModel> messages;
  final MessageShopInfo? shop;

  ConversationThread({
    required this.conversation,
    required this.messages,
    this.shop,
  });

  String get shopName => shop?.shopName ?? '';

  ConversationThread copyWith({
    ConversationHeader? conversation,
    List<MessageModel>? messages,
    MessageShopInfo? shop,
  }) {
    return ConversationThread(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      shop: shop ?? this.shop,
    );
  }

  factory ConversationThread.fromJson(dynamic json) {
    final root = _asMap(json);
    final data = root['data'] is Map ? _asMap(root['data']) : root;

    final conversation = ConversationHeader.fromJson(
      data['conversation'] is Map ? _asMap(data['conversation']) : data,
    );

    MessageShopInfo? shop;
    if (data['shop'] is Map) {
      shop = MessageShopInfo.fromJson(_asMap(data['shop']));
    }

    final rawMessages = data['messages'] is List
        ? data['messages'] as List
        : const <dynamic>[];
    final messages = rawMessages
        .whereType<Map>()
        .map((item) => MessageModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return ConversationThread(
      conversation: conversation,
      messages: messages,
      shop: shop,
    );
  }
}

/// Parses GET /api/messages `{ "conversations": [ ... ], "unread_count": 1 }`.
class ConversationListResponse {
  final List<ConversationModel> conversations;
  final int unreadCount;

  ConversationListResponse({
    required this.conversations,
    required this.unreadCount,
  });

  factory ConversationListResponse.fromJson(dynamic json) {
    final conversations = parseConversationList(json);
    final parsed = json is Map ? _parseInt(json['unread_count']) : null;
    return ConversationListResponse(
      conversations: conversations,
      unreadCount: parsed ?? conversations.where((item) => item.unread).length,
    );
  }
}

/// Parses GET /api/messages `{ "conversations": [ ... ] }`.
List<ConversationModel> parseConversationList(dynamic json) {
  List<dynamic> raw = const [];
  if (json is Map && json['conversations'] is List) {
    raw = json['conversations'] as List;
  } else if (json is List) {
    raw = json;
  } else if (json is Map && json['data'] is List) {
    raw = json['data'] as List;
  }

  return raw
      .whereType<Map>()
      .map((item) => ConversationModel.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
