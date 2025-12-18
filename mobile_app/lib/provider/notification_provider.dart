import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../models/notificationModel.dart';

/// Provider for managing notifications state with pagination support
class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _unreadCount = 0;
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _hasMorePages = false;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  int get total => _total;
  bool get hasMorePages => _hasMorePages;

  /// Get notifications grouped by read status
  List<NotificationModel> get unreadNotifications =>
      _notifications.where((n) => !n.read).toList();

  List<NotificationModel> get readNotifications =>
      _notifications.where((n) => n.read).toList();

  /// Fetch notifications (first page or refresh)
  Future<void> fetchNotifications({
    String? type,
    String? category,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _notifications = [];
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _notificationService.fetchNotifications(
        page: 1,
        type: type,
        category: category,
      );

      if (result['success'] == true && result['data'] != null) {
        final paginatedResponse =
            result['data'] as NotificationPaginatedResponse;
        _notifications = paginatedResponse.notifications;
        _currentPage = paginatedResponse.currentPage;
        _lastPage = paginatedResponse.lastPage;
        _total = paginatedResponse.total;
        _hasMorePages = paginatedResponse.hasMorePages;
        _error = null;

        // Update unread count from the fetched notifications
        _unreadCount = _notifications.where((n) => !n.read).length;
      } else {
        _error = result['message'] ?? 'Failed to fetch notifications';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMoreNotifications({
    String? type,
    String? category,
  }) async {
    if (_isLoadingMore || !_hasMorePages) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final result = await _notificationService.fetchNotifications(
        page: nextPage,
        type: type,
        category: category,
      );

      if (result['success'] == true && result['data'] != null) {
        final paginatedResponse =
            result['data'] as NotificationPaginatedResponse;
        _notifications.addAll(paginatedResponse.notifications);
        _currentPage = paginatedResponse.currentPage;
        _lastPage = paginatedResponse.lastPage;
        _total = paginatedResponse.total;
        _hasMorePages = paginatedResponse.hasMorePages;
      }
    } catch (e) {
      print('Error loading more notifications: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Fetch unread count from API
  Future<void> fetchUnreadCount() async {
    try {
      final result = await _notificationService.getUnreadCount();
      if (result['success'] == true) {
        _unreadCount = result['data'] as int? ?? 0;
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching unread count: $e');
    }
  }

  /// Mark a single notification as read
  Future<bool> markAsRead(int notificationId) async {
    try {
      final result = await _notificationService.markAsRead(notificationId);

      if (result['success'] == true) {
        // Update local state
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(
            read: true,
            readAt: DateTime.now(),
          );
          _unreadCount = _notifications.where((n) => !n.read).length;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final result = await _notificationService.markAllAsRead();

      if (result['success'] == true) {
        // Update local state
        _notifications = _notifications.map((n) {
          return n.copyWith(read: true, readAt: DateTime.now());
        }).toList();
        _unreadCount = 0;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete a single notification
  Future<bool> deleteNotification(int notificationId) async {
    // Store for potential rollback
    final deletedNotification = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => throw Exception('Notification not found'),
    );
    final deletedIndex =
        _notifications.indexWhere((n) => n.id == notificationId);

    // Optimistic update
    _notifications.removeWhere((n) => n.id == notificationId);
    _total = _total > 0 ? _total - 1 : 0;
    if (!deletedNotification.read) {
      _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
    }
    notifyListeners();

    try {
      final result =
          await _notificationService.deleteNotification(notificationId);

      if (result['success'] != true) {
        // Rollback on failure
        _notifications.insert(deletedIndex, deletedNotification);
        _total += 1;
        if (!deletedNotification.read) {
          _unreadCount += 1;
        }
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      // Rollback on error
      _notifications.insert(deletedIndex, deletedNotification);
      _total += 1;
      if (!deletedNotification.read) {
        _unreadCount += 1;
      }
      notifyListeners();
      print('Error deleting notification: $e');
      return false;
    }
  }

  /// Clear all read notifications
  Future<bool> clearReadNotifications() async {
    // Store for potential rollback
    final readNotifications = _notifications.where((n) => n.read).toList();

    // Optimistic update
    _notifications.removeWhere((n) => n.read);
    _total = _notifications.length;
    notifyListeners();

    try {
      final result = await _notificationService.clearReadNotifications();

      if (result['success'] != true) {
        // Rollback on failure
        _notifications.addAll(readNotifications);
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _total = _notifications.length;
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      // Rollback on error
      _notifications.addAll(readNotifications);
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _total = _notifications.length;
      notifyListeners();
      print('Error clearing read notifications: $e');
      return false;
    }
  }

  /// Clear all cached notifications
  void clearCache() {
    _notifications = [];
    _currentPage = 1;
    _lastPage = 1;
    _total = 0;
    _hasMorePages = false;
    _unreadCount = 0;
    _error = null;
    notifyListeners();
  }

  /// Get notification by ID
  NotificationModel? getNotificationById(int id) {
    try {
      return _notifications.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Filter notifications by type
  List<NotificationModel> getNotificationsByType(String type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Filter notifications by category
  List<NotificationModel> getNotificationsByCategory(String category) {
    return _notifications.where((n) => n.category == category).toList();
  }
}

