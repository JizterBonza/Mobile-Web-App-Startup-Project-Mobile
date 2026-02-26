import 'package:hive_flutter/hive_flutter.dart';
import '../models/order_status.dart';

/// Service for managing order status storage in Hive
class OrderStatusService {
  static const String _boxName = 'order_statuses';

  /// Get or open the Hive box for order statuses
  Future<Box<OrderStatus>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<OrderStatus>(_boxName);
    }
    return Hive.box<OrderStatus>(_boxName);
  }

  /// Store an order status in Hive
  /// Uses status_id as the key for easy retrieval
  Future<bool> storeOrderStatus(OrderStatus orderStatus) async {
    try {
      final box = await _getBox();
      await box.put(orderStatus.status_id, orderStatus);
      return true;
    } catch (e) {
      print('Error storing order status: $e');
      return false;
    }
  }

  /// Store multiple order statuses in Hive
  Future<bool> storeOrderStatuses(List<OrderStatus> orderStatuses) async {
    try {
      final box = await _getBox();
      final Map<int, OrderStatus> statusMap = {};
      for (final status in orderStatuses) {
        statusMap[status.status_id] = status;
      }
      await box.putAll(statusMap);
      return true;
    } catch (e) {
      print('Error storing order statuses: $e');
      return false;
    }
  }

  /// Fetch an order status by ID
  /// Returns null if not found
  Future<OrderStatus?> fetchOrderStatusById(int statusId) async {
    try {
      final box = await _getBox();
      return box.get(statusId);
    } catch (e) {
      print('Error fetching order status by ID: $e');
      return null;
    }
  }

  /// Fetch all order statuses from Hive
  Future<List<OrderStatus>> fetchAllOrderStatuses() async {
    try {
      final box = await _getBox();
      return box.values.toList();
    } catch (e) {
      print('Error fetching all order statuses: $e');
      return [];
    }
  }

  /// Clear all order statuses from the Hive box
  Future<bool> clearOrderStatuses() async {
    try {
      final box = await _getBox();
      await box.clear();
      return true;
    } catch (e) {
      print('Error clearing order statuses: $e');
      return false;
    }
  }

  /// Delete a specific order status by ID
  Future<bool> deleteOrderStatusById(int statusId) async {
    try {
      final box = await _getBox();
      await box.delete(statusId);
      return true;
    } catch (e) {
      print('Error deleting order status by ID: $e');
      return false;
    }
  }
}
