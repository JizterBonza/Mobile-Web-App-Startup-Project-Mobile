import 'package:flutter/material.dart';
import '../constants/constants.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  const ProductDetailScreen({
    super.key,
    this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _selectedImageIndex = 0;
  int _quantity = 1;
  bool _isFavorite = false;

  // Static sample data
  final List<String> _sampleImages = [
    'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800',
    'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800',
    'https://images.unsplash.com/photo-1516253593875-bd7ba052fbc5?w=800',
  ];

  final List<Map<String, dynamic>> _sampleReviews = [
    {
      'userName': 'Juan Dela Cruz',
      'rating': 5.0,
      'date': '2024-01-15',
      'comment':
          'Excellent quality seeds! Germination rate was very high. Highly recommend this product.',
      'verified': true,
    },
    {
      'userName': 'Maria Santos',
      'rating': 4.5,
      'date': '2024-01-10',
      'comment':
          'Good product, fast delivery. The seeds grew well in my garden. Will order again.',
      'verified': true,
    },
    {
      'userName': 'Pedro Garcia',
      'rating': 5.0,
      'date': '2024-01-05',
      'comment':
          'Amazing! My plants are thriving. The quality exceeded my expectations.',
      'verified': false,
    },
    {
      'userName': 'Ana Rodriguez',
      'rating': 4.0,
      'date': '2023-12-28',
      'comment':
          'Decent product for the price. Packaging could be better, but seeds are good.',
      'verified': true,
    },
  ];

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
    if (rating == null) return 4.5;
    if (rating is num) return rating.toDouble();
    if (rating is String) {
      final parsed = double.tryParse(rating);
      return parsed ?? 4.5;
    }
    return 4.5;
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

  @override
  Widget build(BuildContext context) {
    // Use product data if provided, otherwise use sample data
    final productName = widget.product?['item_name'] ?? 'Premium Organic Seeds';
    final productPrice = _parsePrice(widget.product?['item_price']);
    final productDescription = widget.product?['item_description'] ?? '';
    final productRating = _parseRating(widget.product?['average_rating']);
    final productStock = _parseStock(widget.product?['item_quantity']);

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
                                  Text(
                                    '(${_sampleReviews.length} reviews)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
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
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.grey[800],
            ),
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isFavorite
                        ? 'Added to favorites'
                        : 'Removed from favorites',
                  ),
                  duration: Duration(seconds: 1),
                  backgroundColor: AppColors.mediumGreen,
                ),
              );
            },
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
    final averageRating = _sampleReviews
            .map((r) => r['rating'] as double)
            .reduce((a, b) => a + b) /
        _sampleReviews.length;

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
            TextButton(
              onPressed: () {
                // Handle view all reviews
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
                    '${_sampleReviews.length} reviews',
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
                    _buildRatingBar(5, 3),
                    _buildRatingBar(4, 1),
                    _buildRatingBar(3, 0),
                    _buildRatingBar(2, 0),
                    _buildRatingBar(1, 0),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // Reviews List
        ..._sampleReviews.take(3).map((review) => _buildReviewCard(review)),
      ],
    );
  }

  Widget _buildRatingBar(int stars, int count) {
    final total = _sampleReviews.length;
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
                  review['userName'][0].toUpperCase(),
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
                          review['userName'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                        if (review['verified'] == true) ...[
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
                            index < (review['rating'] as double).floor()
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: Colors.amber[600],
                          );
                        }),
                        SizedBox(width: 8),
                        Text(
                          review['date'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            review['comment'],
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey[700],
            ),
          ),
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
                onPressed: inStock
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added $_quantity item(s) to cart',
                            ),
                            duration: Duration(seconds: 2),
                            backgroundColor: AppColors.mediumGreen,
                            action: SnackBarAction(
                              label: 'View Cart',
                              textColor: Colors.white,
                              onPressed: () {
                                // Navigate to cart
                              },
                            ),
                          ),
                        );
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
                child: Row(
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
