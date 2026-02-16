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

  // Search state
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  String _lastSearchQuery = '';

  // Category items state
  List<Map<String, dynamic>> _categoryItems = [];
  bool _isCategoryLoading = false;
  String? _categoryError;
  dynamic _selectedCategoryId;

  List<Map<String, dynamic>> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get fromCache => _fromCache;

  // Search getters
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  String get lastSearchQuery => _lastSearchQuery;

  // Category items getters
  List<Map<String, dynamic>> get categoryItems => _categoryItems;
  bool get isCategoryLoading => _isCategoryLoading;
  String? get categoryError => _categoryError;
  dynamic get selectedCategoryId => _selectedCategoryId;

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

  /// Search items from API
  Future<List<Map<String, dynamic>>> searchItems(String query,
      {int limit = 20}) async {
    if (query.trim().length < 2) {
      _searchResults = [];
      _isSearching = false;
      _searchError = null;
      _lastSearchQuery = '';
      notifyListeners();
      return [];
    }

    _isSearching = true;
    _searchError = null;
    _lastSearchQuery = query;
    notifyListeners();

    try {
      final results = await _itemsService.searchItems(query, limit: limit);
      _searchResults = results;
      _searchError = null;
    } catch (e) {
      _searchError = e.toString();
      _searchResults = [];
      print('Search error: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }

    return _searchResults;
  }

  /// Clear search results
  void clearSearch() {
    _searchResults = [];
    _isSearching = false;
    _searchError = null;
    _lastSearchQuery = '';
    notifyListeners();
  }

  /// Fetch items by category from API
  Future<void> fetchItemsByCategory(dynamic categoryId) async {
    _isCategoryLoading = true;
    _categoryError = null;
    _selectedCategoryId = categoryId;
    notifyListeners();

    try {
      final items = await _itemsService.fetchItemsByCategory(categoryId);
      _categoryItems = items;
      _categoryError = null;
    } catch (e) {
      _categoryError = e.toString();
      _categoryItems = [];
      print('Error fetching category items: $e');
    } finally {
      _isCategoryLoading = false;
      notifyListeners();
    }
  }

  /// Clear category selection and items
  void clearCategorySelection() {
    _categoryItems = [];
    _isCategoryLoading = false;
    _categoryError = null;
    _selectedCategoryId = null;
    notifyListeners();
  }
}
