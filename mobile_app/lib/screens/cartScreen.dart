import 'package:flutter/material.dart';
import '../constants/constants.dart';
import '../services/cart_services.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'customerDashboardScreen.dart';
import 'favoriteScreen.dart';
import 'profileScreen.dart';
import 'checkOutScreen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int _selectedIndex = 1; // Cart tab
  // Sample cart items - in real app, this would come from state management
  // List<Map<String, dynamic>> _cartItems = [
  //   {
  //     'id': '1',
  //     'name': 'Organic Fertilizer',
  //     'price': 24.99,
  //     'quantity': 2,
  //     'image': null,
  //   },
  //   {
  //     'id': '2',
  //     'name': 'Garden Spade',
  //     'price': 18.50,
  //     'quantity': 1,
  //     'image': null,
  //   },
  //   {
  //     'id': '3',
  //     'name': 'Watering Can',
  //     'price': 15.99,
  //     'quantity': 3,
  //     'image': null,
  //   },
  // ];

  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  Set<String> _selectedItems = {}; // Track selected items by their ID

  // Group items by shop_id
  Map<String, List<Map<String, dynamic>>> _groupItemsByShop() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in _cartItems) {
      final shopId = item['shop_id']?.toString() ?? 'unknown';
      if (!grouped.containsKey(shopId)) {
        grouped[shopId] = [];
      }
      grouped[shopId]!.add(item);
    }
    return grouped;
  }

  // Get shop name (if available) or use shop_id
  String _getShopName(String shopId) {
    // Try to find shop name from items, or use shop_id
    final shopItems = _cartItems
        .where((item) => item['shop_id']?.toString() == shopId)
        .toList();
    if (shopItems.isNotEmpty && shopItems.first['shop_name'] != null) {
      return shopItems.first['shop_name'].toString();
    }
    return 'Shop $shopId';
  }

  // Get effective price - use item_price if different from price_snapshot
  double _getEffectivePrice(Map<String, dynamic> item) {
    final priceSnapshot = double.parse(item['price_snapshot'].toString());
    final itemPrice = double.parse(item['item_price'].toString());
    return priceSnapshot != itemPrice ? itemPrice : priceSnapshot;
  }

  // Check if item quantity exceeds available stock
  bool _isQuantityValid(Map<String, dynamic> item) {
    final quantity = item['quantity'] as int;
    final itemQuantity = int.parse(item['item_quantity'].toString());
    return quantity <= itemQuantity;
  }

  // Check if item is out of stock
  bool _isOutOfStock(Map<String, dynamic> item) {
    final itemQuantity = int.parse(item['item_quantity'].toString());
    return itemQuantity <= 0;
  }

  // Check if remove button should be disabled
  bool _shouldDisableRemove(Map<String, dynamic> item) {
    final quantity = item['quantity'] as int;
    return quantity <= 1 || _isOutOfStock(item);
  }

  // Check if add button should be disabled
  bool _shouldDisableAdd(Map<String, dynamic> item) {
    final quantity = item['quantity'] as int;
    final itemQuantity = int.parse(item['item_quantity'].toString());
    return quantity >= itemQuantity || _isOutOfStock(item);
  }

  // Get subtotal for a specific shop
  double _getShopSubtotal(String shopId) {
    final shopItems = _cartItems
        .where((item) => item['shop_id']?.toString() == shopId)
        .toList();
    return shopItems.fold(0.0, (sum, item) {
      final itemId = item['id'].toString();
      if (!_selectedItems.contains(itemId) || !_isQuantityValid(item)) {
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
      return _selectedItems.contains(itemId) && _isQuantityValid(item);
    }).length;
  }

  // Get selected items for a specific shop
  List<Map<String, dynamic>> _getShopSelectedItems(String shopId) {
    final shopItems = _cartItems
        .where((item) => item['shop_id']?.toString() == shopId)
        .toList();
    return shopItems.where((item) {
      final itemId = item['id'].toString();
      return _selectedItems.contains(itemId) && _isQuantityValid(item);
    }).toList();
  }

  double get _subtotal {
    return _cartItems.fold(0.0, (sum, item) {
      final itemId = item['id'].toString();
      // Only include checked items with valid quantity (quantity <= item_quantity)
      if (!_selectedItems.contains(itemId) || !_isQuantityValid(item)) {
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
              backgroundColor: Colors.red[700],
            ),
            child: Text('Clear All'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    // Get all cart item IDs
    final cartItemIds =
        _cartItems.map((item) => item['id'].toString()).toList();

    // Show loading indicator
    SnackbarHelper.showLoading(context, 'Removing all items...');

    try {
      final result = await CartService().clearAllCartItems(cartItemIds);

      SnackbarHelper.hide(context);

      if (result['success'] == true) {
        // Clear local state only if API call succeeds
        setState(() {
          _cartItems.clear();
          _selectedItems.clear(); // Clear selection when clearing cart
        });

        SnackbarHelper.showSuccess(
          context,
          result['message'] ?? 'All items removed from cart',
          duration: Duration(seconds: 2),
        );
      } else {
        SnackbarHelper.showError(
          context,
          result['message'] ?? 'Failed to clear cart',
        );
      }
    } catch (e) {
      SnackbarHelper.hide(context);
      SnackbarHelper.showError(
        context,
        'Error clearing cart: ${e.toString()}',
      );
    }
  }

  Future<void> _removeItem(int index) async {
    if (index < 0 || index >= _cartItems.length) return;

    final item = _cartItems[index];
    final cartItemId = item['id'].toString();

    // Show loading indicator
    SnackbarHelper.showLoading(context, 'Removing item...');

    try {
      final result = await CartService().removeCartItem(cartItemId);

      SnackbarHelper.hide(context);

      if (result['success'] == true) {
        // Remove from local state only if API call succeeds
        final removedItemId = item['id'].toString();
        setState(() {
          _cartItems.removeAt(index);
          _selectedItems.remove(
              removedItemId); // Remove from selection if it was selected
        });

        SnackbarHelper.showSuccess(
          context,
          result['message'] ?? 'Item removed from cart',
          duration: Duration(seconds: 2),
        );
      } else {
        SnackbarHelper.showError(
          context,
          result['message'] ?? 'Failed to remove item',
        );
      }
    } catch (e) {
      SnackbarHelper.hide(context);
      SnackbarHelper.showError(
        context,
        'Error removing item: ${e.toString()}',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not logged in';
        });
        return;
      }

      final cartItems = await CartService().fetchCartItemsFromAPI(userId);
      setState(() {
        _cartItems = cartItems;

        // Remove any invalid items from selection
        final itemsToRemove = <String>[];
        for (var item in cartItems) {
          final itemId = item['id'].toString();
          if (!_isQuantityValid(item) && _selectedItems.contains(itemId)) {
            itemsToRemove.add(itemId);
          }
        }
        _selectedItems.removeAll(itemsToRemove);

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load cart items: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Shopping Cart',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[700]),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _cartItems.isEmpty
                  ? _buildEmptyCart()
                  : _buildCartContent(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PageRoute _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale:
                Tween<double>(begin: 0.98, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      transitionDuration: Duration(milliseconds: 150),
      reverseTransitionDuration: Duration(milliseconds: 150),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.mediumGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: AppColors.mediumGreen,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add some items to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              // Navigate to customer dashboard instead of popping
              // This prevents errors when there's no previous route
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomerDashboardScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mediumGreen,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Continue Shopping',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent() {
    final groupedItems = _groupItemsByShop();

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
                          color: Colors.red[700],
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
              color: AppColors.mediumGreen.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.store,
                  color: AppColors.mediumGreen,
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
              color: Colors.grey[50],
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
                                color: Colors.orange[700],
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Select items to see total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
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
                              color: AppColors.mediumGreen,
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
                        ? AppColors.mediumGreen
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
    final isValidQuantity = _isQuantityValid(item);
    final itemId = item['id'].toString();
    final isSelected = _selectedItems.contains(itemId);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValidQuantity ? Colors.grey[300]! : Colors.red[300]!,
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
              activeColor: AppColors.mediumGreen,
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
              color: AppColors.mediumGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.mediumGreen.withOpacity(0.2),
              ),
            ),
            child: Icon(
              Icons.shopping_bag,
              color: AppColors.mediumGreen,
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
                if (double.parse(item['price_snapshot'].toString()) !=
                    double.parse(item['item_price'].toString()))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price at add to cart: ₱${double.parse(item['price_snapshot'].toString()).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Current price: ₱${double.parse(item['item_price'].toString()).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mediumGreen,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '₱${_getEffectivePrice(item).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mediumGreen,
                    ),
                  ),
                if (!_isQuantityValid(item))
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Quantity exceeds available stock (${item['item_quantity']} available)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
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
                            onPressed: _shouldDisableRemove(item)
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
                            onPressed: _shouldDisableAdd(item)
                                ? null
                                : () {
                                    _updateQuantity(
                                        index, (item['quantity'] as int) + 1);
                                  },
                            color: _shouldDisableAdd(item)
                                ? Colors.grey[400]
                                : AppColors.mediumGreen,
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                    Flexible(
                      child: Text(
                        _isQuantityValid(item)
                            ? '₱${(_getEffectivePrice(item) * (item['quantity'] as int)).toStringAsFixed(2)}'
                            : '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isQuantityValid(item)
                              ? Colors.grey[900]
                              : Colors.red[400],
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8),

          // Remove button
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[400]),
            onPressed: () {
              _removeItem(index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          // Handle navigation based on selected index
          if (index == 0) {
            // Home
            Navigator.pushReplacement(
              context,
              _createFadeRoute(CustomerDashboardScreen()),
            );
          } else if (index == 2) {
            // Favorites
            Navigator.pushReplacement(
              context,
              _createFadeRoute(FavoriteScreen()),
            );
          } else if (index == 3) {
            // Profile
            Navigator.pushReplacement(
              context,
              _createFadeRoute(ProfileScreen()),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.mediumGreen,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: Colors.grey[isTotal ? 900 : 700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? AppColors.mediumGreen : Colors.grey[900],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.mediumGreen),
          ),
          SizedBox(height: 16),
          Text(
            'Loading cart items...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[900],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _loadCartItems();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mediumGreen,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
