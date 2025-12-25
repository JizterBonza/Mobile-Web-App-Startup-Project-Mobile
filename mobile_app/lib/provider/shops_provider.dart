import 'package:flutter/material.dart';
import '../services/shops_service.dart';

/// Provider for managing shops state and caching
class ShopsProvider with ChangeNotifier {
  final ShopsService _shopsService = ShopsService();

  List<Map<String, dynamic>> _shops = [];
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;

  // Shop details cache: shopId -> shop data
  Map<dynamic, Map<String, dynamic>> _shopDetails = {};
  Map<dynamic, bool> _detailsLoading = {};
  Map<dynamic, String?> _detailsError = {};

  // Shop items cache: shopId -> items list
  Map<dynamic, List<Map<String, dynamic>>> _shopItems = {};
  Map<dynamic, bool> _itemsLoading = {};
  Map<dynamic, String?> _itemsError = {};

  // Shop reviews cache: shopId -> reviews data
  Map<dynamic, Map<String, dynamic>> _shopReviews = {};
  Map<dynamic, bool> _reviewsLoading = {};
  Map<dynamic, String?> _reviewsError = {};

  List<Map<String, dynamic>> get shops => _shops;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get fromCache => _fromCache;

  /// Fetch shops from API, falls back to cache if API fails
  Future<void> fetchShops({bool useCache = true, int? limit}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final shops = await _shopsService.fetchShops(limit: limit);
      if (shops.isNotEmpty) {
        _shops = shops;
        _fromCache = false;
        _error = null;
      }
    } catch (e) {
      if (useCache && _shops.isNotEmpty) {
        // Use cached data if available
        _fromCache = true;
        _error = null;
        //print('Using cached shops due to connection error: $e');
      } else {
        _error = e.toString();
        if (_shops.isEmpty) {
          _shops = [];
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear shops cache
  void clearCache() {
    _shops = [];
    _fromCache = false;
    _error = null;
    notifyListeners();
  }

  /// Get cached shops without fetching from API
  List<Map<String, dynamic>> getCachedShops() {
    return _shops;
  }

  /// Get a specific shop by ID from cached shops
  Map<String, dynamic>? getShopById(dynamic id) {
    try {
      final shop = _shops.firstWhere(
        (shop) => shop['id'] == id,
      );
      return shop;
    } catch (e) {
      return null;
    }
  }

  /// Fetch shop details from API
  Future<void> fetchShopDetails(dynamic shopId) async {
    _detailsLoading[shopId] = true;
    _detailsError[shopId] = null;
    notifyListeners();

    try {
      final shopData = await _shopsService.fetchShopById(shopId.toString());
      if (shopData.isNotEmpty) {
        _shopDetails[shopId] = shopData;
        _detailsError[shopId] = null;
      }
    } catch (e) {
      _detailsError[shopId] = e.toString();
      //print('Error fetching shop details: $e');
    } finally {
      _detailsLoading[shopId] = false;
      notifyListeners();
    }
  }

  /// Get shop details from cache
  Map<String, dynamic>? getShopDetails(dynamic shopId) {
    return _shopDetails[shopId];
  }

  /// Check if details are loading for a shop
  bool isDetailsLoading(dynamic shopId) {
    return _detailsLoading[shopId] ?? false;
  }

  /// Get details error for a shop
  String? getDetailsError(dynamic shopId) {
    return _detailsError[shopId];
  }

  /// Fetch shop items from API
  Future<void> fetchShopItems(dynamic shopId) async {
    _itemsLoading[shopId] = true;
    _itemsError[shopId] = null;
    notifyListeners();

    try {
      final items = await _shopsService.fetchShopItems(shopId.toString());
      _shopItems[shopId] = items;
      _itemsError[shopId] = null;
      //print('Provider: Fetched ${items.length} items for shop $shopId');
    } catch (e) {
      _itemsError[shopId] = e.toString();
      _shopItems[shopId] = [];
      //print('Error fetching shop items: $e');
    } finally {
      _itemsLoading[shopId] = false;
      notifyListeners();
    }
  }

  /// Get shop items from cache
  List<Map<String, dynamic>> getShopItems(dynamic shopId) {
    return _shopItems[shopId] ?? [];
  }

  /// Check if items are loading for a shop
  bool isItemsLoading(dynamic shopId) {
    return _itemsLoading[shopId] ?? false;
  }

  /// Get items error for a shop
  String? getItemsError(dynamic shopId) {
    return _itemsError[shopId];
  }

  /// Fetch shop reviews from API
  Future<void> fetchShopReviews(dynamic shopId) async {
    _reviewsLoading[shopId] = true;
    _reviewsError[shopId] = null;
    notifyListeners();

    try {
      final reviewsData =
          await _shopsService.fetchShopReviews(shopId.toString());
      if (reviewsData.isNotEmpty) {
        _shopReviews[shopId] = reviewsData;
        _reviewsError[shopId] = null;
      }
    } catch (e) {
      _reviewsError[shopId] = e.toString();
      //print('Error fetching shop reviews: $e');
    } finally {
      _reviewsLoading[shopId] = false;
      notifyListeners();
    }
  }

  /// Get shop reviews from cache
  Map<String, dynamic>? getShopReviews(dynamic shopId) {
    return _shopReviews[shopId];
  }

  /// Get reviews list for a shop
  List<Map<String, dynamic>> getShopReviewsList(dynamic shopId) {
    final reviewsData = _shopReviews[shopId];
    if (reviewsData != null && reviewsData['reviews'] != null) {
      return List<Map<String, dynamic>>.from(reviewsData['reviews']);
    }
    return [];
  }

  /// Check if reviews are loading for a shop
  bool isReviewsLoading(dynamic shopId) {
    return _reviewsLoading[shopId] ?? false;
  }

  /// Get reviews error for a shop
  String? getReviewsError(dynamic shopId) {
    return _reviewsError[shopId];
  }
}
