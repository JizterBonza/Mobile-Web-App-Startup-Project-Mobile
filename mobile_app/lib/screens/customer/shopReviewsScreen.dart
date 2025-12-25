import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/provider.dart';

class ShopReviewsScreen extends StatefulWidget {
  final dynamic shopId;
  final String? shopName;

  const ShopReviewsScreen({
    super.key,
    required this.shopId,
    this.shopName,
  });

  @override
  State<ShopReviewsScreen> createState() => _ShopReviewsScreenState();
}

class _ShopReviewsScreenState extends State<ShopReviewsScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    // Reviews should already be loaded from ShopScreen
    // but refresh if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shopsProvider = Provider.of<ShopsProvider>(context, listen: false);
      if (shopsProvider.getShopReviews(widget.shopId) == null) {
        shopsProvider.fetchShopReviews(widget.shopId);
      }
    });
  }

  Future<void> _refreshReviews() async {
    final shopsProvider = Provider.of<ShopsProvider>(context, listen: false);
    await shopsProvider.fetchShopReviews(widget.shopId);
  }

  List<Map<String, dynamic>> _filterReviews(
      List<Map<String, dynamic>> reviews) {
    if (_selectedFilter == 'all') return reviews;

    final filterRating = int.tryParse(_selectedFilter);
    if (filterRating == null) return reviews;

    return reviews.where((review) {
      final rating = review['rating'] is num
          ? (review['rating'] as num).round()
          : int.tryParse(review['rating']?.toString() ?? '0') ?? 0;
      return rating == filterRating;
    }).toList();
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
      // Ignore
    }
    return '0.0';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Consumer<ShopsProvider>(
                builder: (context, shopsProvider, child) {
                  final reviewsData =
                      shopsProvider.getShopReviews(widget.shopId);
                  final allReviews =
                      shopsProvider.getShopReviewsList(widget.shopId);
                  final isLoading =
                      shopsProvider.isReviewsLoading(widget.shopId);
                  final error = shopsProvider.getReviewsError(widget.shopId);

                  if (isLoading && allReviews.isEmpty) {
                    return _buildLoadingState();
                  }

                  if (error != null && allReviews.isEmpty) {
                    return _buildErrorState(error);
                  }

                  final filteredReviews = _filterReviews(allReviews);

                  return RefreshIndicator(
                    onRefresh: _refreshReviews,
                    color: AppColors.mediumGreen,
                    child: CustomScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Rating Summary
                        SliverToBoxAdapter(
                          child: _buildRatingSummary(reviewsData, allReviews),
                        ),

                        // Filter Chips
                        SliverToBoxAdapter(
                          child: _buildFilterChips(allReviews),
                        ),

                        // Reviews List
                        if (filteredReviews.isEmpty)
                          SliverToBoxAdapter(
                            child: _buildEmptyState(),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return _buildReviewCard(filteredReviews[index]);
                              },
                              childCount: filteredReviews.length,
                            ),
                          ),

                        // Bottom padding
                        SliverToBoxAdapter(
                          child: SizedBox(height: 24),
                        ),
                      ],
                    ),
                  );
                },
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reviews',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                if (widget.shopName != null)
                  Text(
                    widget.shopName!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
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
          CircularProgressIndicator(color: AppColors.mediumGreen),
          SizedBox(height: 16),
          Text(
            'Loading reviews...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Failed to load reviews',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshReviews,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mediumGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              _selectedFilter == 'all'
                  ? 'No reviews yet'
                  : 'No $_selectedFilter-star reviews',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _selectedFilter == 'all'
                  ? 'Be the first to review this shop!'
                  : 'Try a different filter',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSummary(
      Map<String, dynamic>? reviewsData, List<Map<String, dynamic>> reviews) {
    final avgRating = reviewsData?['average_rating'];
    final totalReviews = reviewsData?['total_reviews'] ?? reviews.length;

    // Calculate rating distribution
    Map<int, int> ratingCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (var review in reviews) {
      final rating = review['rating'] is num
          ? (review['rating'] as num).round()
          : int.tryParse(review['rating']?.toString() ?? '0') ?? 0;
      if (rating >= 1 && rating <= 5) {
        ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
      }
    }

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Average Rating
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  _formatRating(avgRating),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final rating = avgRating is num
                        ? avgRating.toDouble()
                        : double.tryParse(avgRating?.toString() ?? '0') ?? 0.0;
                    return Icon(
                      index < rating.round() ? Icons.star : Icons.star_border,
                      size: 20,
                      color: Colors.amber[600],
                    );
                  }),
                ),
                SizedBox(height: 4),
                Text(
                  '$totalReviews reviews',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 100,
            color: Colors.grey[200],
            margin: EdgeInsets.symmetric(horizontal: 16),
          ),
          // Rating Distribution
          Expanded(
            flex: 3,
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = ratingCounts[star] ?? 0;
                final percentage =
                    totalReviews > 0 ? count / totalReviews : 0.0;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '$star',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.star, size: 12, color: Colors.amber[600]),
                      SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.mediumGreen,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<Map<String, dynamic>> reviews) {
    final filters = [
      {'label': 'All', 'value': 'all'},
      {'label': '5 ★', 'value': '5'},
      {'label': '4 ★', 'value': '4'},
      {'label': '3 ★', 'value': '3'},
      {'label': '2 ★', 'value': '2'},
      {'label': '1 ★', 'value': '1'},
    ];

    return Container(
      height: 48,
      margin: EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['value'];

          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['value']!;
                });
              },
              backgroundColor: Colors.white,
              selectedColor: AppColors.mediumGreen.withOpacity(0.15),
              checkmarkColor: AppColors.mediumGreen,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.mediumGreen : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.mediumGreen : Colors.grey[300]!,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final username = review['username'] ?? 'Anonymous';
    final rating = review['rating'] is num
        ? (review['rating'] as num).toDouble()
        : double.tryParse(review['rating']?.toString() ?? '0') ?? 0.0;
    final comment = review['comment'] ?? '';
    final itemName = review['item_name'];
    final createdAt = review['created_at'];
    final reviewImages = review['review_images'];
    final hasImages =
        reviewImages != null && reviewImages is List && reviewImages.isNotEmpty;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info and rating
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.mediumGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : 'A',
                    style: TextStyle(
                      color: AppColors.mediumGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
                        fontSize: 15,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating.round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 16,
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

          // Item name badge
          if (itemName != null && itemName.toString().isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 14, color: Colors.grey[600]),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      itemName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Review comment
          if (comment.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],

          // Review images
          if (hasImages) ...[
            SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (reviewImages as List).length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 80,
                    height: 80,
                    margin: EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        reviewImages[index].toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.image, color: Colors.grey[400]),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
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
}
