import 'package:flutter/material.dart';
import '../services/badge_service.dart';

/// Provider for cart and notification badge counts from `/api/badges`.
class BadgeProvider with ChangeNotifier {
  final BadgeService _badgeService = BadgeService();

  int _cartCount = 0;
  int _unreadNotifications = 0;
  bool _isLoading = false;
  String? _error;

  int get cartCount => _cartCount;
  int get unreadNotifications => _unreadNotifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Display string for a badge count (empty when 0; caps at 99+).
  static String? formatBadgeCount(int count) {
    if (count <= 0) return null;
    if (count > 99) return '99+';
    return count.toString();
  }

  Future<void> fetchBadges() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _badgeService.fetchBadges();
      if (result['success'] == true && result['data'] is Map) {
        final data = result['data'] as Map;
        _cartCount = data['cart_count'] as int? ?? 0;
        _unreadNotifications = data['unread_notifications'] as int? ?? 0;
        _error = null;
      } else {
        _error = result['message']?.toString();
        // Keep last known counts on failure.
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUnreadNotifications(int count) {
    final next = count < 0 ? 0 : count;
    if (_unreadNotifications == next) return;
    _unreadNotifications = next;
    notifyListeners();
  }

  void setCartCount(int count) {
    final next = count < 0 ? 0 : count;
    if (_cartCount == next) return;
    _cartCount = next;
    notifyListeners();
  }

  /// Reset counts for guest / logout.
  void clear() {
    _cartCount = 0;
    _unreadNotifications = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
