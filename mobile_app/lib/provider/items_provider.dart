import 'package:flutter/material.dart';
import '../services/items_services.dart';

/// Provider for managing items state and caching
class ItemsProvider with ChangeNotifier {
  final ItemsService _itemsService = ItemsService();

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;

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
}
