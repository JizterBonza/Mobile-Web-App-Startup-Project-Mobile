/// Notification model for API responses
class NotificationModel {
  final int id;
  final int userId;
  final String type;
  final String category;
  final String title;
  final String message;
  final String? referenceType;
  final int? referenceId;
  final Map<String, dynamic>? data;
  final bool read;
  final DateTime? readAt;
  final String? actionUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? reference;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.title,
    required this.message,
    this.referenceType,
    this.referenceId,
    this.data,
    required this.read,
    this.readAt,
    this.actionUrl,
    required this.createdAt,
    required this.updatedAt,
    this.reference,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      type: json['type'] as String? ?? 'system',
      category: json['category'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as int?,
      data: json['data'] as Map<String, dynamic>?,
      read: json['read'] == true || json['read'] == 1,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      actionUrl: json['action_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      reference: json['reference'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'category': category,
      'title': title,
      'message': message,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'data': data,
      'read': read,
      'read_at': readAt?.toIso8601String(),
      'action_url': actionUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'reference': reference,
    };
  }

  /// Create a copy with updated read status
  NotificationModel copyWith({
    int? id,
    int? userId,
    String? type,
    String? category,
    String? title,
    String? message,
    String? referenceType,
    int? referenceId,
    Map<String, dynamic>? data,
    bool? read,
    DateTime? readAt,
    String? actionUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? reference,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      message: message ?? this.message,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      data: data ?? this.data,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      actionUrl: actionUrl ?? this.actionUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reference: reference ?? this.reference,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, type: $type, title: $title, read: $read)';
  }
}

/// Paginated response wrapper for notifications
class NotificationPaginatedResponse {
  final List<NotificationModel> notifications;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int from;
  final int to;
  final String? nextPageUrl;
  final String? prevPageUrl;

  NotificationPaginatedResponse({
    required this.notifications,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.from,
    required this.to,
    this.nextPageUrl,
    this.prevPageUrl,
  });

  factory NotificationPaginatedResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    return NotificationPaginatedResponse(
      notifications: dataList
          .map((item) =>
              NotificationModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      from: json['from'] as int? ?? 0,
      to: json['to'] as int? ?? 0,
      nextPageUrl: json['next_page_url'] as String?,
      prevPageUrl: json['prev_page_url'] as String?,
    );
  }

  bool get hasMorePages => currentPage < lastPage;
  bool get isEmpty => notifications.isEmpty;
}

