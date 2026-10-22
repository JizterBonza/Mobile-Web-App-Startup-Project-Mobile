import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/category_provider.dart';
import '../../services/cart_services.dart';

import '../../services/api_service.dart';

import '../../utils/cart_item_pricing.dart';
import '../../utils/gamefowl_item.dart';
import '../../utils/snackbar_helper.dart';

import 'customerDashboardScreen.dart';

import 'checkOutScreen.dart';

class CartScreen extends StatefulWidget {

  const CartScreen({super.key});

  @override

  State<CartScreen> createState() => _CartScreenState();

}

class _CartScreenState extends State<CartScreen> {

  List<Map<String, dynamic>> _cartItems = [];

  final Set<String> _selectedItems = {};

  bool _isLoading = true;

  String? _errorMessage;
  bool _categoriesReady = false;
  Set<String> _selectedItems = {}; // Track selected items by their ID

  int _int(dynamic value, [int fallback = 0]) {

    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? fallback;

  }

  int? _parseId(dynamic value) {

    if (value is Map) {

      return _parseId(

        value['id'] ?? value['cart_id'] ?? value['cartId'],

      );

    }

    final id = _int(value, -1);

    return id > 0 ? id : null;

  }

  /// Retrieves the parent cart ID only.

  /// Never treats a cart-line ID or product ID as the parent cart ID.

  bool _isGamefowlCartItem(Map<String, dynamic> item) => isGamefowlItem(
        item,
        categories: context.read<CategoryProvider>().categories,
      );

  // Check if item quantity exceeds available stock
  bool _isQuantityValid(Map<String, dynamic> item) {
    final quantity = item['quantity'] as int;
    final itemQuantity = int.parse(item['item_quantity'].toString());
    return quantity <= itemQuantity;
  }

    final nestedCart = item['cart'];

    return _parseId(

      item['cart_id'] ??
          item['cartId'] ??
          item['parent_cart_id'] ??
          item['parentCartId'] ??
          (nestedCart is Map
              ? nestedCart['id'] ??
                  nestedCart['cart_id'] ??
                  nestedCart['cartId'] ??
                  nestedCart['parent_cart_id'] ??
                  nestedCart['parentCartId']
              : null),

  // Get subtotal for a specific shop
  double _getShopSubtotal(String shopId) {
    final shopItems = _cartItems
        .where((item) => item['shop_id']?.toString() == shopId)
        .toList();
    return shopItems.fold(0.0, (sum, item) {
      final itemId = item['id'].toString();
      if (!_categoriesReady || !_selectedItems.contains(itemId) || !_isQuantityValid(item) || _isGamefowlCartItem(item)) {
        return sum;
      }
      final effectivePrice = _getEffectivePrice(item);
      return sum + (effectivePrice * (item['quantity'] as int));
    });
  }

  // Get selected items count for a specific shop
  int _getShopSelectedItemsCount(String shopId) {
    final shopItems = _cartItems
        .where((item) => item['shop_id']?.toString() == shopId)
        .toList();
    return shopItems.where((item) {
      final itemId = item['id'].toString();
      return _categoriesReady && _selectedItems.contains(itemId) && _isQuantityValid(item) && !_isGamefowlCartItem(item);
    }).length;
  }

  // Get selected items for a specific shop
  List<Map<String, dynamic>> _getShopSelectedItems(String shopId) {
    final shopItems = _cartItems
        .where((item) => item['shop_id']?.toString() == shopId)
        .toList();
    return shopItems.where((item) {
      final itemId = item['id'].toString();
      return _categoriesReady && _selectedItems.contains(itemId) && _isQuantityValid(item) && !_isGamefowlCartItem(item);
    }).toList();
  }

  double get _subtotal {
    return _cartItems.fold(0.0, (sum, item) {
      final itemId = item['id'].toString();
      // Only include checked items with valid quantity (quantity <= item_quantity)
      if (!_categoriesReady || !_selectedItems.contains(itemId) || !_isQuantityValid(item) || _isGamefowlCartItem(item)) {
        return sum;
      }
      final effectivePrice = _getEffectivePrice(item);
      return sum + (effectivePrice * (item['quantity'] as int));
    });
  }

  double get _tax {
    return _subtotal * 0.08; // 8% tax
  }

  double get _total {
    //return _subtotal + _tax;
    return _subtotal;
  }

  int get _selectedItemsCount {
    return _selectedItems.length;
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
    } else {
      setState(() {
        _cartItems[index]['quantity'] = newQuantity;
        // Unselect item if quantity becomes invalid
        final itemId = _cartItems[index]['id'].toString();
        if (!_isQuantityValid(_cartItems[index]) &&
            _selectedItems.contains(itemId)) {
          _selectedItems.remove(itemId);
        }
      });
    }
  }

