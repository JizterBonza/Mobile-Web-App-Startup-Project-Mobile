import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'customerDashboardScreen.dart';
import 'cartScreen.dart';
import 'profileScreen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  int _selectedIndex = 2; // Favorites tab
  // Sample favorite products - in real app, this would come from state management or API
  List<Map<String, dynamic>> _favoriteProducts = [
    {
      'id': '1',
      'name': 'Organic Fertilizer',
      'price': 24.99,
      'rating': 4.6,
      'category': 'Fertilizers',
      'vendor': 'Green Farm Supplies',
      'inStock': true,
    },
    {
      'id': '2',
      'name': 'Garden Spade',
      'price': 18.50,
      'rating': 4.9,
      'category': 'Tools',
      'vendor': 'Farm Tools Co.',
      'inStock': true,
    },
    {
      'id': '3',
      'name': 'Watering Can',
      'price': 15.99,
      'rating': 4.7,
      'category': 'Tools',
      'vendor': 'Garden Essentials',
      'inStock': true,
    },
    {
      'id': '4',
      'name': 'Premium Seeds Pack',
      'price': 32.50,
      'rating': 4.8,
      'category': 'Seeds',
      'vendor': 'Seed Masters',
      'inStock': false,
    },
  ];

  bool _isGridView = false;

  void _removeFavorite(int index) {
    setState(() {
      final removedProduct = _favoriteProducts[index];
      _favoriteProducts.removeAt(index);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${removedProduct['name']} removed from favorites'),
          backgroundColor: Colors.grey[800],
          duration: Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _favoriteProducts.insert(index, removedProduct);
              });
            },
          ),
        ),
      );
    });
  }

  void _toggleFavorite(int index) {
    _removeFavorite(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
          if (_favoriteProducts.isNotEmpty)
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
        ],
      ),
      body: _favoriteProducts.isEmpty
          ? _buildEmptyState()
          : _isGridView
              ? _buildGridView()
              : _buildListView(),
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
          } else if (index == 1) {
            // Cart
            Navigator.push(
              context,
              _createFadeRoute(CartScreen()),
            ).then((_) {
              // Keep favorites selected when returning
              setState(() {
                _selectedIndex = 2;
              });
            });
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
              Navigator.pop(context);
            },
            icon: Icon(Icons.shopping_bag_outlined, size: 18),
            label: Text('Browse Products'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mediumGreen,
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
        childAspectRatio: 0.75,
      ),
      itemCount: _favoriteProducts.length,
      itemBuilder: (context, index) {
        final product = _favoriteProducts[index];
        return _buildProductCard(product, index, isGrid: true);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index,
      {required bool isGrid}) {
    return Container(
      margin: EdgeInsets.only(bottom: isGrid ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: product['inStock'] == false
              ? Colors.orange[300]!
              : Colors.grey[300]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Handle product tap - navigate to product details
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Viewing ${product['name']}'),
                backgroundColor: AppColors.mediumGreen,
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(isGrid ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product image placeholder
                Container(
                  height: isGrid ? 120 : 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.mediumGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.mediumGreen.withOpacity(0.2),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.mediumGreen,
                          size: isGrid ? 32 : 40,
                        ),
                      ),
                      // Favorite button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _toggleFavorite(index),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(6),
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
                                color: Colors.red[600],
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Out of stock badge
                      if (product['inStock'] == false)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Out of Stock',
                              style: TextStyle(
                                fontSize: 10,
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
                SizedBox(height: 12),
                // Product name
                Text(
                  product['name'],
                  style: TextStyle(
                    fontSize: isGrid ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                // Category
                Text(
                  product['category'],
                  style: TextStyle(
                    fontSize: isGrid ? 10 : 11,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 6),
                // Rating
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: isGrid ? 12 : 14,
                      color: Colors.amber[600],
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${product['rating']}',
                      style: TextStyle(
                        fontSize: isGrid ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Price and vendor
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₱${(product['price'] as num).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isGrid ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.mediumGreen,
                            ),
                          ),
                          if (!isGrid) ...[
                            SizedBox(height: 2),
                            Text(
                              product['vendor'],
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
                                    backgroundColor: AppColors.mediumGreen,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: product['inStock'] == false
                                ? Colors.grey[300]
                                : AppColors.mediumGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.add_shopping_cart,
                            size: isGrid ? 16 : 18,
                            color: product['inStock'] == false
                                ? Colors.grey[500]
                                : AppColors.mediumGreen,
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
