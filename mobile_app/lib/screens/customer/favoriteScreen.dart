import 'package:flutter/material.dart';
import '../../constants/constants.dart';
import '../../services/favorite_services.dart';
import '../../services/api_service.dart';
import '../../utils/customer_nav.dart';
import '../../utils/media_url.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'customerDashboardScreen.dart';
import 'productDetailScreen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<Map<String, dynamic>> _favoriteProducts = [];
  bool _isGridView = true;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isGuest = true;
  final FavoriteService _favoriteService = FavoriteService();

  @override
  void initState() {
    super.initState();
    _loadGuestState();
    _loadFavorites();
  }

  Future<void> _loadGuestState() async {
    try {
      final token = await ApiService.getToken();
      if (!mounted) return;
      setState(() {
        _isGuest = token == null || token.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _isGuest = true);
    }
  }

  Future<void> _loadFavorites() async {
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

      final favorites = await _favoriteService.fetchFavoritesFromAPI(userId);
      setState(() {
        _favoriteProducts = favorites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load favorites: ${e.toString()}';
      });
    }
  }

  Future<void> _removeFavorite(int index) async {
    if (index < 0 || index >= _favoriteProducts.length) return;

    final product = _favoriteProducts[index];
    final favoriteId = product['id'].toString();
    final productName = product['name'] ?? product['item_name'] ?? 'Item';

    // Show loading indicator
    SnackbarHelper.showLoading(context, 'Removing from favorites...');

    try {
      final result = await _favoriteService.removeFromFavorites(favoriteId);

      SnackbarHelper.hide(context);

      if (result['success'] == true) {
        // Remove from local state only if API call succeeds
        setState(() {
          _favoriteProducts.removeAt(index);
        });

        SnackbarHelper.showSuccess(
          context,
          result['message'] ?? '$productName removed from favorites',
          duration: Duration(seconds: 2),
        );
      } else {
        SnackbarHelper.showError(
          context,
          result['message'] ?? 'Failed to remove from favorites',
        );
      }
    } catch (e) {
      SnackbarHelper.hide(context);
      SnackbarHelper.showError(
        context,
        'Error removing favorite: ${e.toString()}',
      );
    }
  }

  void _toggleFavorite(int index) {
    _removeFavorite(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(
          'Favorites',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[700]),
        actions: [
          if (_favoriteProducts.isNotEmpty && !_isLoading)
            IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list : Icons.grid_view,
                color: Colors.grey[700],
              ),
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
              tooltip: _isGridView ? 'List View' : 'Grid View',
            ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.grey[700],
            ),
            onPressed: _loadFavorites,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _favoriteProducts.isEmpty
                  ? _buildEmptyState()
                  : _isGridView
                      ? _buildGridView()
                      : _buildListView(),
      bottomNavigationBar: buildCustomerBottomNavigationBar(
        context: context,
        currentIndex: CustomerNavIndex.favorites,
        isGuest: _isGuest,
        onLoginSuccess: () {
          _loadGuestState();
          _loadFavorites();
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return _isGridView
        ? const ProductGridSkeleton(imageHeight: 130, childAspectRatio: 0.62)
        : const ListRowsSkeleton(count: 6);
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withOpacity(0.4),
            ),
            SizedBox(height: 16),
            Text(
              'Error loading favorites',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadFavorites,
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_outline,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No favorites yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start adding items you love',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
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
            icon: Icon(Icons.shopping_bag_outlined, size: 18),
            label: Text('Browse Products'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _favoriteProducts.length,
      itemBuilder: (context, index) {
        final product = _favoriteProducts[index];
        return _buildProductCard(product, index, isGrid: false);
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 250,
      ),
      itemCount: _favoriteProducts.length,
      itemBuilder: (context, index) {
        final product = _favoriteProducts[index];
        final itemId = product['item_id'] ?? product['id'];
        return ProductCard(
          product: product,
          imageOverlay: _buildFavoriteToggle(index),
          onTap: () {
            if (itemId == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(productId: itemId),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFavoriteToggle(int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleFavorite(index),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.favorite,
            color: AppColors.error,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index,
      {required bool isGrid}) {
    final imageUrl = resolveItemImageUrl(product['item_images']);

    return Container(
      margin: EdgeInsets.only(bottom: isGrid ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: product['inStock'] == false
              ? AppColors.warning.withOpacity(0.5)
              : Colors.grey[300]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigate to product detail screen
            final itemId = product['item_id'] ?? product['id'];
            if (itemId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(
                    productId: itemId,
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: EdgeInsets.all(isGrid ? 8 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product image
                Container(
                  height: isGrid ? 100 : 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.2),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      if (imageUrl != null)
                        Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.primaryGreen,
                              size: isGrid ? 28 : 40,
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.primaryGreen,
                            size: isGrid ? 28 : 40,
                          ),
                        ),
                      // Favorite button
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _toggleFavorite(index),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(isGrid ? 4 : 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.favorite,
                                color: AppColors.error,
                                size: isGrid ? 14 : 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Out of stock badge
                      if (product['inStock'] == false)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          right: 6,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Out of Stock',
                              style: TextStyle(
                                fontSize: isGrid ? 8 : 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: isGrid ? 6 : 12),
                // Product name
                Flexible(
                  child: Text(
                    product['name']?.toString() ??
                        product['item_name']?.toString() ??
                        'Unknown Product',
                    style: TextStyle(
                      fontSize: isGrid ? 11 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: isGrid ? 2 : 4),
                // Category
                Text(
                  product['category']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: isGrid ? 9 : 11,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isGrid ? 4 : 6),
                // Rating
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: isGrid ? 10 : 14,
                      color: AppColors.accentAmber,
                    ),
                    SizedBox(width: 2),
                    Text(
                      '${(product['rating'] ?? 0.0) is num ? (product['rating'] as num).toStringAsFixed(1) : '0.0'}',
                      style: TextStyle(
                        fontSize: isGrid ? 10 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isGrid ? 4 : 8),
                // Price and vendor
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₱${(product['price'] ?? 0.0) is num ? (product['price'] as num).toStringAsFixed(2) : '0.00'}',
                            style: TextStyle(
                              fontSize: isGrid ? 12 : 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          if (!isGrid &&
                              (product['vendor']?.toString().isNotEmpty ??
                                  false)) ...[
                            SizedBox(height: 2),
                            Text(
                              product['vendor']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Add to cart button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: product['inStock'] == false
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${product['name']} added to cart'),
                                    backgroundColor: AppColors.primaryGreen,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(isGrid ? 6 : 8),
                          decoration: BoxDecoration(
                            color: product['inStock'] == false
                                ? Colors.grey[300]
                                : AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.add_shopping_cart,
                            size: isGrid ? 14 : 18,
                            color: product['inStock'] == false
                                ? Colors.grey[500]
                                : AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
