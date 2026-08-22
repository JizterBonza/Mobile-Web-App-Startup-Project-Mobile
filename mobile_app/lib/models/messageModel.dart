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

/// Inbox `outgoing` when the last sender is the customer; otherwise `incoming`.
String? _parseLastMessageSide(Map json) {
  final explicit = _readString(json, ['last_message_side', 'lastMessageSide']);
  if (explicit.isNotEmpty) return explicit;

  final sender = _asMap(json['last_sender'] ?? json['lastSender']);
  if (sender.isEmpty) return null;
  final role = _readString(sender, ['role']).toLowerCase();
  if (role.isEmpty) return null;
  return role == 'customer' ? 'outgoing' : 'incoming';
}

/// Conversation row from GET /api/messages (`conversations` array).
class ConversationModel {
  final dynamic id;
  final dynamic shopId;
  final String shopName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool unread;
  final int unreadCount;
  final String? lastMessageSide;

  ConversationModel({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.lastMessage,
    this.lastMessageAt,
    this.unread = false,
    this.unreadCount = 0,
    this.lastMessageSide,
  });

  /// Count shown on the inbox badge. Falls back to 1 when unread but count is missing.
  int get displayUnreadCount {
    if (!unread) return 0;
    return unreadCount > 0 ? unreadCount : 1;
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final unread = _parseBool(json['unread']);
    return ConversationModel(
      id: json['id'],
      shopId: json['shop_id'],
      shopName: _readString(json, ['shop_name']),
      lastMessage: _readString(json, ['last_message']),
      lastMessageAt: _parseDate(json['last_message_at']),
      unread: unread,
      unreadCount: _parseInt(json['unread_count'] ?? json['unreadCount']) ?? 0,
      lastMessageSide: _parseLastMessageSide(json),
    );
  }

