import 'package:flutter/material.dart';
import '../services/items_services.dart';
import '../models/catalog_search.dart';

/// Provider for managing items state and caching
class ItemsProvider with ChangeNotifier {
  ItemsProvider({ItemsService? itemsService})
      : _itemsService = itemsService ?? ItemsService();

  final ItemsService _itemsService;

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;

  // Reviews cache: itemId -> item data with reviews
  Map<dynamic, Map<String, dynamic>> _itemReviews = {};
  Map<dynamic, bool> _reviewsLoading = {};
  Map<dynamic, String?> _reviewsError = {};

  // Search state
  CatalogSearchResponse _catalogSearchResults = const CatalogSearchResponse();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  String _lastSearchQuery = '';
  int _searchRequestId = 0;
  bool _disposed = false;

  // Category items state
  List<Map<String, dynamic>> _categoryItems = [];
  bool _isCategoryLoading = false;
  String? _categoryError;
  dynamic _selectedCategoryId;
  int _categoryRequestId = 0;

  // On-sale items state
  List<Map<String, dynamic>> _onSaleItems = [];
  bool _isOnSaleLoading = false;
  String? _onSaleError;

  List<Map<String, dynamic>> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get fromCache => _fromCache;

  CatalogSearchResponse get catalogSearchResults => _catalogSearchResults;

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

  // On-sale items getters
  List<Map<String, dynamic>> get onSaleItems => _onSaleItems;
  bool get isOnSaleLoading => _isOnSaleLoading;
  String? get onSaleError => _onSaleError;

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
    for (final source in [
      _items,
      _categoryItems,
      _searchResults,
      _onSaleItems
    ]) {
      for (final item in source) {
        if (item['id']?.toString() == id?.toString()) return item;
      }
    }
    return null;
  }

  /// Fetch item reviews from API
  Future<void> fetchItemReviews(dynamic itemId) async {
    _reviewsLoading[itemId] = true;
    _reviewsError[itemId] = null;
    notifyListeners();

    try {
      final itemData = await _itemsService.fetchItemReviews(itemId.toString());
      if (_disposed) return;
      if (itemData.isNotEmpty) {
        _itemReviews[itemId] = itemData;
        _reviewsError[itemId] = null;
      } else {
        _reviewsError[itemId] = 'Product details are unavailable';
      }
    } catch (e) {
      if (_disposed) return;
      _reviewsError[itemId] = e.toString();
      print('Error fetching item reviews: $e');
    } finally {
      if (!_disposed) {
        _reviewsLoading[itemId] = false;
        notifyListeners();
      }
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

  /// Compatibility wrapper: grouped search state is updated atomically.
  Future<List<Map<String, dynamic>>> searchItems(String query,
          {int limit = 20}) async =>
      (await searchCatalog(query, limit: limit)).itemData;

  Future<CatalogSearchResponse> searchCatalog(String query,
      {int limit = 20}) async {
    final requestId = ++_searchRequestId;
    if (query.trim().length < 2) {
      _searchResults = [];
      _catalogSearchResults = const CatalogSearchResponse();
      _isSearching = false;
      _searchError = null;
      _lastSearchQuery = '';
      notifyListeners();
      return const CatalogSearchResponse();
    }

    _isSearching = true;
    _searchResults = [];
    _catalogSearchResults = const CatalogSearchResponse();
    _searchError = null;
    _lastSearchQuery = query;
    notifyListeners();

    try {
      final results = await _itemsService.searchCatalog(query, limit: limit);
      if (_disposed || requestId != _searchRequestId)
        return const CatalogSearchResponse();
      _catalogSearchResults = results;
      _searchResults = results.itemData;
      _searchError = null;
    } catch (e) {
      if (_disposed || requestId != _searchRequestId)
        return const CatalogSearchResponse();
      _searchError = e.toString();
      _searchResults = [];
      _catalogSearchResults = const CatalogSearchResponse();
      print('Search error: $e');
    } finally {
      if (!_disposed && requestId == _searchRequestId) {
        _isSearching = false;
        notifyListeners();
      }
    }

    return _catalogSearchResults;
  }

  /// Clear search results
  void clearSearch() {
    ++_searchRequestId;
    _catalogSearchResults = const CatalogSearchResponse();
    _searchResults = [];
    _isSearching = false;
    _searchError = null;
    _lastSearchQuery = '';
    notifyListeners();
  }

  /// Invalidates in-flight work without notifying listeners during teardown.
  void invalidateSearch() {
    ++_searchRequestId;
    _isSearching = false;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_searchRequestId;
    super.dispose();
  }

  /// Fetch items by category from API
  Future<void> fetchItemsByCategory(dynamic categoryId) async {
    final requestId = ++_categoryRequestId;
    _isCategoryLoading = true;
    _categoryError = null;
    _selectedCategoryId = categoryId;
    notifyListeners();

    try {
      final items = await _itemsService.fetchItemsByCategory(categoryId);
      if (requestId != _categoryRequestId) return;
      _categoryItems = items;
      _categoryError = null;
    } catch (e) {
      if (requestId != _categoryRequestId) return;
      _categoryError = e.toString();
      _categoryItems = [];
      print('Error fetching category items: $e');
    } finally {
      if (requestId == _categoryRequestId) {
        _isCategoryLoading = false;
        notifyListeners();
      }
    }
  }

  /// Clear category selection and items
  void clearCategorySelection() {
    _categoryRequestId++;
    _categoryItems = [];
    _isCategoryLoading = false;
    _categoryError = null;
    _selectedCategoryId = null;
    notifyListeners();
  }

  /// Fetch on-sale items from API
  Future<void> fetchItemsOnSale() async {
    _isOnSaleLoading = true;
    _onSaleError = null;
    notifyListeners();

    try {
      final items = await _itemsService.fetchItemsOnSale();
      _onSaleItems = items;
      _onSaleError = null;
    } catch (e) {
      _onSaleError = e.toString();
      _onSaleItems = [];
      print('Error fetching on-sale items: $e');
    } finally {
      _isOnSaleLoading = false;
      notifyListeners();
    }
  }
}
