import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/constants.dart';
import '../provider/provider.dart';
import '../services/cart_services.dart';
import '../services/favorite_services.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

class ProductDetailScreen extends StatefulWidget {
  final dynamic productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _selectedImageIndex = 0;
  int _quantity = 1;
  bool _isFavorite = false;
  bool _showAllReviews = false;
  bool _isAddingToCart = false;
  bool _isTogglingFavorite = false;
  String? _favoriteId; // Store favorite record ID for removal
  late double _averageRating;
  final FavoriteService _favoriteService = FavoriteService();

  // Static sample data for images
  final List<String> _sampleImages = [
    'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800',
    'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800',
    'https://images.unsplash.com/photo-1516253593875-bd7ba052fbc5?w=800',
  ];

  @override
  void initState() {
    super.initState();
    // Fetch reviews when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
      itemsProvider.fetchItemReviews(widget.productId);
      _checkFavoriteStatus();
    });

    _averageRating = _getAverage() as double;
  }

  // Check if item is already in favorites
  Future<void> _checkFavoriteStatus() async {
    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        return;
      }

      final isFavorite = await _favoriteService.isItemFavorite(
        userId,
        widget.productId.toString(),
      );

      if (isFavorite) {
        // Fetch favorites to get the favorite record ID
        final favorites = await _favoriteService.fetchFavoritesFromAPI(userId);
        final favorite = favorites.firstWhere(
          (fav) => fav['item_id'].toString() == widget.productId.toString(),
          orElse: () => {},
        );
        if (favorite.isNotEmpty) {
          setState(() {
            _isFavorite = true;
            _favoriteId = favorite['id'].toString();
          });
        }
      }
    } catch (e) {
      // Silently fail - user might not be logged in or network error
      print('Error checking favorite status: $e');
    }
  }

  // Toggle favorite status via API
  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite) return;

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            'Please login to add items to favorites',
          );
        }
        setState(() {
          _isTogglingFavorite = false;
        });
        return;
      }

      if (_isFavorite) {
        // Remove from favorites
        if (_favoriteId == null) {
          // Need to fetch favorites to get the favorite ID
          final favorites =
              await _favoriteService.fetchFavoritesFromAPI(userId);
          final favorite = favorites.firstWhere(
            (fav) => fav['item_id'].toString() == widget.productId.toString(),
            orElse: () => {},
          );
          if (favorite.isEmpty) {
            setState(() {
              _isFavorite = false;
              _isTogglingFavorite = false;
            });
            return;
          }
          _favoriteId = favorite['id'].toString();
        }

        final result = await _favoriteService.removeFromFavorites(_favoriteId!);
        if (mounted) {
          if (result['success'] == true) {
            setState(() {
              _isFavorite = false;
              _favoriteId = null;
            });
            SnackbarHelper.showSuccess(
              context,
              result['message'] ?? 'Removed from favorites',
              duration: Duration(seconds: 1),
            );
          } else {
            SnackbarHelper.showError(
              context,
              result['message'] ?? 'Failed to remove from favorites',
            );
          }
        }
      } else {
        // Add to favorites
        final result = await _favoriteService.addToFavorites(
          userId: userId,
          itemId: widget.productId.toString(),
        );
        if (mounted) {
          if (result['success'] == true) {
            // Fetch favorites to get the favorite record ID
            final favorites =
                await _favoriteService.fetchFavoritesFromAPI(userId);
            final favorite = favorites.firstWhere(
              (fav) => fav['item_id'].toString() == widget.productId.toString(),
              orElse: () => {},
            );
            setState(() {
              _isFavorite = true;
              if (favorite.isNotEmpty) {
                _favoriteId = favorite['id'].toString();
              }
            });
            SnackbarHelper.showSuccess(
              context,
              result['message'] ?? 'Added to favorites',
              duration: Duration(seconds: 1),
            );
          } else {
            SnackbarHelper.showError(
              context,
              result['message'] ?? 'Failed to add to favorites',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Error updating favorite: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingFavorite = false;
        });
      }
    }
  }

  // Helper method to safely parse price
  double _parsePrice(dynamic price) {
    if (price == null) return 299.99;
    if (price is num) return price.toDouble();
    if (price is String) {
      final parsed = double.tryParse(price);
      return parsed ?? 299.99;
    }
    return 299.99;
  }

  // Helper method to safely parse rating
  double _parseRating(dynamic rating) {
    if (rating == null) return 0.0;
    if (rating is num) return rating.toDouble();
    if (rating is String) {
      final parsed = double.tryParse(rating);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  // Helper method to safely parse stock quantity
  int _parseStock(dynamic stock) {
    if (stock == null) return 50;
    if (stock is num) return stock.toInt();
    if (stock is String) {
      final parsed = int.tryParse(stock);
      return parsed ?? 50;
    }
    return 50;
  }

  // Method to Get averageRating
  double _getAverage() {
    final reviews = Provider.of<ItemsProvider>(context, listen: false)
        .getReviewsList(widget.productId);

    // Calculate average rating from reviews
    double averageRating = 0.0;
    if (reviews.isNotEmpty) {
      final totalRating = reviews.fold<double>(
        0.0,
        (sum, review) => sum + (review['rating'] as num).toDouble(),
      );
      return averageRating = totalRating / reviews.length;
    } else {
      return 0.00;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get product from provider using productId
    final itemsProvider = Provider.of<ItemsProvider>(context);
    final product = itemsProvider.getItemById(widget.productId);

    // Use product data if found, otherwise use sample data
    final productName = product?['item_name'] ?? 'Premium Organic Seeds';
    final productPrice = _parsePrice(product?['item_price']);
    final productDescription = product?['item_description'] ?? '';
    final productRating = _parseRating(product?['average_rating']);
    final productStock = _parseStock(product?['item_quantity']);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            _buildAppBar(),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Carousel
                    _buildImageCarousel(),
                    SizedBox(height: 20),

                    // Product Info Section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Badge
                          // Container(
                          //   padding: EdgeInsets.symmetric(
                          //       horizontal: 12, vertical: 6),
                          //   decoration: BoxDecoration(
                          //     color: AppColors.mediumGreen.withOpacity(0.1),
                          //     borderRadius: BorderRadius.circular(20),
                          //   ),
                          //   child: Text(
                          //     productCategory,
                          //     style: TextStyle(
                          //       fontSize: 12,
                          //       fontWeight: FontWeight.w600,
                          //       color: AppColors.mediumGreen,
                          //     ),
                          //   ),
                          // ),
                          // SizedBox(height: 12),

                          // Product Name
                          Text(
                            productName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 12),

                          // Rating and Stock
                          Row(
                            children: [
                              // Rating
                              Row(
                                children: [
                                  Icon(Icons.star,
                                      color: Colors.amber[600], size: 20),
                                  SizedBox(width: 4),
                                  Text(
                                    productRating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Builder(
                                    builder: (context) {
                                      final itemsProvider =
                                          Provider.of<ItemsProvider>(context);
                                      final reviewsList = itemsProvider
                                          .getReviewsList(widget.productId);
                                      final totalReviews = reviewsList.length;
                                      return Text(
                                        '($totalReviews reviews)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              Spacer(),
                              // Stock Status
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: productStock > 0
                                      ? Colors.green[50]
                                      : Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: productStock > 0
                                        ? Colors.green[300]!
                                        : Colors.red[300]!,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      productStock > 0
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: 14,
                                      color: productStock > 0
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      productStock > 0
                                          ? 'In Stock: $productStock'
                                          : 'Out of Stock',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: productStock > 0
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),

                          // Price
                          Row(
                            children: [
                              Text(
                                '₱${productPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.mediumGreen,
                                ),
                              ),
                              SizedBox(width: 8),
                              if (productPrice > 200)
                                Text(
                                  '₱${(productPrice * 1.2).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey[400],
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 24),

                          // Description
                          _buildDescriptionSection(productDescription),
                          SizedBox(height: 24),

                          // Reviews Section
                          _buildReviewsSection(),
                          SizedBox(height: 24),

                          // Related Products (Sample)
                          _buildRelatedProducts(),
                          SizedBox(height: 100), // Space for bottom button
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            _buildBottomActionBar(productPrice, productStock > 0),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Spacer(),
          IconButton(
            icon: _isTogglingFavorite
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isFavorite ? Colors.red : Colors.grey[800]!,
                      ),
                    ),
                  )
                : Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.grey[800],
                  ),
            onPressed: _isTogglingFavorite ? null : _toggleFavorite,
          ),
          IconButton(
            icon: Icon(Icons.share, color: Colors.grey[800]),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Share product'),
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

  Widget _buildImageCarousel() {
    return Container(
      height: 350,
      child: Stack(
        children: [
          // Image PageView
          PageView.builder(
            itemCount: _sampleImages.length,
            onPageChanged: (index) {
              setState(() {
                _selectedImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                color: AppColors.mediumGreen.withOpacity(0.1),
                child: Center(
                  child: Icon(
                    Icons.image,
                    size: 100,
                    color: AppColors.mediumGreen.withOpacity(0.5),
                  ),
                ),
                // In real implementation, use Image.network(_sampleImages[index])
              );
            },
          ),

          // Image Indicators
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _sampleImages.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selectedImageIndex == index
                        ? AppColors.mediumGreen
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 12),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 16),

        // Key Features
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Key Features',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
              ),
              SizedBox(height: 12),
              _buildFeatureItem(Icons.eco, '100% Organic'),
              _buildFeatureItem(Icons.verified, 'Tested for Quality'),
              _buildFeatureItem(Icons.local_shipping, 'Fast Delivery'),
              _buildFeatureItem(Icons.support_agent, 'Customer Support'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mediumGreen),
          SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Consumer<ItemsProvider>(
      builder: (context, itemsProvider, child) {
        final reviewsData = itemsProvider.getItemReviews(widget.productId);
        final isLoading = itemsProvider.isReviewsLoading(widget.productId);
        final error = itemsProvider.getReviewsError(widget.productId);

        //Here!!!
        final reviews = itemsProvider.getReviewsList(widget.productId);

        // Calculate average rating from reviews
        double averageRating = 0.0;
        if (reviews.isNotEmpty) {
          final totalRating = reviews.fold<double>(
            0.0,
            (sum, review) => sum + (review['rating'] as num).toDouble(),
          );
          averageRating = totalRating / reviews.length;
        } else if (reviewsData != null &&
            reviewsData['average_rating'] != null) {
          averageRating = _parseRating(reviewsData['average_rating']);
        }

        final totalReviews = reviews.length;

        // Calculate rating distribution
        final ratingCounts = Map<int, int>.from({5: 0, 4: 0, 3: 0, 2: 0, 1: 0});
        for (var review in reviews) {
          final rating = (review['rating'] as num).toInt();
          if (ratingCounts.containsKey(rating)) {
            ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reviews & Ratings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                if (reviews.length > 3)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showAllReviews = !_showAllReviews;
                      });
                    },
                    child: Text(
                      _showAllReviews ? 'Show Less' : 'View All',
                      style: TextStyle(
                        color: AppColors.mediumGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            if (isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    color: AppColors.mediumGreen,
                  ),
                ),
              )
            else if (error != null)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load reviews',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          itemsProvider.fetchItemReviews(widget.productId);
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (reviews.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No reviews yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else ...[
              // Rating Summary
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Text(
                          averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                        ),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < averageRating.floor()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: Colors.amber[600],
                            );
                          }),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$totalReviews reviews',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRatingBar(
                              5, ratingCounts[5] ?? 0, reviews.length),
                          _buildRatingBar(
                              4, ratingCounts[4] ?? 0, reviews.length),
                          _buildRatingBar(
                              3, ratingCounts[3] ?? 0, reviews.length),
                          _buildRatingBar(
                              2, ratingCounts[2] ?? 0, reviews.length),
                          _buildRatingBar(
                              1, ratingCounts[1] ?? 0, reviews.length),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Reviews List - Show all reviews if _showAllReviews is true, otherwise show first 3
              ...(_showAllReviews || reviews.length <= 3
                  ? reviews.map((review) => _buildReviewCard(review))
                  : reviews.take(3).map((review) => _buildReviewCard(review))),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final percentage = total > 0 ? count / total : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$stars',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            textAlign: TextAlign.right,
          ),
          SizedBox(width: 4),
          Icon(Icons.star, size: 14, color: Colors.amber[600]),
          SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber[600]!),
                minHeight: 6,
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    // Format date from API (e.g., "2025-11-24T21:24:05.000000Z")
    String formattedDate = '';
    if (review['created_at'] != null) {
      try {
        final dateTime = DateTime.parse(review['created_at']);
        formattedDate =
            '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      } catch (e) {
        formattedDate = review['created_at'].toString();
      }
    }

    final username = review['username'] ?? 'Anonymous';
    final rating = (review['rating'] as num).toDouble();
    final comment = review['comment'] ?? '';
    final verified = review['verified'] == true || review['verified'] == 'true';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.mediumGreen.withOpacity(0.2),
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'A',
                  style: TextStyle(
                    color: AppColors.mediumGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          username,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                        if (verified) ...[
                          SizedBox(width: 6),
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: AppColors.mediumGreen,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: Colors.amber[600],
                          );
                        }),
                        if (formattedDate.isNotEmpty) ...[
                          SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You May Also Like',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                width: 150,
                margin: EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.mediumGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.shopping_bag,
                          color: AppColors.mediumGreen,
                          size: 40,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product ${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '₱${(199.99 + index * 50).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.mediumGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleAddToCart(double price) async {
    setState(() {
      _isAddingToCart = true;
    });

    try {
      // Get user ID
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            'Please login to add items to cart',
          );
        }
        setState(() {
          _isAddingToCart = false;
        });
        return;
      }

      // Call addToCart service
      final cartService = CartService();
      final result = await cartService.addToCart(
        userId: userId,
        itemId: widget.productId.toString(),
        price: price,
        quantity: _quantity,
      );

      if (mounted) {
        if (result['success'] == true) {
          SnackbarHelper.showSuccess(
            context,
            result['message'] ?? 'Added $_quantity item(s) to cart',
            duration: Duration(seconds: 2),
          );
        } else {
          SnackbarHelper.showError(
            context,
            result['message'] ?? 'Failed to add item to cart',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Error adding to cart: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  Widget _buildBottomActionBar(double price, bool inStock) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Quantity Selector
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove, size: 20),
                    onPressed: _quantity > 1
                        ? () {
                            setState(() {
                              _quantity--;
                            });
                          }
                        : null,
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(),
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '$_quantity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add, size: 20),
                    onPressed: () {
                      setState(() {
                        _quantity++;
                      });
                    },
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),

            // Add to Cart Button
            Expanded(
              child: ElevatedButton(
                onPressed: (inStock && !_isAddingToCart)
                    ? () async {
                        await _handleAddToCart(price);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mediumGreen,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isAddingToCart
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Add to Cart',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