  ConversationModel copyWith({
    dynamic id,
    dynamic shopId,
    String? shopName,
    String? lastMessage,
    DateTime? lastMessageAt,
    bool? unread,
    int? unreadCount,
    String? lastMessageSide,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unread: unread ?? this.unread,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageSide: lastMessageSide ?? this.lastMessageSide,
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

String _resolveMediaUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = Url.getUrl().replaceAll(RegExp(r'/+$'), '');
  final path = url.startsWith('/') ? url : '/$url';
  return '$base$path';
}

String _formatPeso(dynamic value) {
  if (value == null) return '';
  final raw = value.toString().trim();
  if (raw.isEmpty || raw == 'null') return '';
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(raw.replaceAll(',', '').replaceAll('₱', ''));
  if (parsed == null) return raw.startsWith('₱') ? raw : '₱$raw';
  if (parsed == parsed.roundToDouble()) return '₱${parsed.toInt()}';
  return '₱${parsed.toStringAsFixed(2)}';
}

String? _firstImageUrl(Map json) {
  final direct = _readString(json, [
    'image_url',
    'image',
    'thumbnail_url',
    'thumbnail',
    'photo',
  ]);
  if (direct.isNotEmpty) return _resolveMediaUrl(direct);

  for (final key in ['item_images', 'images', 'photos']) {
    final raw = json[key];
    if (raw is! List || raw.isEmpty) continue;
    final first = raw.first;
    if (first is String && first.trim().isNotEmpty) {
      return _resolveMediaUrl(first.trim());
    }
    if (first is Map) {
      final nested = _readString(first, ['url', 'path', 'src', 'image']);
      if (nested.isNotEmpty) return _resolveMediaUrl(nested);
    }
  }
  return null;
}

/// Variation option on a compact shop product (picker).
class MessageProductVariation {
  final dynamic id;
  final String name;
  final String? priceLabel;
  final String? originalPriceLabel;
  final String? imageUrl;

  MessageProductVariation({
    required this.id,
    required this.name,
    this.priceLabel,
    this.originalPriceLabel,
    this.imageUrl,
  });

  factory MessageProductVariation.fromJson(Map<String, dynamic> json) {
    final name = _readString(json, ['name', 'variation', 'label', 'title']);
    final price = _formatPeso(
      json['effective_price'] ?? json['item_price'] ?? json['price'],
    );
    final original = _formatPeso(
      json['original_price'] ??
          json['compare_at_price'] ??
          json['item_price_original'],
    );
    return MessageProductVariation(
      id: json['item_id'] ?? json['id'],
      name: name.isEmpty ? 'Variation' : name,
      priceLabel: price.isEmpty ? null : price,
      originalPriceLabel:
          original.isNotEmpty && original != price ? original : null,
      imageUrl: _firstImageUrl(json),
    );
  }
}

/// Compact product from the picker API or a thread `type: product` snapshot.
class MessageProductSnapshot {
  final dynamic id;
  final String name;
  final String? imageUrl;
  final String? priceLabel;
  final String? originalPriceLabel;
  final String? variationLabel;
  final List<MessageProductVariation> variations;

  MessageProductSnapshot({
    required this.id,
    required this.name,
    this.imageUrl,
    this.priceLabel,
    this.originalPriceLabel,
    this.variationLabel,
    this.variations = const [],
  });

  bool get hasDiscount =>
      originalPriceLabel != null &&
      originalPriceLabel!.isNotEmpty &&
      originalPriceLabel != priceLabel;

  factory MessageProductSnapshot.fromJson(Map<String, dynamic> json) {
    final nested = json['product'] is Map
        ? _asMap(json['product'])
        : json['item'] is Map
            ? _asMap(json['item'])
            : json;
    final name = _readString(nested, ['item_name', 'name', 'title']);
    final price = _formatPeso(
      nested['effective_price'] ?? nested['item_price'] ?? nested['price'],
    );
    final original = _formatPeso(
      nested['original_price'] ??
          nested['compare_at_price'] ??
          nested['item_original_price'],
    );
    final variations = <MessageProductVariation>[];
    final rawVariations =
        nested['variations'] ?? nested['variants'] ?? nested['options'];
    if (rawVariations is List) {
      for (final item in rawVariations) {
        if (item is Map) {
          variations.add(
            MessageProductVariation.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return MessageProductSnapshot(
      id: nested['item_id'] ?? nested['id'] ?? json['item_id'] ?? json['id'],
      name: name.isEmpty ? 'Product' : name,
      imageUrl: _firstImageUrl(nested) ?? _firstImageUrl(json),
      priceLabel: price.isEmpty ? null : price,
      originalPriceLabel:
          original.isNotEmpty && original != price ? original : null,
      variationLabel: _readString(nested, [
        'variation',
        'variant',
        'option',
        'size',
        'unit',
        'volume',
        'subtitle',
        'item_size',
      ]),
      variations: variations,
    );
  }
}

List<MessageProductSnapshot> parseMessageProductList(dynamic json) {
  List<dynamic> raw = const [];
  if (json is List) {
    raw = json;
  } else if (json is Map) {
    if (json['products'] is List) {
      raw = json['products'] as List;
    } else if (json['items'] is List) {
      raw = json['items'] as List;
    } else if (json['data'] is List) {
      raw = json['data'] as List;
    } else if (json['data'] is Map) {
      final data = _asMap(json['data']);
      if (data['products'] is List) {
        raw = data['products'] as List;
      } else if (data['items'] is List) {
        raw = data['items'] as List;
      }
    }
  }

  return raw
      .whereType<Map>()
      .map((item) => MessageProductSnapshot.fromJson(
            Map<String, dynamic>.from(item),
          ))
      .toList();
}

MessageProductSnapshot? _parseProductSnapshot(Map<String, dynamic> json) {
  final type = _readString(json, ['type'], 'text').toLowerCase();
  final raw = json['product'] ?? json['item'] ?? json['snapshot'];
  if (raw is Map) {
    return MessageProductSnapshot.fromJson(Map<String, dynamic>.from(raw));
  }
  if (type == 'product') {
    return MessageProductSnapshot.fromJson(json);
  }
  return null;
}

/// Thread item: date separator (`type: date`), text bubble, or product card.
class MessageModel {
  final dynamic id;
  final String type;
  final String side;
  final String time;
  final String sentBy;
  final String status;
  final String body;
  final String caption;
  final String label;
  final List<MessageAttachmentModel> attachments;
  final MessageProductSnapshot? product;

  MessageModel({
    required this.id,
    required this.type,
    required this.side,
    required this.time,
    required this.sentBy,
    required this.status,
    required this.body,
    this.caption = '',
    required this.label,
    this.attachments = const [],
    this.product,
  });

  bool get isDate => type == 'date';
  bool get isOutgoing => side == 'outgoing';
  bool get isProduct => type == 'product' || product != null;
  bool get isImages => type.toLowerCase() == 'images';
  bool get isFile => type.toLowerCase() == 'file';

  /// Text shown in the bubble. Image messages expose caption, not body.
  String get displayText {
    if (isImages) return caption;
    if (body.isNotEmpty) return body;
    return caption;
  }

  String get previewText {
    if (displayText.isNotEmpty) return displayText;
    if (isImages || attachments.any((item) => item.isImage)) {
      return 'Sent a photo';
    }
    if (isFile || attachments.isNotEmpty) {
      final name = attachments.first.name;
      return name.isNotEmpty ? name : 'Sent a file';
    }
    if (isProduct) return product?.name ?? 'Product';
    return '';
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final type = _readString(json, ['type'], 'text');
    final caption = _readString(json, ['caption']);
    final body = _readString(json, ['body']);
    final attachments = <MessageAttachmentModel>[];

    final rawImages = json['images'];
    if (rawImages is List) {
      for (final item in rawImages) {
        if (item is String && item.trim().isNotEmpty) {
          final url = item.trim();
          attachments.add(
            MessageAttachmentModel(
              url: url,
              name: url.split('/').last.split('?').first,
              mimeType: 'image/jpeg',
            ),
          );
        } else if (item is Map) {
          attachments.add(
            MessageAttachmentModel.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

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
      body: body,
      caption: caption,
      label: _readString(json, ['label']),
      attachments: attachments,
      product: _parseProductSnapshot(json),
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
