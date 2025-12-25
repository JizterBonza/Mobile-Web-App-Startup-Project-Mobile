import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/provider.dart';
import 'productDetailScreen.dart';
import 'shopReviewsScreen.dart';

class ShopScreen extends StatefulWidget {
  final dynamic shopId;
  final String? shopName;

  const ShopScreen({
    super.key,
    required this.shopId,
    this.shopName,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _shopDetails;
  List<Map<String, dynamic>> _shopItems = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShopData();
    });
  }

  Future<void> _loadShopData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final shopsProvider = Provider.of<ShopsProvider>(context, listen: false);

      // Fetch shop details, items, and reviews in parallel
      await Future.wait([
        shopsProvider.fetchShopDetails(widget.shopId),
        shopsProvider.fetchShopItems(widget.shopId),
        shopsProvider.fetchShopReviews(widget.shopId),
      ]);

      final shopData = shopsProvider.getShopDetails(widget.shopId);
      final items = shopsProvider.getShopItems(widget.shopId);

      //print('Shop data received: $shopData');
      //print('Shop items received: ${items.length} items');

      if (mounted) {
        setState(() {
          _shopDetails = shopData;
          _shopItems = items;
          _isLoading = false;
          _error = shopsProvider.getDetailsError(widget.shopId) ??
              shopsProvider.getItemsError(widget.shopId);
        });
      }
    } catch (e) {
      //print('Error loading shop data: $e');
      //print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
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
      //print('Error formatting price: $e');
    }
    return '₱0.00';
  }

  String _formatRating(dynamic rating) {
    if (rating == null) return '0.0';
    try {
      if (rating is num) {
        return rating.toStringAsFixed(1);
      } else if (rating is String) {
        final parsed = double.tryParse(rating);
        return parsed != null ? parsed.toStringAsFixed(1) : '0.0';
      }
    } catch (e) {
      //print('Error formatting rating: $e');
    }
    return '0.0';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _loadShopData,
                          color: AppColors.mediumGreen,
                          child: SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Shop Header
                                _buildShopHeader(),

                                // Shop Stats
                                _buildShopStats(),

                                // Products Section
                                _buildProductsSection(),

                                // Reviews Preview Section
                                SizedBox(height: 12),
                                _buildReviewsPreview(),

                                SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              widget.shopName ?? _shopDetails?['shop_name'] ?? 'Shop',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.share, color: Colors.grey[800]),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Share shop'),
                  duration: Duration(seconds: 1),
                  backgroundColor: AppColors.mediumGreen,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.mediumGreen,
          ),
          SizedBox(height: 16),
          Text(
            'Loading shop...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Failed to load shop',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _error ?? 'An error occurred',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadShopData,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mediumGreen,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopHeader() {
    final shopLogo = _shopDetails?['shop_logo'];
    final hasLogo = shopLogo != null && shopLogo.toString().isNotEmpty;
    final isVerified = _shopDetails?['is_verified'] == true;
    final shopBanner = _shopDetails?['shop_banner'];
    final hasBanner = shopBanner != null && shopBanner.toString().isNotEmpty;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Banner
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.mediumGreen,
                  AppColors.mediumGreen.withOpacity(0.7),
                ],
              ),
            ),
            child: hasBanner
                ? Image.network(
                    shopBanner.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container();
                    },
                  )
                : Center(
                    child: Icon(
                      Icons.store,
                      size: 48,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
          ),

          // Shop Info
          Transform.translate(
            offset: Offset(0, -40),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Shop Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: hasLogo
                          ? Image.network(
                              shopLogo.toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.mediumGreen.withOpacity(0.1),
                                  child: Icon(
                                    Icons.store,
                                    size: 36,
                                    color: AppColors.mediumGreen,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: AppColors.mediumGreen.withOpacity(0.1),
                              child: Icon(
                                Icons.store,
                                size: 36,
                                color: AppColors.mediumGreen,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Shop Name with Verified Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _shopDetails?['shop_name'] ?? 'Shop',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        SizedBox(width: 8),
                        Icon(
                          Icons.verified,
                          size: 22,
                          color: Colors.blue[600],
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 8),

                  // Shop Description
                  if (_shopDetails?['shop_description'] != null &&
                      _shopDetails!['shop_description'].toString().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _shopDetails!['shop_description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopStats() {
    final rating = _shopDetails?['shop_rating'];
    final totalProducts = _shopItems.length;
    final totalReviews = _shopDetails?['total_reviews'] ?? 0;

    return Transform.translate(
      offset: Offset(0, -24),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.star,
              iconColor: Colors.amber[600]!,
              value: _formatRating(rating),
              label: 'Rating',
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[200],
            ),
            _buildStatItem(
              icon: Icons.shopping_bag,
              iconColor: AppColors.mediumGreen,
              value: '$totalProducts',
              label: 'Products',
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[200],
            ),
            _buildStatItem(
              icon: Icons.rate_review,
              iconColor: Colors.blue[600]!,
              value: '$totalReviews',
              label: 'Reviews',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsPreview() {
    return Consumer<ShopsProvider>(
      builder: (context, shopsProvider, child) {
        final reviewsData = shopsProvider.getShopReviews(widget.shopId);
        final reviews = shopsProvider.getShopReviewsList(widget.shopId);
        final isLoading = shopsProvider.isReviewsLoading(widget.shopId);
        final totalReviews = reviewsData?['total_reviews'] ?? reviews.length;
        final avgRating = reviewsData?['average_rating'];

        // Take only first 3 reviews for preview
        final previewReviews = reviews.take(3).toList();

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Customer Reviews',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      SizedBox(width: 8),
                      if (avgRating != null) ...[
                        Icon(Icons.star, size: 18, color: Colors.amber[600]),
                        SizedBox(width: 4),
                        Text(
                          _formatRating(avgRating),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          ' ($totalReviews)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (totalReviews > 0)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          _createFadeRoute(
                            ShopReviewsScreen(
                              shopId: widget.shopId,
                              shopName:
                                  widget.shopName ?? _shopDetails?['shop_name'],
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'See All',
                        style: TextStyle(
                          color: AppColors.mediumGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12),
              if (isLoading)
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.mediumGreen,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (previewReviews.isEmpty)
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          size: 40,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No reviews yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
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
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: previewReviews.asMap().entries.map((entry) {
                      final index = entry.key;
                      final review = entry.value;
                      final isLast = index == previewReviews.length - 1;
                      return _buildReviewCard(review, isLast: isLast);
                    }).toList(),
                  ),
                ),
              SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, {bool isLast = false}) {
    final username = review['username'] ?? 'Anonymous';
    final rating = review['rating'] is num
        ? (review['rating'] as num).toDouble()
        : double.tryParse(review['rating']?.toString() ?? '0') ?? 0.0;
    final comment = review['comment'] ?? '';
    final itemName = review['item_name'];
    final createdAt = review['created_at'];

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // User avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.mediumGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : 'A',
                    style: TextStyle(
                      color: AppColors.mediumGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating.round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: Colors.amber[600],
                          );
                        }),
                        SizedBox(width: 8),
                        if (createdAt != null)
                          Text(
                            _formatReviewDate(createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (itemName != null && itemName.toString().isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                itemName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (comment.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatReviewDate(String dateString) {
    try {
      final dateTime = DateTime.tryParse(dateString);
      if (dateTime != null) {
        final now = DateTime.now();
        final difference = now.difference(dateTime);

        if (difference.inDays == 0) {
          if (difference.inHours == 0) {
            return '${difference.inMinutes}m ago';
          }
          return '${difference.inHours}h ago';
        } else if (difference.inDays < 7) {
          return '${difference.inDays}d ago';
        } else if (difference.inDays < 30) {
          return '${(difference.inDays / 7).floor()}w ago';
        } else {
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
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return '';
  }

  Widget _buildProductsSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Products',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              Text(
                '${_shopItems.length} items',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_shopItems.isEmpty)
            Container(
              padding: EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No products yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'This shop hasn\'t added any products',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
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
              itemCount: _shopItems.length,
              itemBuilder: (context, index) {
                final product = _shopItems[index];
                return _buildProductCard(product);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final itemImages = product['item_images'];
    final hasImage = itemImages != null &&
        itemImages is List &&
        (itemImages as List).isNotEmpty;
    final imageUrl = hasImage ? (itemImages as List).first.toString() : null;
    final productName = product['item_name'] ?? 'Unknown Product';
    final productPrice = product['item_price'];
    final productRating = product['average_rating'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              _createFadeRoute(ProductDetailScreen(productId: product['id'])),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.mediumGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.shopping_bag,
                                  size: 40,
                                  color: AppColors.mediumGreen.withOpacity(0.5),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.shopping_bag,
                            size: 40,
                            color: AppColors.mediumGreen.withOpacity(0.5),
                          ),
                        ),
                ),
              ),

              // Product Info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatRating(productRating),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatPrice(productPrice),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mediumGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
