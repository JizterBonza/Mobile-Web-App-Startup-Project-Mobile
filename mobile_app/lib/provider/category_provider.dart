import 'package:flutter/material.dart';
import '../services/category_service.dart';

/// Provider for managing categories state and caching
class CategoryProvider with ChangeNotifier {
  final CategoryService _categoryService = CategoryService();

  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;

  List<Map<String, dynamic>> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get fromCache => _fromCache;

  /// Fetch categories from API, falls back to cache if API fails
  Future<void> fetchCategories({bool useCache = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final categories = await _categoryService.fetchCategories();
      if (categories.isNotEmpty) {
        _categories = categories;
        _fromCache = false;
        _error = null;
      }
    } catch (e) {
      if (useCache && _categories.isNotEmpty) {
        // Use cached data if available
        _fromCache = true;
        _error = null;
        print('Using cached categories due to connection error: $e');
      } else {
        _error = e.toString();
        if (_categories.isEmpty) {
          _categories = [];
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear categories cache
  void clearCache() {
    _categories = [];
    _fromCache = false;
    _error = null;
    notifyListeners();
  }

  /// Get cached categories without fetching from API
  List<Map<String, dynamic>> getCachedCategories() {
    return _categories;
  }
}
