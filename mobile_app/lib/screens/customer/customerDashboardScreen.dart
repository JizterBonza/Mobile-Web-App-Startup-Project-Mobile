import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../services/api_service.dart';
import '../../provider/provider.dart';
import 'cartScreen.dart';
import '../common/profileScreen.dart';
import '../common/myOrderScreen.dart';
import 'favoriteScreen.dart';
import 'productDetailScreen.dart';
import 'shopScreen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;
  String? _categoryError;
  List<Map<String, dynamic>> _featuredProducts = [];
  bool _isLoadingProducts = true;
  List<Map<String, dynamic>> _recentOrders = [];
  bool _isLoadingOrders = true;
  String? _orderError;
  String? _userName;

  // Suggested Stores
  List<Map<String, dynamic>> _suggestedStores = [];
  bool _isLoadingStores = true;
  String? _storeError;

  // Selected Category
  String? _selectedCategoryName;

  // For SearchBar
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounceTimer;
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    // Defer loading until after the build phase completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
      _loadFeaturedProducts();
      _loadSuggestedStores();
      _loadRecentOrders();
      _loadUserName();
    });

    // Listen to text changes with debounce
    _searchController.addListener(_onSearchChanged);

    // Hide overlay when focus is lost
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        // Delay to allow tap on results
        Future.delayed(Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _showOverlay = false);
          }
        });
      }
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text;

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Clear results if query is empty or too short
    if (query.trim().isEmpty || query.trim().length < 2) {
      final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
      itemsProvider.clearSearch();
      setState(() => _showOverlay = false);
      return;
    }

    // Debounce search requests
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
    await itemsProvider.searchItems(query);

    if (mounted) {
      setState(() {
        _showOverlay = itemsProvider.searchResults.isNotEmpty;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
    itemsProvider.clearSearch();
    setState(() => _showOverlay = false);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCategories({bool useCache = true}) async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    if (!mounted) return;
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });

    await categoryProvider.fetchCategories(useCache: useCache);

    if (!mounted) return;
    setState(() {
      _categories = categoryProvider.categories;
      _isLoadingCategories = categoryProvider.isLoading;
      _categoryError = categoryProvider.error;
      if (categoryProvider.fromCache && _categories.isNotEmpty) {
        _categoryError = 'Using cached data (connection lost)';
      }

      // Fallback to default categories if both API and cache failed
      if (_categories.isEmpty && _categoryError != null) {
        _categories = [
          {'name': 'Seeds', 'icon': Icons.eco},
          {'name': 'Fertilizers', 'icon': Icons.science},
          {'name': 'Tools', 'icon': Icons.build},
          {'name': 'Equipment', 'icon': Icons.agriculture},
        ];
      }
    });
  }

  Future<void> _loadUserName() async {
    try {
      _userName = await ApiService.getUserName();
    } catch (e) {
      print('Error loading user name: $e');
    }
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

  Future<void> _loadFeaturedProducts({bool useCache = true}) async {
    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);

    if (!mounted) return;
    setState(() {
      _isLoadingProducts = true;
    });

    await itemsProvider.fetchItems(useCache: useCache);

    if (!mounted) return;
    // Take first 4 items as featured products
    setState(() {
      _featuredProducts = itemsProvider.items.take(4).toList();
      _isLoadingProducts = itemsProvider.isLoading;
    });
  }

  Future<void> _loadSuggestedStores({bool useCache = true}) async {
    final shopsProvider = Provider.of<ShopsProvider>(context, listen: false);

    if (!mounted) return;
    setState(() {
      _isLoadingStores = true;
      _storeError = null;
    });

    await shopsProvider.fetchShops(useCache: useCache, limit: 6);

    if (!mounted) return;
    setState(() {
      _suggestedStores = shopsProvider.shops;
      _isLoadingStores = shopsProvider.isLoading;
      _storeError = shopsProvider.error;
      if (shopsProvider.fromCache && _suggestedStores.isNotEmpty) {
        _storeError = 'Using cached data (connection lost)';
      }
    });
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '₱0.00';

    try {
      if (price is num) {
        return '₱${price.toStringAsFixed(2)}';
      } else if (price is String) {
        final parsed = double.tryParse(price);
        return parsed != null ? '₱${parsed.toStringAsFixed(2)}' : '₱0.00';
      }
    } catch (e) {
      print('Error formatting price: $e');
    }

    return '₱0.00';
  }

  String _formatRating(dynamic rating) {
    if (rating == null) return 'N/A';

    try {
      if (rating is num) {
        return rating.toStringAsFixed(1);
      } else if (rating is String) {
        final parsed = double.tryParse(rating);
        return parsed != null ? parsed.toStringAsFixed(1) : 'N/A';
      }
    } catch (e) {
      print('Error formatting rating: $e');
    }

    return 'N/A';
  }

  Future<void> _loadRecentOrders({bool useCache = true}) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);

    if (!mounted) return;
    setState(() {
      _isLoadingOrders = true;
      _orderError = null;
    });

    await ordersProvider.fetchOrders(useCache: useCache);

    if (!mounted) return;
    // Take only the most recent 3 orders
    final recentOrders = ordersProvider.orders.take(3).toList();

    setState(() {
      _recentOrders = recentOrders;
      _isLoadingOrders = ordersProvider.isLoading;
      _orderError = ordersProvider.error;
      if (ordersProvider.fromCache && _recentOrders.isNotEmpty) {
        _orderError = 'Using cached data (connection lost)';
      }
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadCategories(),
      _loadFeaturedProducts(),
      _loadSuggestedStores(),
      _loadRecentOrders(),
    ]);
    // Add a small delay to show the refresh indicator
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.mediumGreen,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with greeting and profile
                    _buildHeader(),
                    SizedBox(height: 24),

                    // Search bar
                    _buildSearchBar(),
                    SizedBox(height: 24),

                    // Categories section
                    _buildCategoriesSection(),
                    SizedBox(height: 24),

                    // Featured products
                    _buildFeaturedProducts(),
                    SizedBox(height: 24),

                    // Category items (shown when a category is selected)
                    _buildCategoryItems(),

                    // Suggested stores
                    _buildSuggestedStores(),
                    SizedBox(height: 24),

                    // Recent orders
                    _buildRecentOrders(),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildSearchOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good Morning!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            Text(
              'Welcome to Agrify, $_userName!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              _createFadeRoute(ProfileScreen()),
            );
          },
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.mediumGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.mediumGreen.withOpacity(0.3)),
            ),
            child: Icon(
              Icons.person,
              color: AppColors.mediumGreen,
              size: 28,
            ),
          ),
        )
      ],
    );
  }

  // Widget _buildSearchBar() {
  //   return Container(
  //     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(color: Colors.grey[300]!),
  //     ),
  //     child: TextField(
  //       decoration: InputDecoration(
  //         hintText: 'Search for products...',
  //         border: InputBorder.none,
  //         prefixIcon: Icon(Icons.search, color: AppColors.mediumGreen),
  //         suffixIcon: Icon(Icons.filter_list, color: Colors.grey[600]),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildSearchBar() {
    return Consumer<ItemsProvider>(
      builder: (context, itemsProvider, child) {
        final isSearching = itemsProvider.isSearching;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: 'Search for products...',
              border: InputBorder.none,
              prefixIcon: isSearching
                  ? Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.mediumGreen,
                        ),
                      ),
                    )
                  : Icon(Icons.search, color: AppColors.mediumGreen),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: _clearSearch,
                    )
                  : Icon(Icons.filter_list, color: Colors.grey[600]),
            ),
            onTap: () {
              if (itemsProvider.searchResults.isNotEmpty &&
                  _searchController.text.length >= 2) {
                setState(() => _showOverlay = true);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchOverlay() {
    return Consumer<ItemsProvider>(
      builder: (context, itemsProvider, child) {
        final searchResults = itemsProvider.searchResults;

        if (!_showOverlay || searchResults.isEmpty) {
          return SizedBox.shrink();
        }

        return Positioned(
          top: 140,
          left: 16,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(vertical: 8),
                itemCount: searchResults.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = searchResults[index];

                  // Handle item_images array
                  final itemImages = product['item_images'];
                  final hasImage = itemImages != null &&
                      itemImages is List &&
                      (itemImages as List).isNotEmpty;
                  final imageUrl =
                      hasImage ? (itemImages as List).first.toString() : null;

                  return ListTile(
                    leading: hasImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[200],
                                  child: Icon(Icons.shopping_bag,
                                      color: Colors.grey),
                                );
                              },
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.shopping_bag, color: Colors.grey),
                          ),
                    title: Text(
                      product['item_name'] ?? 'Unknown Product',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatPrice(product['item_price']),
                      style: TextStyle(
                        color: AppColors.mediumGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      // Navigate to product detail
                      _clearSearch();
                      _searchFocus.unfocus();

                      Navigator.push(
                        context,
                        _createFadeRoute(
                          ProductDetailScreen(productId: product['id']),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Categories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            if (_categoryError != null)
              IconButton(
                icon:
                    Icon(Icons.refresh, size: 20, color: AppColors.mediumGreen),
                onPressed: _loadCategories,
                tooltip: 'Retry',
              ),
          ],
        ),
        SizedBox(height: 16),
        if (_isLoadingCategories)
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.mediumGreen,
                  ),
                ),
              );
            },
          )
        else if (_categories.isEmpty)
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No categories available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final itemsProvider = Provider.of<ItemsProvider>(context);
              final isSelected =
                  itemsProvider.selectedCategoryId == category['id'];

              return Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.mediumGreen.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.mediumGreen : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // Handle category tap - fetch items for this category
                      final categoryId = category['id'];
                      final categoryName = category['name'] ?? 'Category';

                      if (itemsProvider.selectedCategoryId == categoryId) {
                        // Deselect if same category is tapped
                        itemsProvider.clearCategorySelection();
                        setState(() {
                          _selectedCategoryName = null;
                        });
                      } else {
                        // Select and fetch items for this category
                        setState(() {
                          _selectedCategoryName = categoryName;
                        });
                        itemsProvider.fetchItemsByCategory(categoryId);
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            category['icon'] ?? Icons.broken_image,
                            size: 32,
                            color: AppColors.mediumGreen,
                          ),
                          SizedBox(height: 8),
                          Text(
                            category['name'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.mediumGreen
                                  : Colors.grey[800],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFeaturedProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Featured Products',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            // TextButton(
            //   onPressed: () {
            //     // Handle view all
            //   },
            //   child: Text(
            //     'View All',
            //     style: TextStyle(
            //       color: AppColors.mediumGreen,
            //       fontWeight: FontWeight.w600,
            //     ),
            //   ),
            // ),
          ],
        ),
        SizedBox(height: 16),
        if (_isLoadingProducts)
          SizedBox(
            height: 160,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.mediumGreen,
              ),
            ),
          )
        else if (_featuredProducts.isEmpty)
          Container(
            height: 160,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No products available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _featuredProducts.length,
              itemBuilder: (context, index) {
                final product = _featuredProducts[index];
                final itemImages = product['item_images'];
                final hasImage = itemImages != null &&
                    itemImages is List &&
                    (itemImages as List).isNotEmpty;

                return Container(
                  width: 140,
                  margin: EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // Navigate to product detail screen
                        Navigator.push(
                          context,
                          _createFadeRoute(
                              ProductDetailScreen(productId: product['id'])),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 60,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.mediumGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color:
                                        AppColors.mediumGreen.withOpacity(0.2)),
                              ),
                              child: hasImage
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        (itemImages as List).first.toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Icon(
                                            Icons.shopping_bag,
                                            color: AppColors.mediumGreen,
                                            size: 24,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      Icons.shopping_bag,
                                      color: AppColors.mediumGreen,
                                      size: 24,
                                    ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              product['item_name'] ?? 'Unknown Product',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.amber[600],
                                ),
                                SizedBox(width: 2),
                                Text(
                                  _formatRating(product['average_rating']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            Spacer(),
                            Text(
                              _formatPrice(product['item_price']),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.mediumGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryItems() {
    return Consumer<ItemsProvider>(
      builder: (context, itemsProvider, child) {
        // Only show if a category is selected
        if (itemsProvider.selectedCategoryId == null) {
          return SizedBox.shrink();
        }

        final categoryItems = itemsProvider.categoryItems;
        final isLoading = itemsProvider.isCategoryLoading;
        final error = itemsProvider.categoryError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedCategoryName != null
                        ? '$_selectedCategoryName Products'
                        : 'Category Products',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
                  onPressed: () {
                    itemsProvider.clearCategorySelection();
                    setState(() {
                      _selectedCategoryName = null;
                    });
                  },
                  tooltip: 'Clear selection',
                ),
              ],
            ),
            SizedBox(height: 16),
            if (isLoading)
              Container(
                height: 200,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.mediumGreen,
                  ),
                ),
              )
            else if (error != null)
              Container(
                height: 200,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[400],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load products',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          if (itemsProvider.selectedCategoryId != null) {
                            itemsProvider.fetchItemsByCategory(
                                itemsProvider.selectedCategoryId!);
                          }
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (categoryItems.isEmpty)
              Container(
                height: 200,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No products in this category',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: categoryItems.length,
                itemBuilder: (context, index) {
                  final product = categoryItems[index];
                  final itemImages = product['item_images'];
                  final hasImage = itemImages != null &&
                      itemImages is List &&
                      (itemImages as List).isNotEmpty;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            _createFadeRoute(
                              ProductDetailScreen(productId: product['id']),
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product image
                              Expanded(
                                flex: 3,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.mediumGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.mediumGreen
                                          .withOpacity(0.2),
                                    ),
                                  ),
                                  child: hasImage
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            (itemImages as List)
                                                .first
                                                .toString(),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Center(
                                                child: Icon(
                                                  Icons.shopping_bag,
                                                  color: AppColors.mediumGreen,
                                                  size: 32,
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : Center(
                                          child: Icon(
                                            Icons.shopping_bag,
                                            color: AppColors.mediumGreen,
                                            size: 32,
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(height: 8),
                              // Product name
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['item_name'] ?? 'Unknown Product',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4),
                                    // Rating
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 12,
                                          color: Colors.amber[600],
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          _formatRating(
                                              product['average_rating']),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Spacer(),
                                    // Price
                                    Text(
                                      _formatPrice(product['item_price']),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.mediumGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildSuggestedStores() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Suggested Stores',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            if (_storeError != null)
              IconButton(
                icon:
                    Icon(Icons.refresh, size: 20, color: AppColors.mediumGreen),
                onPressed: () => _loadSuggestedStores(useCache: false),
                tooltip: 'Retry',
              )
            // else
            //   TextButton(
            //     onPressed: () {
            //       // Handle view all stores
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         SnackBar(
            //           content: Text('View all stores coming soon!'),
            //           backgroundColor: AppColors.mediumGreen,
            //           duration: Duration(seconds: 1),
            //         ),
            //       );
            //     },
            //     child: Text(
            //       'View All',
            //       style: TextStyle(
            //         color: AppColors.mediumGreen,
            //         fontWeight: FontWeight.w600,
            //       ),
            //     ),
            //   ),
          ],
        ),
        SizedBox(height: 16),
        if (_isLoadingStores)
          SizedBox(
            height: 140,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.mediumGreen,
              ),
            ),
          )
        else if (_suggestedStores.isEmpty)
          Container(
            height: 140,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8),
                  Text(
                    _storeError != null
                        ? 'Failed to load stores'
                        : 'No stores available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedStores.length,
              itemBuilder: (context, index) {
                final store = _suggestedStores[index];
                final shopLogo = store['shop_logo'];
                final hasLogo =
                    shopLogo != null && shopLogo.toString().isNotEmpty;
                final shopRating = store['shop_rating'];
                final totalReviews = store['total_reviews'] ?? 0;

                return Container(
                  width: 160,
                  margin: EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // Navigate to shop screen
                        Navigator.push(
                          context,
                          _createFadeRoute(
                            ShopScreen(
                              shopId: store['id'],
                              shopName: store['shop_name'],
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Store logo
                            Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                color: AppColors.mediumGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: AppColors.mediumGreen.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: hasLogo
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: Image.network(
                                        shopLogo.toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Icon(
                                            Icons.store,
                                            color: AppColors.mediumGreen,
                                            size: 28,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      Icons.store,
                                      color: AppColors.mediumGreen,
                                      size: 28,
                                    ),
                            ),
                            SizedBox(height: 8),
                            // Store name
                            Text(
                              store['shop_name'] ?? 'Unknown Store',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4),
                            // Rating and reviews count
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.amber[600],
                                ),
                                SizedBox(width: 2),
                                Text(
                                  _formatRating(shopRating),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.rate_review_outlined,
                                  size: 12,
                                  color: Colors.grey[500],
                                ),
                                SizedBox(width: 2),
                                Text(
                                  '$totalReviews',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            Spacer(),
                            // Visit store button
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.mediumGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Visit Store',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mediumGreen,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecentOrders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Orders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            if (_orderError != null)
              IconButton(
                icon:
                    Icon(Icons.refresh, size: 20, color: AppColors.mediumGreen),
                onPressed: () => _loadRecentOrders(useCache: false),
                tooltip: 'Retry',
              )
            else
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    _createFadeRoute(MyOrderScreen()),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.mediumGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        if (_isLoadingOrders)
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.mediumGreen,
              ),
            ),
          )
        else if (_recentOrders.isEmpty)
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8),
                  Text(
                    _orderError != null
                        ? 'Failed to load orders'
                        : 'No recent orders',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: _recentOrders.asMap().entries.map((entry) {
                final index = entry.key;
                final order = entry.value;
                final orderCode = order['order_code']?.toString() ?? 'N/A';
                final orderStatus =
                    order['order_status']?.toString() ?? 'Pending';
                final totalAmount = order['total_amount']?.toString() ?? '0.00';
                final orderedAt = order['ordered_at']?.toString() ?? '';

                return Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey[200]!,
                        width: index < _recentOrders.length - 1 ? 1 : 0,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order $orderCode',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              _formatOrderDate(orderedAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  _getStatusColor(orderStatus).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              orderStatus,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(orderStatus),
                              ),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatPrice(totalAmount),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.mediumGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  String _formatOrderDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';
    try {
      // Parse date string like "2025-11-13 23:00:10"
      final dateTime = DateTime.tryParse(dateString);
      if (dateTime != null) {
        // Format as "MMM dd, yyyy" or "Jan 15, 2024"
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
      }
    } catch (e) {
      print('Error formatting date: $e');
    }
    return dateString;
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
          if (index == 1) {
            // Cart
            Navigator.push(
              context,
              _createFadeRoute(CartScreen()),
            ).then((_) {
              // Reset to home when returning from cart
              if (mounted) {
                setState(() {
                  _selectedIndex = 0;
                });
              }
            });
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return AppColors.mediumGreen;
      case 'in transit':
      case 'in-transit':
        return Colors.orange[600]!;
      case 'pending':
        return Colors.grey[600]!;
      case 'processing':
        return Colors.blue[600]!;
      case 'cancelled':
      case 'canceled':
        return Colors.red[600]!;
      default:
        return Colors.grey[500]!;
    }
  }
}
