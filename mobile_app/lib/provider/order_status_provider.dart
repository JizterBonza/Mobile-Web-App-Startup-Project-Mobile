import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/order_status.dart';
import '../services/order_status_service.dart';
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

/// Provider for managing order status state and caching
class OrderStatusProvider with ChangeNotifier {
  final OrderStatusService _orderStatusService = OrderStatusService();

  List<OrderStatus> _orderStatuses = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<OrderStatus> get orderStatuses => _orderStatuses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  /// Fetch order statuses from API and store in Hive
  Future<void> fetchAndCacheOrderStatuses() async {
    // Check if already initialized to avoid unnecessary API calls
    if (_isInitialized && _orderStatuses.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please login.');
      }

      final response = await http.get(
        Uri.parse(ApiEndpoints.getOrderStatus),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds');
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        List<OrderStatus> statuses = [];

        // Handle different response formats
        List<dynamic> statusList = [];
        if (responseData is Map) {
          if (responseData['success'] == true && responseData['data'] != null) {
            statusList = responseData['data'] is List
                ? responseData['data']
                : [responseData['data']];
          } else if (responseData['data'] != null) {
            statusList = responseData['data'] is List
                ? responseData['data']
                : [responseData['data']];
          }
        } else if (responseData is List) {
          statusList = responseData;
        }

        // Convert JSON to OrderStatus objects
        // Expected format: {"id": 1, "stat_description": "Pending"}
        for (var item in statusList) {
          try {
            // Try the expected format first: id and stat_description
            final statusId = item['id'] ?? item['status_id'];
            final statusDesc = item['stat_description'] ?? item['status_desc'];

            if (statusId != null && statusDesc != null) {
              statuses.add(OrderStatus(
                status_id:
                    statusId is int ? statusId : int.parse(statusId.toString()),
                status_desc: statusDesc.toString(),
              ));
            }
          } catch (e) {
            print('Error parsing order status item: $e');
          }
        }

        // Store in Hive
        if (statuses.isNotEmpty) {
          await _orderStatusService.storeOrderStatuses(statuses);
          _orderStatuses = statuses;
          _isInitialized = true;
          _error = null;
        } else {
          // Try to load from cache if API returns empty
          await _loadFromCache();
        }
      } else {
        throw Exception(
            'Failed to fetch order statuses: ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      print('Error fetching order statuses: $e');
      // Try to load from cache on error
      await _loadFromCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load order statuses from Hive cache
  Future<void> _loadFromCache() async {
    try {
      final cachedStatuses = await _orderStatusService.fetchAllOrderStatuses();
      if (cachedStatuses.isNotEmpty) {
        _orderStatuses = cachedStatuses;
        _isInitialized = true;
      }
    } catch (e) {
      print('Error loading from cache: $e');
    }
  }

  /// Get order status by ID (from cache)
  OrderStatus? getOrderStatusById(int statusId) {
    try {
      return _orderStatuses.firstWhere(
        (status) => status.status_id == statusId,
        orElse: () => throw Exception('Status not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get order status description by ID
  String? getOrderStatusDescription(int statusId) {
    final status = getOrderStatusById(statusId);
    return status?.status_desc;
  }

  /// Get order status ID by description (case-insensitive)
  /// Returns null if not found
  int? getOrderStatusIdByDescription(String description) {
    final normalizedDesc = description.toLowerCase().trim();

    try {
      final status = _orderStatuses.firstWhere(
        (status) => status.status_desc.toLowerCase().trim() == normalizedDesc,
        orElse: () => throw Exception('Status not found'),
      );
      return status.status_id;
    } catch (e) {
      // Also try matching with common variations
      final variations = [
        normalizedDesc,
        normalizedDesc.replaceAll('-', ' '),
        normalizedDesc.replaceAll(' ', '-'),
      ];

      for (var variation in variations) {
        try {
          final status = _orderStatuses.firstWhere(
            (status) => status.status_desc.toLowerCase().trim() == variation,
          );
          return status.status_id;
        } catch (_) {
          continue;
        }
      }

      return null;
    }
  }

  /// Clear order statuses cache
  Future<void> clearCache() async {
    await _orderStatusService.clearOrderStatuses();
    _orderStatuses = [];
    _isInitialized = false;
    _error = null;
    notifyListeners();
  }

  /// Initialize order statuses (loads from cache first, then fetches from API)
  Future<void> initialize() async {
    // Load from cache first for immediate availability
    await _loadFromCache();
    notifyListeners();

    // Then fetch from API to ensure data is up to date
    await fetchAndCacheOrderStatuses();
  }
}
