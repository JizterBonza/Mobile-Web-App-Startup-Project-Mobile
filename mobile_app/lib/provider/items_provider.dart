import 'package:flutter/material.dart';
import '../services/items_services.dart';

/// Provider for managing items state and caching
class ItemsProvider with ChangeNotifier {
  final ItemsService _itemsService = ItemsService();

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;

  // Reviews cache: itemId -> item data with reviews
  Map<dynamic, Map<String, dynamic>> _itemReviews = {};
  Map<dynamic, bool> _reviewsLoading = {};
  Map<dynamic, String?> _reviewsError = {};

  List<Map<String, dynamic>> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get fromCache => _fromCache;

  /// Fetch items from API, falls back to cache if API fails
  Future<void> fetchItems({bool useCache = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final items = await _itemsService.fetchItems();
      if (items.isNotEmpty) {
        _items = items;
        _fromCache = false;
        _error = null;
      }
    } catch (e) {
      if (useCache && _items.isNotEmpty) {
        // Use cached data if available
        _fromCache = true;
        _error = null;
        print('Using cached items due to connection error: $e');
      } else {
        _error = e.toString();
        if (_items.isEmpty) {
          _items = [];
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear items cache
  void clearCache() {
    _items = [];
    _fromCache = false;
    _error = null;
    notifyListeners();
  }

  /// Get cached items without fetching from API
  List<Map<String, dynamic>> getCachedItems() {
    return _items;
  }

  /// Get a specific item by ID from cached items
  Map<String, dynamic>? getItemById(dynamic id) {
    try {
      final item = _items.firstWhere(
        (item) => item['id'] == id,
      );
      return item;
    } catch (e) {
      return null;
    }
  }

  /// Fetch item reviews from API
  Future<void> fetchItemReviews(dynamic itemId) async {
    _reviewsLoading[itemId] = true;
    _reviewsError[itemId] = null;
    notifyListeners();

    try {
      final itemData = await _itemsService.fetchItemReviews(itemId.toString());
      if (itemData.isNotEmpty) {
        _itemReviews[itemId] = itemData;
        _reviewsError[itemId] = null;
      }
    } catch (e) {
      _reviewsError[itemId] = e.toString();
      print('Error fetching item reviews: $e');
    } finally {
      _reviewsLoading[itemId] = false;
      notifyListeners();
    }
  }

  /// Get item reviews from cache
  Map<String, dynamic>? getItemReviews(dynamic itemId) {
    return _itemReviews[itemId];
  }

  /// Check if reviews are loading for an item
  bool isReviewsLoading(dynamic itemId) {
    return _reviewsLoading[itemId] ?? false;
  }

  /// Get reviews error for an item
  String? getReviewsError(dynamic itemId) {
    return _reviewsError[itemId];
  }

  /// Get reviews list for an item
  List<Map<String, dynamic>> getReviewsList(dynamic itemId) {
    final itemData = _itemReviews[itemId];
    if (itemData != null && itemData['reviews'] != null) {
      return List<Map<String, dynamic>>.from(itemData['reviews']);
    }
    return [];
  }
}
