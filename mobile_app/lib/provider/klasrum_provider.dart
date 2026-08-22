import 'package:flutter/material.dart';
import '../services/klasrum_service.dart';

class KlasrumProvider with ChangeNotifier {
  final KlasrumService _service = KlasrumService();

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _contents = [];
  List<Map<String, dynamic>> _featured = [];
  bool _isCategoriesLoading = false;
  bool _isContentsLoading = false;
  bool _isFeaturedLoading = false;
  String? _categoriesError;
  String? _contentsError;
  String? _featuredError;

  List<Map<String, dynamic>> get categories => _categories;
  List<Map<String, dynamic>> get contents => _contents;
  List<Map<String, dynamic>> get featured => _featured;
  Map<String, dynamic>? get featuredContent =>
      _featured.isNotEmpty ? _featured.first : null;
  bool get isCategoriesLoading => _isCategoriesLoading;
  bool get isContentsLoading => _isContentsLoading;
  bool get isFeaturedLoading => _isFeaturedLoading;
  String? get categoriesError => _categoriesError;
  String? get contentsError => _contentsError;
  String? get featuredError => _featuredError;

  Future<void> fetchCategories() async {
    _isCategoriesLoading = true;
    _categoriesError = null;
    notifyListeners();

    try {
      _categories = await _service.fetchCategories();
      _categoriesError = null;
    } catch (e) {
      _categoriesError = e.toString();
      if (_categories.isEmpty) {
        _categories = [];
      }
    } finally {
      _isCategoriesLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchContents({
    dynamic categoryId,
    String? search,
  }) async {
    _isContentsLoading = true;
    _contentsError = null;
    notifyListeners();

    try {
      _contents = await _service.fetchContents(
        categoryId: categoryId,
        search: search,
      );
      _contentsError = null;
    } catch (e) {
      _contentsError = e.toString();
      if (_contents.isEmpty) {
        _contents = [];
      }
    } finally {
      _isContentsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFeatured() async {
    _isFeaturedLoading = true;
    _featuredError = null;
    notifyListeners();

    try {
      _featured = await _service.fetchFeatured();
      _featuredError = null;
    } catch (e) {
      _featuredError = e.toString();
      if (_featured.isEmpty) {
        _featured = [];
      }
    } finally {
      _isFeaturedLoading = false;
      notifyListeners();
    }
  }
}
