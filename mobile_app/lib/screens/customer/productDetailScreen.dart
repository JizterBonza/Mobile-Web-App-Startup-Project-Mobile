import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/provider.dart';
import '../../services/cart_services.dart';
import '../../services/favorite_services.dart';
import '../../services/api_service.dart';
import '../../services/shops_service.dart';
import '../../utils/auth_guard.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/url.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'cartScreenV2.dart';
import 'checkOutScreen.dart';
import 'shopScreen.dart';

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
  bool _isBuyingNow = false;
  bool _isTogglingFavorite = false;
  String? _favoriteId; // Store favorite record ID for removal
  late double _averageRating;
  final FavoriteService _favoriteService = FavoriteService();
  final ShopsService _shopsService = ShopsService();
  Map<String, dynamic>? _shopDetails;
  bool _isLoadingShop = false;
  int _selectedVariantIndex = 0;
  dynamic _loadedShopId;

  @override
  void initState() {
    super.initState();
    // Fetch reviews when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
      itemsProvider.fetchItemReviews(widget.productId);
      _checkFavoriteStatus();
      final product = itemsProvider.getItemById(widget.productId);
      _ensureShopLoaded(product?['shop_id']);
    });

    _averageRating = _getAverage() as double;
  }

  Future<void> _ensureShopLoaded(dynamic shopId) async {
    if (shopId == null) return;
    if (_loadedShopId?.toString() == shopId.toString() &&
        _shopDetails != null) {
      return;
    }
    _loadedShopId = shopId;
    setState(() => _isLoadingShop = true);
    try {
      final shop = await _shopsService.fetchShopById(shopId.toString());
      if (!mounted) return;
      setState(() {
        _shopDetails = shop.isNotEmpty ? shop : null;
        _isLoadingShop = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _shopDetails = null;
        _isLoadingShop = false;
      });
    }
  }

  List<String> _resolveProductImages(Map<String, dynamic>? product) {
    final rawImages = product?['item_images'];
    if (rawImages is! List || rawImages.isEmpty) return const [];

    final urls = <String>[];
    for (final entry in rawImages) {
      String? raw;
      if (entry is Map) {
        raw = entry['url']?.toString() ??
            entry['image_url']?.toString() ??
            entry['path']?.toString() ??
            entry['item_image']?.toString();
      } else {
        raw = entry?.toString();
      }
      final resolved = _resolveMediaUrl(raw);
      if (resolved != null) urls.add(resolved);
    }
    return urls;
  }

  String? _resolveMediaUrl(String? raw) {
    if (raw == null) return null;
    final path = raw.trim();
    if (path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final baseUrl = Url.getUrl().replaceAll(RegExp(r'/+$'), '');
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$normalized';
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

    if (!await requireAuth(context)) return;

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
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

  String _formatDisplayPrice(double price) {
    if (price == price.roundToDouble()) {
      return '₱${price.toStringAsFixed(0)}';
    }
    return '₱${price.toStringAsFixed(2)}';
  }

  String _resolveCategoryName(BuildContext context, Map<String, dynamic>? product) {
    final raw = (product?['category'] ?? '').toString().trim();
    if (raw.isEmpty) return '';

    final categories =
        Provider.of<CategoryProvider>(context, listen: false).categories;
    for (final category in categories) {
      if (category['id']?.toString() == raw) {
        return (category['name'] ?? '').toString();
      }
    }
    for (final category in categories) {
      final name = (category['name'] ?? '').toString();
      if (name.toLowerCase() == raw.toLowerCase()) return name;
    }
    return int.tryParse(raw) != null ? '' : raw;
  }

  List<String> _resolveVariants(Map<String, dynamic>? product) {
    if (product == null) return const [];
    final raw = product['variations'] ??
        product['variants'] ??
        product['options'] ??
        product['sizes'];
    if (raw is! List || raw.isEmpty) return const [];

    final labels = <String>[];
    for (final entry in raw) {
      if (entry is Map) {
        final label = entry['name']?.toString() ??
            entry['label']?.toString() ??
            entry['size']?.toString() ??
            entry['value']?.toString();
        if (label != null && label.trim().isNotEmpty) {
          labels.add(label.trim());
        }
      } else {
        final label = entry?.toString().trim();
        if (label != null && label.isNotEmpty) labels.add(label);
      }
    }
    return labels;
  }

  int _parseSoldCount(dynamic sold) {
    if (sold is num) return sold.toInt();
    return int.tryParse(sold?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final itemsProvider = Provider.of<ItemsProvider>(context);
    final product = itemsProvider.getItemById(widget.productId);

    final productName = product?['item_name'] ?? 'Product';
    final productPrice = _parsePrice(product?['item_price']);
    final productDescription = product?['item_description']?.toString() ?? '';
    final productStock = _parseStock(product?['item_quantity']);
    final images = _resolveProductImages(product);
    final categoryName = _resolveCategoryName(context, product);
    final soldCount = _parseSoldCount(product?['sold_count']);
    final variants = _resolveVariants(product);
    final shopId = product?['shop_id'];
    final shopName = (_shopDetails?['shop_name'] ?? product?['shop_name'])
            ?.toString()
            .trim() ??
        '';

    if (shopId != null &&
        _loadedShopId?.toString() != shopId.toString() &&
        !_isLoadingShop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureShopLoaded(shopId);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageCarousel(images),
                      if (images.length > 1) _buildCarouselIndicators(images.length),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  _formatDisplayPrice(productPrice),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey[900],
                                    height: 1.1,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _isTogglingFavorite
                                      ? null
                                      : _toggleFavorite,
                                  child: _isTogglingFavorite
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.grey[500],
                                          ),
                                        )
                                      : Icon(
                                          _isFavorite
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 20,
                                          color: _isFavorite
                                              ? AppColors.error
                                              : Colors.grey[400],
                                        ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$soldCount sold',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (categoryName.isNotEmpty) ...[
                              Text(
                                categoryName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              productName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[900],
                                height: 1.2,
                              ),
                            ),
                            if (variants.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildVariantChips(variants),
                            ],
                            const SizedBox(height: 20),
                            _buildDescriptionSection(productDescription),
                            const SizedBox(height: 20),
                            _buildShopCard(
                              shopId: shopId,
                              shopName: shopName,
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildOverlayHeader(),
              ],
            ),
          ),
          _buildBottomActionBar(productPrice, productStock > 0),
        ],
      ),
    );
  }

  Widget _buildOverlayHeader() {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, top + 8, 12, 8),
        child: Row(
          children: [
            _buildCircleIconButton(
              onTap: () => Navigator.pop(context),
              child: SvgPicture.asset(
                'assets/icons/Back.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  Colors.grey[800]!,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const Spacer(),
            Consumer<BadgeProvider>(
              builder: (context, badges, _) {
                final count =
                    BadgeProvider.formatBadgeCount(badges.cartCount);
                return _buildCircleIconButton(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CartScreenV2(),
                      ),
                    );
                    if (mounted) {
                      context.read<BadgeProvider>().fetchBadges();
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/Crate.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          Colors.grey[800]!,
                          BlendMode.srcIn,
                        ),
                      ),
                      if (count != null)
                        Positioned(
                          top: -8,
                          right: -10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(minWidth: 16),
                            child: Text(
                              count,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            _buildCircleIconButton(
              onTap: () {
                SnackbarHelper.showSuccess(
                  context,
                  'Share product',
                  duration: const Duration(seconds: 1),
                );
              },
              child: SvgPicture.asset(
                'assets/icons/Share.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  Colors.grey[800]!,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIconButton({
    IconData? icon,
    Widget? child,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: child ??
                Icon(icon, size: 20, color: Colors.grey[800]),
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselIndicators(int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final selected = index == _selectedImageIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: selected ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryGreen
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVariantChips(List<String> variants) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(variants.length, (index) {
        final selected = index == _selectedVariantIndex;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedVariantIndex = index);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryGreenDark
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryGreenDark
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  variants[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.grey[500],
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: -5,
                  right: -5,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedVariantIndex = -1);
                    },
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 11,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildShopCard({
    required dynamic shopId,
    required String shopName,
  }) {
    final address = _shopDetails?['shop_address']?.toString().trim() ?? '';
    final zone = _shopDetails?['zone'] is Map
        ? (_shopDetails!['zone']['name']?.toString() ?? '')
        : (_shopDetails?['zone_name']?.toString() ??
            (_shopDetails?['zone_id'] != null
                ? 'Zone ${_shopDetails!['zone_id']}'
                : ''));
    final logoUrl = _shopDetails?['shop_logo']?.toString();
    final displayName =
        shopName.isNotEmpty ? shopName : 'Store';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: shopId == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopScreen(
                      shopId: shopId,
                      shopName: displayName,
                    ),
                  ),
                );
              },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              ClipOval(
                child: Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[200],
                  child: logoUrl != null && logoUrl.isNotEmpty
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.storefront,
                            color: Colors.grey[500],
                          ),
                        )
                      : Icon(
                          Icons.storefront,
                          color: Colors.grey[500],
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_isLoadingShop && address.isEmpty && zone.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey[400],
                          ),
                        ),
                      )
                    else ...[
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 13, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (zone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 13, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                zone,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[100],
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.grey[500],
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return _buildOverlayHeader();
  }

  Widget _buildImageCarousel(List<String> images) {
    final hasImages = images.isNotEmpty;
    final pageCount = hasImages ? images.length : 1;

    return SizedBox(
      height: MediaQuery.of(context).size.width * 0.92,
      width: double.infinity,
      child: PageView.builder(
        itemCount: pageCount,
        onPageChanged: (index) {
          setState(() {
            _selectedImageIndex = index;
          });
        },
        itemBuilder: (context, index) {
          if (!hasImages) {
            return Container(
              color: AppColors.primaryGreen.withOpacity(0.1),
              child: Center(
                child: Icon(
                  Icons.image,
                  size: 100,
                  color: AppColors.primaryGreen.withOpacity(0.5),
                ),
              ),
            );
          }

          return Image.network(
            images[index],
            fit: BoxFit.cover,
            width: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: AppColors.primaryGreen.withOpacity(0.08),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppColors.primaryGreen.withOpacity(0.1),
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 80,
                    color: AppColors.primaryGreen.withOpacity(0.5),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDescriptionSection(String description) {
    final text = description.trim().isEmpty
        ? 'No description available.'
        : description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: Colors.grey[800],
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
          Icon(icon, size: 18, color: AppColors.primaryGreen),
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
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            if (isLoading)
              const ListRowsSkeleton(
                count: 3,
                padding: EdgeInsets.zero,
              )
            else if (error != null)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 48),
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
                  color: AppColors.surfaceLight,
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
                              color: AppColors.accentAmber,
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
          Icon(Icons.star, size: 14, color: AppColors.accentAmber),
          SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentAmber!),
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
                backgroundColor: AppColors.primaryGreen.withOpacity(0.2),
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'A',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
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
                            color: AppColors.primaryGreen,
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
                            color: AppColors.accentAmber,
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
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.shopping_bag,
                          color: AppColors.primaryGreen,
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
                              color: AppColors.primaryGreenDark,
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
    if (!await requireAuth(context)) return;

    setState(() {
      _isAddingToCart = true;
    });

    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
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
          context.read<BadgeProvider>().fetchBadges();
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

  /// Sets the cart line to the Buy Now quantity (update if present, add if not),
  /// then opens checkout with only that line.
  Future<void> _handleBuyNow(double price) async {
    if (_isBuyingNow || _isAddingToCart) return;
    if (!await requireAuth(context)) return;

    setState(() {
      _isBuyingNow = true;
    });

    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          setState(() {
            _isBuyingNow = false;
          });
        }
        return;
      }

      final cartService = CartService();
      final productIdStr = widget.productId.toString();

      // Fetch first so we set quantity instead of stacking via addToCart.
      var cartItems = await cartService.fetchCartItemsFromAPI(userId);
      Map<String, dynamic>? cartLine;
      for (final item in cartItems) {
        if (item['item_id']?.toString() == productIdStr) {
          cartLine = item;
          break;
        }
      }

      if (cartLine != null) {
        final result = await cartService.updateCart(
          cartItemId: cartLine['id'],
          quantity: _quantity,
        );
        if (!mounted) return;
        if (result['success'] != true) {
          SnackbarHelper.showError(
            context,
            result['message'] ?? 'Failed to prepare checkout',
          );
          return;
        }
        cartLine = Map<String, dynamic>.from(cartLine);
        cartLine['quantity'] = _quantity;
      } else {
        final result = await cartService.addToCart(
          userId: userId,
          itemId: productIdStr,
          price: price,
          quantity: _quantity,
        );
        if (!mounted) return;
        if (result['success'] != true) {
          SnackbarHelper.showError(
            context,
            result['message'] ?? 'Failed to prepare checkout',
          );
          return;
        }

        cartItems = await cartService.fetchCartItemsFromAPI(userId);
        for (final item in cartItems) {
          if (item['item_id']?.toString() == productIdStr) {
            cartLine = item;
            break;
          }
        }
      }

      if (!mounted) return;

      if (cartLine == null) {
        SnackbarHelper.showError(
          context,
          'Could not find item in cart for checkout',
        );
        return;
      }

      final product =
          Provider.of<ItemsProvider>(context, listen: false)
              .getItemById(widget.productId);

      final checkoutItem = <String, dynamic>{
        'id': cartLine['id'] is int
            ? cartLine['id']
            : int.tryParse(cartLine['id'].toString()) ?? cartLine['id'],
        'item_id': cartLine['item_id'] is int
            ? cartLine['item_id']
            : int.tryParse(cartLine['item_id'].toString()) ??
                cartLine['item_id'],
        'shop_id': cartLine['shop_id'] is int
            ? cartLine['shop_id']
            : int.tryParse(cartLine['shop_id'].toString()) ??
                cartLine['shop_id'],
        'shop_name': cartLine['shop_name'],
        'quantity': _quantity,
        'price_snapshot': cartLine['price_snapshot']?.toString() ??
            price.toStringAsFixed(2),
        'item_name': cartLine['item_name'] ?? product?['item_name'],
        'item_price': cartLine['item_price']?.toString() ??
            price.toStringAsFixed(2),
        'item_quantity': cartLine['item_quantity']?.toString() ??
            product?['item_quantity']?.toString(),
        if (product?['item_images'] != null)
          'item_images': product!['item_images'],
        if (cartLine['discounted_price'] != null)
          'discounted_price': cartLine['discounted_price'].toString(),
        if (cartLine['discount_status'] != null)
          'discount_status': cartLine['discount_status'],
        if (cartLine['discount_details'] != null)
          'discount_details': cartLine['discount_details'],
      };

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckOutScreen(
            selectedCartItems: [checkoutItem],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Error starting checkout: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBuyingNow = false;
        });
      }
    }
  }

  Widget _buildBottomActionBar(double price, bool inStock) {
    final actionsBusy = _isAddingToCart || _isBuyingNow;
    final canAct = inStock && !actionsBusy;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: (!actionsBusy && _quantity > 1)
                              ? () {
                                  setState(() {
                                    _quantity--;
                                  });
                                }
                              : null,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(20),
                          ),
                          child: SizedBox(
                            width: 40,
                            height: 36,
                            child: Icon(
                              Icons.remove,
                              size: 16,
                              color: (!actionsBusy && _quantity > 1)
                                  ? Colors.grey[700]
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: Colors.grey[300],
                        ),
                        SizedBox(
                          width: 44,
                          height: 36,
                          child: Center(
                            child: Text(
                              '$_quantity',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: Colors.grey[300],
                        ),
                        InkWell(
                          onTap: actionsBusy
                              ? null
                              : () {
                                  setState(() {
                                    _quantity++;
                                  });
                                },
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(20),
                          ),
                          child: SizedBox(
                            width: 40,
                            height: 36,
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: actionsBusy
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: canAct
                        ? AppColors.primaryGreen
                        : AppColors.primaryGreen.withOpacity(0.5),
                    child: InkWell(
                      onTap: canAct
                          ? () async {
                              await _handleAddToCart(price);
                            }
                          : null,
                      child: SizedBox(
                        height: 52,
                        child: Center(
                          child: _isAddingToCart
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Add to Crate',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Material(
                    color: canAct
                        ? AppColors.primaryGreenDark
                        : AppColors.primaryGreenDark.withOpacity(0.5),
                    child: InkWell(
                      onTap: canAct
                          ? () async {
                              await _handleBuyNow(price);
                            }
                          : null,
                      child: SizedBox(
                        height: 52,
                        child: Center(
                          child: _isBuyingNow
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Buy Now',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