  void _toggleItemSelection(String itemId) {
    final matches = _cartItems.where((item) => item['id'].toString() == itemId);
    if (!_categoriesReady || matches.isEmpty || _isGamefowlCartItem(matches.first)) return;
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  Future<void> _clearAllItems() async {
    if (_cartItems.isEmpty) return;

    // Show confirmation dialog
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Cart'),
        content: Text(
            'Are you sure you want to remove all ${_cartItems.length} item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text('Clear All'),
          ),
        ],
      ),
    );

  }

  int? _resolveParentCartId(List<Map<String, dynamic>> items) {

    if (items.isEmpty) return null;

    final firstId = _rawCartId(items.first);

    if (firstId == null) return null;

    // All selected items must belong to the same parent cart.

    for (final item in items) {

      if (_rawCartId(item) != firstId) {

        debugPrint(

          'CHECKOUT ERROR: Items do not share the same parent cart ID.',

        );

        return null;

      }

    }

    return firstId;

  }

  bool _validQty(Map<String, dynamic> item) {

    final qty = _int(item['quantity']);

    final stock = _int(item['item_quantity']);

    return qty > 0 && stock > 0 && qty <= stock;

  }

  bool _outOfStock(Map<String, dynamic> item) {

    return _int(item['item_quantity']) <= 0;

  }

  double _price(Map<String, dynamic> item) {

    return CartItemPricing.fromCartMap(item).effectivePrice;

  }

  String _key(Map<String, dynamic> item) {

    return item['id']?.toString() ?? '';

  }

  Map<String, List<Map<String, dynamic>>> _groupItems() {

    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in _cartItems) {

      final shopId = item['shop_id']?.toString() ?? 'unknown';

      grouped.putIfAbsent(shopId, () => []).add(item);

    }

    return grouped;

  }

  String _shopName(

    String shopId,

    List<Map<String, dynamic>> items,

  ) {

    final name = items.isNotEmpty ? items.first['shop_name'] : null;

    if (name != null && name.toString().trim().isNotEmpty) {

      return name.toString();

    }

    return 'Shop $shopId';

  }

  List<Map<String, dynamic>> _selectedForShop(

    List<Map<String, dynamic>> items,

  ) {

    return items

        .where(

          (item) =>

              _selectedItems.contains(_key(item)) && _validQty(item),

        )

        .toList();

  }

  double _subtotal(List<Map<String, dynamic>> items) {

    return _selectedForShop(items).fold<double>(

      0,

      (sum, item) => sum + _price(item) * _int(item['quantity']),

    );

  }

  Future<void> _loadCartItems() async {

    if (mounted) {

      setState(() {

        _isLoading = true;

        _errorMessage = null;

      });

    }

    try {

      final userId = await ApiService.getUserId();

      if (userId == null || userId.isEmpty) {

        throw Exception('User not logged in.');

      }

      final categories = context.read<CategoryProvider>();
      if (categories.categories.isEmpty) await categories.fetchCategories();
      final cartItems = await CartService().fetchCartItemsFromAPI(userId);
      setState(() {
        _categoriesReady = categories.categories.isNotEmpty;
        _cartItems = cartItems;

        // Remove any invalid items from selection
        final itemsToRemove = <String>[];
        for (var item in cartItems) {
          final itemId = item['id'].toString();
          if ((!_categoriesReady || !_isQuantityValid(item) || _isGamefowlCartItem(item)) && _selectedItems.contains(itemId)) {
            itemsToRemove.add(itemId);
          }
        }
        _selectedItems.removeAll(itemsToRemove);

        _isLoading = false;

      });

    } catch (e, stackTrace) {

      debugPrint('CART LOAD ERROR: $e');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {

        _isLoading = false;

        _errorMessage = 'Failed to load cart items: $e';

      });

    }

  }

  void _openCheckout(List<Map<String, dynamic>> items) {

    if (items.isEmpty) {

      SnackbarHelper.showError(

        context,

        'Please select valid items to checkout.',

      );

      return;

    }

    final cartId = _resolveParentCartId(items);

    debugPrint('========== CHECKOUT DEBUG ==========');

    debugPrint('SELECTED ITEMS: ${items.length}');

    debugPrint('RESOLVED PARENT CART ID: $cartId');

    for (final item in items) {

      debugPrint(

        'Selected item: lineId=${item['id']}, '

        'cartId=${_rawCartId(item)}, '

        'productId=${item['item_id']}',

      );

    }

    debugPrint('====================================');

    if (cartId == null) {

      SnackbarHelper.showError(

        context,

        'Unable to identify the parent cart ID. '

        'Please check the CART DEBUG logs in Android Studio.',

      );

      return;

    }

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => CheckOutScreen(

          selectedCartItems: items,

          cartId: cartId,

        ),

      ),

    );

  }

  void _toggle(String id) {

    setState(() {

      if (_selectedItems.contains(id)) {

        _selectedItems.remove(id);

      } else {

        _selectedItems.add(id);

      }

    });

  }

  Future<void> _removeItem(Map<String, dynamic> item) async {

    final id = _key(item);

    if (id.isEmpty) {

      SnackbarHelper.showError(

        context,

        'Cart item ID is missing.',

      );

      return;

    }

    SnackbarHelper.showLoading(context, 'Removing item...');

    try {

      final result = await CartService().removeCartItem(id);

      if (!mounted) return;

      SnackbarHelper.hide(context);

      if (result['success'] == true) {

        setState(() {

          _cartItems.removeWhere((i) => _key(i) == id);

          _selectedItems.remove(id);

        });

        SnackbarHelper.showSuccess(

          context,

          result['message'] ?? 'Item removed from cart.',

        );

      } else {

        SnackbarHelper.showError(

          context,

          result['message'] ?? 'Failed to remove item.',

        );

      }

    } catch (e) {

      if (!mounted) return;

      SnackbarHelper.hide(context);

      SnackbarHelper.showError(

        context,

        'Error removing item: $e',

      );

    }

  }

  Future<void> _clearCart() async {

    if (_cartItems.isEmpty) return;

    final confirmed = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Clear Cart'),

        content: Text(

          'Remove all ${_cartItems.length} item(s)?',

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: const Text('Cancel'),

          ),

          ElevatedButton(

            onPressed: () => Navigator.pop(ctx, true),

            child: const Text('Clear All'),

          ),

        ],

      ),

    );

    if (confirmed != true || !mounted) return;

    SnackbarHelper.showLoading(

      context,

      'Removing all items...',

    );

    try {

      final result = await CartService().clearAllCartItems(

        _cartItems.map(_key).toList(),

      );

      if (!mounted) return;

      SnackbarHelper.hide(context);

      if (result['success'] == true) {

        setState(() {

          _cartItems.clear();

          _selectedItems.clear();

        });

        SnackbarHelper.showSuccess(

          context,

          result['message'] ?? 'All items removed from cart.',

        );

      } else {

        SnackbarHelper.showError(

          context,

          result['message'] ?? 'Failed to clear cart.',

        );

      }

    } catch (e) {

      if (!mounted) return;

      SnackbarHelper.hide(context);

      SnackbarHelper.showError(

        context,

        'Error clearing cart: $e',

      );

    }

  }

  void _changeQty(Map<String, dynamic> item, int delta) {

    final index = _cartItems.indexWhere(

      (i) => _key(i) == _key(item),

    );

    if (index < 0) return;

    final qty = _int(item['quantity']) + delta;

    if (qty <= 0) {

      _removeItem(item);

      return;

    }

    setState(() {

      _cartItems[index]['quantity'] = qty;

      if (!_validQty(_cartItems[index])) {

        _selectedItems.remove(_key(item));

      }

    });

  }

  @override

  void initState() {

    super.initState();

    _loadCartItems();

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.surfaceLight,

      appBar: AppBar(

        title: const Text('Shopping Cart'),

        backgroundColor: Colors.white,

        foregroundColor: Colors.black87,

        elevation: 0,

        actions: [

          TextButton(

            onPressed: _cartItems.isEmpty ? null : _clearCart,

            child: const Text('Clear All'),

          ),

        ],

      ),

      body: _isLoading

          ? const Center(

              child: CircularProgressIndicator(),

            )

          : _errorMessage != null

              ? Center(

                  child: Padding(

                    padding: const EdgeInsets.all(24),

                    child: Column(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        Text(

                          _errorMessage!,

                          textAlign: TextAlign.center,

                        ),

                        const SizedBox(height: 12),

                        ElevatedButton(

                          onPressed: _loadCartItems,

                          child: const Text('Retry'),

                        ),

                      ],

                    ),

                  ),

                )

              : _cartItems.isEmpty

                  ? Center(

                      child: Column(

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cart items header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_cartItems.length} ${_cartItems.length == 1 ? 'item' : 'items'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    TextButton(
                      onPressed: _cartItems.isEmpty
                          ? null
                          : () {
                              _clearAllItems();
                            },
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Grouped cart items by shop
                ...groupedItems.entries.map((entry) {
                  final shopId = entry.key;
                  final shopItems = entry.value;
                  return _buildShopGroup(shopId, shopItems);
                }),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShopGroup(String shopId, List<Map<String, dynamic>> shopItems) {
    final shopName = _getShopName(shopId);
    final shopSubtotal = _getShopSubtotal(shopId);
    final shopSelectedCount = _getShopSelectedItemsCount(shopId);
    final shopSelectedItems = _getShopSelectedItems(shopId);

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.store,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shopName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
                Text(
                  '${shopItems.length} ${shopItems.length == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Shop items
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                ...shopItems.asMap().entries.map((entry) {
                  int globalIndex = _cartItems
                      .indexWhere((item) => item['id'] == entry.value['id']);
                  return _buildCartItem(entry.value, globalIndex);
                }),
              ],
            ),
          ),

          // Shop checkout section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                // Shop summary
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      if (shopSelectedCount > 0)
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Calculated for $shopSelectedCount selected item${shopSelectedCount == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: AppColors.warning,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Select items to see total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.warning,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '₱${shopSubtotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandPrimaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),

                // Shop checkout button
                ElevatedButton(
                  onPressed: shopSelectedCount > 0
                      ? () {
                          if (shopSelectedItems.isEmpty) {
                            SnackbarHelper.showError(
                              context,
                              'Please select valid items to checkout',
                            );
                            return;
                          }

                          // Navigate to checkout screen with shop-specific items
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckOutScreen(
                                selectedCartItems: shopSelectedItems,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: shopSelectedCount > 0
                        ? AppColors.brandPrimary
                        : Colors.grey[400],
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_checkout,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        shopSelectedCount > 0
                            ? 'Checkout from ${shopName} (${shopSelectedCount} item${shopSelectedCount == 1 ? '' : 's'})'
                            : 'Select items to checkout',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    final isGamefowl = _isGamefowlCartItem(item);
    final isValidQuantity = _categoriesReady && _isQuantityValid(item) && !isGamefowl;
    final itemId = item['id'].toString();
    final isSelected = _selectedItems.contains(itemId);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValidQuantity ? Colors.grey[300]! : AppColors.error.withOpacity(0.4),
          width: isValidQuantity ? 1 : 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isValidQuantity ? isSelected : false,
              onChanged: isValidQuantity
                  ? (bool? value) {
                      _toggleItemSelection(itemId);
                    }
                  : null,
              activeColor: AppColors.brandPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          SizedBox(width: 4),
          // Product image placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.brandPrimary.withOpacity(0.2),
              ),
            ),
            child: Icon(
              Icons.shopping_bag,
              color: AppColors.brandPrimary,
              size: 32,
            ),
          ),
          SizedBox(width: 16),

          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['item_name'] ?? 'Unknown Item',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                CartItemPriceDisplay(
                  pricing: CartItemPricing.fromCartMap(item),
                  primaryFontSize: 18,
                  strikethroughFontSize: 14,
                ),
                if (!_categoriesReady)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Item category unavailable. Refresh the cart to retry.'),
                  )
                else if (isGamefowl)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Gamefowl is view only. Remove this item to clear it from your cart.'),
                  ),
                if (!_isQuantityValid(item))
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Quantity exceeds available stock (${item['item_quantity']} available)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                SizedBox(height: 12),

                // Quantity controls
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          IconButton(
                            icon: Icon(Icons.remove, size: 18),
                            padding: EdgeInsets.all(4),
                            constraints: BoxConstraints(),
                            onPressed: !_categoriesReady || isGamefowl || _shouldDisableRemove(item)
                                ? null
                                : () {
                                    _updateQuantity(
                                        index, (item['quantity'] as int) - 1);
                                  },
                            color: _shouldDisableRemove(item)
                                ? Colors.grey[400]
                                : Colors.grey[700],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${item['quantity']}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, size: 18),
                            padding: EdgeInsets.all(4),
                            constraints: BoxConstraints(),
                            onPressed: !_categoriesReady || isGamefowl || _shouldDisableAdd(item)
                                ? null
                                : () {
                                    _updateQuantity(
                                        index, (item['quantity'] as int) + 1);
                                  },
                            color: _shouldDisableAdd(item)
                                ? Colors.grey[400]
                                : AppColors.brandPrimary,
                          ),

                        ],

                      ),

                    )

                  : ListView(

                      padding: const EdgeInsets.all(16),

                      children: [

                        Text(

                          '${_cartItems.length} '

                          '${_cartItems.length == 1 ? 'item' : 'items'}',

                        ),

                        const SizedBox(height: 12),

                        ..._groupItems().entries.map((entry) {

                          final shopId = entry.key;

                          final items = entry.value;

                          final name = _shopName(shopId, items);

                          final selected = _selectedForShop(items);

                          final subtotal = _subtotal(items);

                          return Card(

                            margin: const EdgeInsets.only(bottom: 18),

                            clipBehavior: Clip.antiAlias,

                            child: Column(

                              crossAxisAlignment:

                                  CrossAxisAlignment.stretch,

                              children: [

                                Container(

                                  color: AppColors.brandPrimary

                                      .withOpacity(.1),

                                  padding: const EdgeInsets.all(14),

                                  child: Row(

                                    children: [

                                      const Icon(Icons.store),

                                      const SizedBox(width: 8),

                                      Expanded(

                                        child: Text(

                                          name,

                                          style: const TextStyle(

                                            fontWeight: FontWeight.bold,

                                          ),

                                        ),

                                      ),

                                      Text('${items.length} item(s)'),

                                    ],

                                  ),

                                ),

                                ...items.map((item) {

                                  final id = _key(item);

                                  final valid = _validQty(item);

                                  final qty = _int(item['quantity']);

                                  final stock =

                                      _int(item['item_quantity']);

                                  return Padding(

                                    padding: const EdgeInsets.all(12),

                                    child: Row(

                                      crossAxisAlignment:

                                          CrossAxisAlignment.start,

                                      children: [

                                        Checkbox(

                                          value: valid &&

                                              _selectedItems.contains(id),

                                          onChanged: valid

                                              ? (_) => _toggle(id)

                                              : null,

                                        ),

                                        Container(

                                          width: 56,

                                          height: 56,

                                          decoration: BoxDecoration(

                                            color: AppColors.brandPrimary

                                                .withOpacity(.1),

                                            borderRadius:

                                                BorderRadius.circular(8),

                                          ),

                                          child: Icon(

                                            Icons.shopping_bag_outlined,

                                            color: AppColors.brandPrimary,

                                          ),

                                        ),

                                        const SizedBox(width: 10),

                                        Expanded(

                                          child: Column(

                                            crossAxisAlignment:

                                                CrossAxisAlignment.start,

                                            children: [

                                              Text(

                                                item['item_name']

                                                        ?.toString() ??

                                                    'Unknown Item',

                                                style: const TextStyle(

                                                  fontWeight:

                                                      FontWeight.w600,

                                                ),

                                              ),

                                              const SizedBox(height: 5),

                                              CartItemPriceDisplay(

                                                pricing:

                                                    CartItemPricing

                                                        .fromCartMap(item),

                                                primaryFontSize: 17,

                                                strikethroughFontSize: 13,

                                              ),

                                              if (!valid)

                                                Text(

                                                  'Invalid quantity '

                                                  '($stock available)',

                                                  style: TextStyle(

                                                    color: AppColors.error,

                                                    fontSize: 12,

                                                  ),

                                                ),

                                              Row(

                                                children: [

                                                  IconButton(

                                                    onPressed: qty <= 1 ||

                                                            _outOfStock(item)

                                                        ? null

                                                        : () => _changeQty(

                                                              item,

                                                              -1,

                                                            ),

                                                    icon: const Icon(

                                                      Icons.remove,

                                                      size: 18,

                                                    ),

                                                  ),

                                                  Text('$qty'),

                                                  IconButton(

                                                    onPressed: qty >= stock ||

                                                            _outOfStock(item)

                                                        ? null

                                                        : () => _changeQty(

                                                              item,

                                                              1,

                                                            ),

                                                    icon: const Icon(

                                                      Icons.add,

                                                      size: 18,

                                                    ),

                                                  ),

                                                  const Spacer(),

                                                  IconButton(

                                                    onPressed: () =>

                                                        _removeItem(item),

                                                    icon: Icon(

                                                      Icons.delete_outline,

                                                      color: AppColors.error,

                                                    ),

                                                  ),

                                                ],

                                              ),

                                            ],

                                          ),

                                        ),

                                      ],

                                    ),

                                  );

                                }),

                                Padding(

                                  padding: const EdgeInsets.fromLTRB(

                                    14,

                                    4,

                                    14,

                                    14,

                                  ),

                                  child: Column(

                                    children: [

                                      Row(

                                        mainAxisAlignment:

                                            MainAxisAlignment.spaceBetween,

                                        children: [

                                          const Text('Selected subtotal'),

                                          Text(

                                            '₱${subtotal.toStringAsFixed(2)}',

                                            style: const TextStyle(

                                              fontWeight: FontWeight.bold,

                                            ),

                                          ),

                                        ],

                                      ),

                                      const SizedBox(height: 10),

                                      SizedBox(

                                        width: double.infinity,

                                        child: ElevatedButton(

                                          onPressed: selected.isEmpty

                                              ? null

                                              : () => _openCheckout(

                                                    selected,

                                                  ),

                                          style: ElevatedButton.styleFrom(

                                            backgroundColor:

                                                AppColors.brandPrimary,

                                            foregroundColor: Colors.white,

                                          ),

                                          child: Text(

                                            selected.isEmpty

                                                ? 'Select items to checkout'

                                                : 'Checkout from $name '

                                                    '(${selected.length})',

                                          ),

                                        ),

                                      ),

                                    ],

                                  ),

                                ),

                              ],

                            ),

                          );

                        }),

                      ],

                    ),

    );

  }

}
