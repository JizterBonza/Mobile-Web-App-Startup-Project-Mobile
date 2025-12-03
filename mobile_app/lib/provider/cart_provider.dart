import 'package:flutter/material.dart';
import '../services/cart_services.dart';
import '../services/api_service.dart';

/// Provider for managing cart state and caching
class CartProvider with ChangeNotifier {
  final CartService _cartService = CartService();

  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;
  Set<String> _selectedItems = {}; // Track selected items by their ID

  List<Map<String, dynamic>> get cartItems => _cartItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get fromCache => _fromCache;
  Set<String> get selectedItems => _selectedItems;

  /// Get effective price - use item_price if different from price_snapshot
  double _getEffectivePrice(Map<String, dynamic> item) {
    final priceSnapshot = double.parse(item['price_snapshot'].toString());
    final itemPrice = double.parse(item['item_price'].toString());
    return priceSnapshot != itemPrice ? itemPrice : priceSnapshot;
  }

  /// Check if item quantity exceeds available stock
  bool isQuantityValid(Map<String, dynamic> item) {
    final quantity = item['quantity'] as int;
    final itemQuantity = int.parse(item['item_quantity'].toString());
    return quantity <= itemQuantity;
  }

  /// Check if item is out of stock
  bool isOutOfStock(Map<String, dynamic> item) {
    final itemQuantity = int.parse(item['item_quantity'].toString());
    return itemQuantity <= 0;
  }

  /// Get selected items count
  int get selectedItemsCount => _selectedItems.length;

  /// Get subtotal for selected items
  double get subtotal {
    return _cartItems.fold(0.0, (sum, item) {
      final itemId = item['id'].toString();
      // Only include checked items with valid quantity
      if (!_selectedItems.contains(itemId) || !isQuantityValid(item)) {
        return sum;
      }
      final effectivePrice = _getEffectivePrice(item);
      return sum + (effectivePrice * (item['quantity'] as int));
    });
  }

  /// Fetch cart items from API, falls back to cache if API fails
  Future<void> fetchCartItems({bool useCache = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        throw Exception('User not logged in');
      }

      final cartItems = await _cartService.fetchCartItemsFromAPI(userId);
      if (cartItems.isNotEmpty || _cartItems.isEmpty) {
        _cartItems = cartItems;
        _fromCache = false;
        _error = null;

        // Remove any invalid items from selection
        final itemsToRemove = <String>[];
        for (var item in cartItems) {
          final itemId = item['id'].toString();
          if (!isQuantityValid(item) && _selectedItems.contains(itemId)) {
            itemsToRemove.add(itemId);
          }
        }
        _selectedItems.removeAll(itemsToRemove);
      }
    } catch (e) {
      if (useCache && _cartItems.isNotEmpty) {
        // Use cached data if available
        _fromCache = true;
        _error = null;
        print('Using cached cart items due to connection error: $e');
      } else {
        _error = e.toString();
        if (_cartItems.isEmpty) {
          _cartItems = [];
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add item to cart
  Future<Map<String, dynamic>> addToCart({
    required String itemId,
    required double price,
    required int quantity,
  }) async {
    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        return {
          'success': false,
          'message': 'User not logged in',
          'data': null,
        };
      }

      final result = await _cartService.addToCart(
        userId: userId,
        itemId: itemId,
        price: price,
        quantity: quantity,
      );

      if (result['success'] == true) {
        // Refresh cart items after successful add
        await fetchCartItems(useCache: false);
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error adding to cart: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Remove item from cart
  Future<Map<String, dynamic>> removeCartItem(String cartItemId) async {
    try {
      final result = await _cartService.removeCartItem(cartItemId);

      if (result['success'] == true) {
        // Remove from local state
        _cartItems.removeWhere((item) => item['id'].toString() == cartItemId);
        _selectedItems.remove(cartItemId);
        notifyListeners();
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error removing item: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Clear all items from cart
  Future<Map<String, dynamic>> clearAllCartItems() async {
    try {
      if (_cartItems.isEmpty) {
        return {
          'success': true,
          'message': 'Cart is already empty',
          'data': null,
        };
      }

      final cartItemIds =
          _cartItems.map((item) => item['id'].toString()).toList();
      final result = await _cartService.clearAllCartItems(cartItemIds);

      if (result['success'] == true) {
        // Clear local state
        _cartItems.clear();
        _selectedItems.clear();
        notifyListeners();
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error clearing cart: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Update item quantity in local state (optimistic update)
  void updateItemQuantity(String cartItemId, int newQuantity) {
    final index = _cartItems.indexWhere(
      (item) => item['id'].toString() == cartItemId,
    );
    if (index != -1) {
      _cartItems[index]['quantity'] = newQuantity;
      // Unselect item if quantity becomes invalid
      if (!isQuantityValid(_cartItems[index]) &&
          _selectedItems.contains(cartItemId)) {
        _selectedItems.remove(cartItemId);
      }
      notifyListeners();
    }
  }

  /// Toggle item selection
  void toggleItemSelection(String itemId) {
    final item = _cartItems.firstWhere(
      (item) => item['id'].toString() == itemId,
      orElse: () => {},
    );

    if (item.isEmpty) return;

    // Only allow selection if quantity is valid
    if (!isQuantityValid(item)) return;

    if (_selectedItems.contains(itemId)) {
      _selectedItems.remove(itemId);
    } else {
      _selectedItems.add(itemId);
    }
    notifyListeners();
  }

  /// Select all valid items
  void selectAllItems() {
    _selectedItems.clear();
    for (var item in _cartItems) {
      if (isQuantityValid(item)) {
        _selectedItems.add(item['id'].toString());
      }
    }
    notifyListeners();
  }

  /// Deselect all items
  void deselectAllItems() {
    _selectedItems.clear();
    notifyListeners();
  }

  /// Get selected cart items for checkout
  List<Map<String, dynamic>> getSelectedCartItems() {
    return _cartItems.where((item) {
      final itemId = item['id'].toString();
      return _selectedItems.contains(itemId) && isQuantityValid(item);
    }).toList();
  }

  /// Clear cart cache
  void clearCache() {
    _cartItems = [];
    _selectedItems.clear();
    _fromCache = false;
    _error = null;
    notifyListeners();
  }

  /// Get cached cart items without fetching from API
  List<Map<String, dynamic>> getCachedCartItems() {
    return _cartItems;
  }

  /// Get a specific cart item by ID
  Map<String, dynamic>? getCartItemById(String cartItemId) {
    try {
      final item = _cartItems.firstWhere(
        (item) => item['id'].toString() == cartItemId,
      );
      return item;
    } catch (e) {
      return null;
    }
  }

  /// Check if an item is selected
  bool isItemSelected(String itemId) {
    return _selectedItems.contains(itemId);
  }
}
