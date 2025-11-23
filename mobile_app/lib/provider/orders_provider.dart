import 'package:flutter/material.dart';
import '../services/order_service.dart';

/// Provider for managing orders state and caching
class OrdersProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;
  int _count = 0;

  List<Map<String, dynamic>> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get fromCache => _fromCache;
  int get count => _count;

  /// Fetch orders from API, falls back to cache if API fails
  Future<void> fetchOrders({
    String? status,
    bool useCache = true,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _orderService.fetchOrders(status: status);
      final orders = result['orders'] as List<Map<String, dynamic>>;
      if (orders.isNotEmpty) {
        _orders = orders;
        _count = result['count'] as int;
        _fromCache = false;
        _error = null;
      }
    } catch (e) {
      if (useCache && _orders.isNotEmpty) {
        // Use cached data if available
        _fromCache = true;
        _error = null;
        print('Using cached orders due to connection error: $e');
      } else {
        _error = e.toString();
        if (_orders.isEmpty) {
          _orders = [];
          _count = 0;
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear orders cache
  void clearCache() {
    _orders = [];
    _count = 0;
    _fromCache = false;
    _error = null;
    notifyListeners();
  }

  /// Get cached orders without fetching from API
  List<Map<String, dynamic>> getCachedOrders() {
    return _orders;
  }

  /// Update order in the list after status update
  void updateOrderInList(String orderId, Map<String, dynamic> updatedOrder) {
    final index = _orders.indexWhere((order) => order['id'] == orderId);
    if (index != -1) {
      _orders[index] = updatedOrder;
      notifyListeners();
    }
  }

  /// Remove order from the list
  void removeOrder(String orderId) {
    _orders.removeWhere((order) => order['id'] == orderId);
    _count = _orders.length;
    notifyListeners();
  }
}
