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
import '../../utils/manila_time.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/url.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'cartScreenV2.dart';
import 'checkOutScreen.dart';
import 'gamefowlListing.dart';
import 'InquiryChat.dart';
import 'GamefowlOrderReq.dart';


class gamefowlProdDetail extends StatefulWidget {
  final dynamic productId;
  final Map<String, dynamic>? productData;
  final dynamic shopId;
  final String? shopName;

  const gamefowlProdDetail({
    super.key,
    required this.productId,
    this.productData,
    this.shopId,
    this.shopName,
  });

  @override
  State<gamefowlProdDetail> createState() => _gamefowlProdDetailState();
}

class _gamefowlProdDetailState extends State<gamefowlProdDetail> {
  int _selectedImageIndex = 0;
  int _quantity = 1;
  bool _isFavorite = false;
  bool _showAllReviews = false;
  bool _isAddingToCart = false;
  bool _isBuyingNow = false;
  bool _isTogglingFavorite = false;
  String? _favoriteId;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final itemsProvider = Provider.of<ItemsProvider>(
        context,
        listen: false,
      );

      itemsProvider.fetchItemReviews(widget.productId);
      _checkFavoriteStatus();

      final product =
          widget.productData ?? itemsProvider.getItemById(widget.productId);

      final shopId = widget.shopId ?? _resolveShopId(product);

      _ensureShopLoaded(shopId);
    });

    _averageRating = 0.0;
  }

  dynamic _resolveShopId(Map<String, dynamic>? product) {
    if (widget.shopId != null &&
        widget.shopId.toString().trim().isNotEmpty) {
      return widget.shopId;
    }

    if (product == null) return null;

    for (final key in [
      'shop_id',
      'shopId',
      'shopID',
      'store_id',
      'storeId',
    ]) {
      final value = product[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value;
      }
    }

    for (final key in [
      'shop',
      'store',
      'shop_details',
      'shopDetails',
    ]) {
      final value = product[key];

      if (value is Map) {
        for (final idKey in [
          'id',
          'shop_id',
          'shopId',
          'store_id',
          'storeId',
        ]) {
          final id = value[idKey];

          if (id != null && id.toString().trim().isNotEmpty) {
            return id;
          }
        }
      }
    }

    return null;
  }

  String _getShopDisplayName() {
    if (widget.shopName?.trim().isNotEmpty == true) {
      return widget.shopName!.trim();
    }

    final value = _shopDetails?['shop_name'] ??
        _shopDetails?['shopName'] ??
        _shopDetails?['name'] ??
        _shopDetails?['store_name'] ??
        _shopDetails?['storeName'];

    final name = value?.toString().trim() ?? '';

    return name.isNotEmpty ? name : 'Gamefarm Davao';
  }

  Future<void> _ensureShopLoaded(dynamic shopId) async {
    if (shopId == null || shopId.toString().trim().isEmpty) return;

    if (_loadedShopId?.toString() == shopId.toString() &&
        _shopDetails != null) {
      return;
    }

    _loadedShopId = shopId;

    if (mounted) {
      setState(() => _isLoadingShop = true);
    }

    try {
      final shop = await _shopsService.fetchShopById(
        shopId.toString(),
      );

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
    if (product == null) return const [];

    final rawImages =
        product['item_images'] ??
        product['images'] ??
        product['image_urls'];

    final urls = <String>[];

    if (rawImages is List) {
      for (final entry in rawImages) {
        String? raw;

        if (entry is Map) {
          raw = entry['url']?.toString() ??
              entry['image_url']?.toString() ??
              entry['path']?.toString() ??
              entry['item_image']?.toString() ??
              entry['image']?.toString();
        } else {
          raw = entry?.toString();
        }

        final resolved = _resolveMediaUrl(raw);

        if (resolved != null) {
          urls.add(resolved);
        }
      }
    }

    if (urls.isEmpty) {
      final singleImage =
          product['image_url'] ??
          product['image'] ??
          product['product_image'] ??
          product['item_image'] ??
          product['photo'] ??
          product['thumbnail'];

      if (singleImage is String && singleImage.trim().isNotEmpty) {
        final resolved = _resolveMediaUrl(singleImage);

        if (resolved != null) {
          urls.add(resolved);
        }
      }
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

    final baseUrl = Url.getUrl().replaceAll(
      RegExp(r'/+$'),
      '',
    );

    final normalized = path.startsWith('/') ? path : '/$path';

    return '$baseUrl$normalized';
  }

  // UPDATED: Find the shop profile image using common API field names.
  String? _getShopProfileImage() {
    final shop = _shopDetails;

    if (shop == null) return null;

    // Some APIs return shop details inside a nested object.
    final nestedShop = shop['shop'] ??
        shop['store'] ??
        shop['shop_details'] ??
        shop['shopDetails'];

    final Map<dynamic, dynamic> imageSource =
        nestedShop is Map ? nestedShop : shop;

    final possibleKeys = [
      'shop_profile',
      'shop_profile_image',
      'shop_profile_picture',
      'shop_profile_photo',
      'shop_image',
      'shop_image_url',
      'shop_logo',
      'shop_logo_url',
      'profile_image',
      'profile_image_url',
      'profile_picture',
      'profile_picture_url',
      'profile_photo',
      'avatar',
      'avatar_url',
      'image',
      'image_url',
      'logo',
      'logo_url',
      'picture',
      'photo',
    ];

    for (final key in possibleKeys) {
      final value = imageSource[key];

      if (value is String && value.trim().isNotEmpty) {
        final resolved = _resolveMediaUrl(value);

        if (resolved != null) {
          return resolved;
        }
      }

      if (value is Map) {
        final nestedValue = value['url'] ??
            value['path'] ??
            value['image_url'] ??
            value['file_path'] ??
            value['image'] ??
            value['src'];

        if (nestedValue is String && nestedValue.trim().isNotEmpty) {
          final resolved = _resolveMediaUrl(nestedValue);

          if (resolved != null) {
            return resolved;
          }
        }
      }

      if (value is List && value.isNotEmpty) {
        final first = value.first;

        if (first is String && first.trim().isNotEmpty) {
          final resolved = _resolveMediaUrl(first);

          if (resolved != null) {
            return resolved;
          }
        }

        if (first is Map) {
          final nestedValue = first['url'] ??
              first['path'] ??
              first['image_url'] ??
              first['file_path'] ??
              first['image'];

          if (nestedValue is String &&
              nestedValue.trim().isNotEmpty) {
            final resolved = _resolveMediaUrl(nestedValue);

            if (resolved != null) {
              return resolved;
            }
          }
        }
      }
    }

    return null;
  }

  // UPDATED: Display the actual shop profile picture.
  // A storefront icon is shown only when there is no usable image.
  Widget _buildShopAvatar() {
    final imageUrl = _getShopProfileImage();

    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFFE9EAEE),
        shape: BoxShape.circle,
      ),
      child: imageUrl == null
          ? const Icon(
              Icons.storefront,
              size: 28,
              color: Color(0xFFB7B9C0),
            )
          : Image.network(
              imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.storefront,
                    size: 28,
                    color: Color(0xFFB7B9C0),
                  ),
                );
              },
            ),
    );
  }

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
        final favorites =
            await _favoriteService.fetchFavoritesFromAPI(userId);

        final favorite = favorites.firstWhere(
          (fav) =>
              fav['item_id'].toString() == widget.productId.toString(),
          orElse: () => {},
        );

        if (favorite.isNotEmpty && mounted) {
          setState(() {
            _isFavorite = true;
            _favoriteId = favorite['id'].toString();
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite) return;

    if (!await requireAuth(context)) return;

    if (!mounted) return;

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      final userId = await ApiService.getUserId();

      if (userId == null || userId.isEmpty) {
        if (mounted) {
          setState(() {
            _isTogglingFavorite = false;
          });
        }
        return;
      }

      if (_isFavorite) {
        if (_favoriteId == null) {
          final favorites =
              await _favoriteService.fetchFavoritesFromAPI(userId);

          final favorite = favorites.firstWhere(
            (fav) =>
                fav['item_id'].toString() == widget.productId.toString(),
            orElse: () => {},
          );

          if (favorite.isEmpty) {
            if (mounted) {
              setState(() {
                _isFavorite = false;
                _isTogglingFavorite = false;
              });
            }
            return;
          }

          _favoriteId = favorite['id'].toString();
        }

        final result =
            await _favoriteService.removeFromFavorites(_favoriteId!);

        if (mounted) {
          if (result['success'] == true) {
            setState(() {
              _isFavorite = false;
              _favoriteId = null;
            });

            SnackbarHelper.showSuccess(
              context,
              result['message'] ?? 'Removed from favorites',
              duration: const Duration(seconds: 1),
            );
          } else {
            SnackbarHelper.showError(
              context,
              result['message'] ?? 'Failed to remove from favorites',
            );
          }
        }
      } else {
        final result = await _favoriteService.addToFavorites(
          userId: userId,
          itemId: widget.productId.toString(),
        );

        if (mounted) {
          if (result['success'] == true) {
            final favorites =
                await _favoriteService.fetchFavoritesFromAPI(userId);

            final favorite = favorites.firstWhere(
              (fav) =>
                  fav['item_id'].toString() == widget.productId.toString(),
              orElse: () => {},
            );

            if (!mounted) return;

            setState(() {
              _isFavorite = true;

              if (favorite.isNotEmpty) {
                _favoriteId = favorite['id'].toString();
              }
            });

            SnackbarHelper.showSuccess(
              context,
              result['message'] ?? 'Added to favorites',
              duration: const Duration(seconds: 1),
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

  double _parsePrice(dynamic price) {
    if (price == null) return 0.0;

    if (price is num) {
      return price.toDouble();
    }

    if (price is String) {
      final parsed = double.tryParse(price);
      return parsed ?? 0.0;
    }

    return 299.99;
  }

  double _parseRating(dynamic rating) {
    if (rating == null) return 0.0;

    if (rating is num) {
      return rating.toDouble();
    }

    if (rating is String) {
      final parsed = double.tryParse(rating);
      return parsed ?? 0.0;
    }

    return 0.0;
  }

  int _parseStock(dynamic stock) {
    if (stock == null) return 50;

    if (stock is num) {
      return stock.toInt();
    }

    if (stock is String) {
      final parsed = int.tryParse(stock);
      return parsed ?? 50;
    }

    return 50;
  }

  double _getAverage() {
    final reviews = Provider.of<ItemsProvider>(
      context,
      listen: false,
    ).getReviewsList(widget.productId);

    if (reviews.isEmpty) return 0.0;

    final totalRating = reviews.fold<double>(
      0.0,
      (sum, review) =>
          sum + ((review['rating'] as num?)?.toDouble() ?? 0.0),
    );

    return totalRating / reviews.length;
  }

  String _formatDisplayPrice(double price) {
    if (price == price.roundToDouble()) {
      return '₱${price.toStringAsFixed(0)}';
    }

    return '₱${price.toStringAsFixed(2)}';
  }

  String _resolveCategoryName(
    BuildContext context,
    Map<String, dynamic>? product,
  ) {
    final raw = (product?['category'] ?? '').toString().trim();

    if (raw.isEmpty) return '';

    final categories = Provider.of<CategoryProvider>(
      context,
      listen: false,
    ).categories;

    for (final category in categories) {
      if (category['id']?.toString() == raw) {
        return (category['name'] ?? '').toString();
      }
    }

    for (final category in categories) {
      final name = (category['name'] ?? '').toString();

      if (name.toLowerCase() == raw.toLowerCase()) {
        return name;
      }
    }

    return int.tryParse(raw) != null ? '' : raw;
  }

  List<String> _resolveVariants(Map<String, dynamic>? product) {
    if (product == null) return const [];

    final raw = product['variations'] ??
        product['variants'] ??
        product['options'] ??
        product['sizes'];

    if (raw is! List || raw.isEmpty) {
      return const [];
    }

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

        if (label != null && label.isNotEmpty) {
          labels.add(label);
        }
      }
    }

    return labels;
  }

  int _parseSoldCount(dynamic sold) {
    if (sold is num) return sold.toInt();

    return int.tryParse(sold?.toString() ?? '') ?? 0;
  }

  String _firstNonEmptyValue(
    Map<String, dynamic>? product,
    List<String> keys,
    String fallback,
  ) {
    if (product == null) return fallback;

    for (final key in keys) {
      final value = product[key]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    return fallback;
  }

  String _resolveGamefowlType(Map<String, dynamic>? product) {
    return _firstNonEmptyValue(
      product,
      [
        'gamefowl_type',
        'fowl_type',
        'breed_type',
        'type',
        'category_name',
      ],
      'One way / Pure',
    );
  }

  String _resolveGamefowlName(Map<String, dynamic>? product) {
    return _firstNonEmptyValue(
      product,
      [
        'item_name',
        'product_name',
        'name',
        'title',
      ],
      'Gamefowl',
    );
  }

  String _resolveGamefowlAge(Map<String, dynamic>? product) {
    if (product == null) return '';

    for (final key in [
      'age',
      'gamefowl_age',
      'fowl_age',
    ]) {
      final value = product[key]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final itemsProvider = Provider.of<ItemsProvider>(context);

    final product =
        widget.productData ?? itemsProvider.getItemById(widget.productId);

    final gamefowlName = _resolveGamefowlName(product);
    final gamefowlType = _resolveGamefowlType(product);
    final gamefowlAge = _resolveGamefowlAge(product);
    final productName = gamefowlName;

    final productPrice = _parsePrice(
      product?['item_price'] ??
          product?['price'] ??
          product?['selling_price'] ??
          product?['product_price'] ??
          product?['amount'],
    );

    final productDescription = (
      product?['item_description'] ??
          product?['description'] ??
          product?['product_description'] ??
          ''
    ).toString();

    final productStock = _parseStock(
      product?['item_quantity'] ??
          product?['quantity'] ??
          product?['stock'],
    );

    final images = _resolveProductImages(product);

    final soldCount = _parseSoldCount(
      product?['sold_count'] ??
          product?['sold'] ??
          product?['sales_count'],
    );

    final shopId = widget.shopId ?? _resolveShopId(product);

    if (shopId != null &&
        _loadedShopId?.toString() != shopId.toString() &&
        !_isLoadingShop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureShopLoaded(shopId);
        }
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
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageCarousel(images),
                      if (images.length > 1)
                        _buildCarouselIndicators(images.length),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          32,
                          12,
                          32,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatDisplayPrice(productPrice),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF171717),
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    '/per head',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF777777),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _isTogglingFavorite
                                      ? null
                                      : _toggleFavorite,
                                  child: _isTogglingFavorite
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFB8BAC0),
                                          ),
                                        )
                                      : Icon(
                                          _isFavorite
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 20,
                                          color: _isFavorite
                                              ? AppColors.error
                                              : const Color(0xFFB8BAC0),
                                        ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '$soldCount sold',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF9A9A9A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              productName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF202020),
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              [
                                gamefowlType,
                                if (gamefowlAge.isNotEmpty) gamefowlAge,
                              ].join(' | '),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF3155B7),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildDescriptionSection(productDescription),
                            const SizedBox(height: 20),
                            _buildShopCard(
                              shopId: shopId,
                              shopName: _getShopDisplayName(),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: productStock > 0 && !_isBuyingNow
                                    ? () => _handleInquiry(shopId)
                                    : null,
                                icon: const Icon(Icons.help, size: 18),
                                label: const Text('Inquire'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF29479A),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xFF29479A).withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
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
          _buildBottomActionBar(
            productPrice,
            productStock > 0,
            shopId,
          ),
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
        padding: EdgeInsets.fromLTRB(
          12,
          top + 8,
          12,
          8,
        ),
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
                            constraints: const BoxConstraints(
                              minWidth: 16,
                            ),
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
                Icon(
                  icon,
                  size: 20,
                  color: Colors.grey[800],
                ),
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
                  ? AppColors.brandPrimary
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
            setState(() {
              _selectedVariantIndex = index;
            });
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
                      ? AppColors.brandPrimaryDark
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.brandPrimaryDark
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
                      setState(() {
                        _selectedVariantIndex = -1;
                      });
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
    final address = (
      _shopDetails?['shop_address'] ??
          _shopDetails?['address'] ??
          _shopDetails?['store_address'] ??
          ''
    ).toString().trim();

    final contact = (
      _shopDetails?['contact_number'] ??
          _shopDetails?['phone'] ??
          _shopDetails?['phone_number'] ??
          _shopDetails?['mobile_number'] ??
          ''
    ).toString().trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (shopId == null || shopId.toString().trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Shop information is unavailable.'),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => gamefowlListing(
                shopId: widget.shopId ?? shopId,
                shopName: shopName,
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E5E5),
            ),
          ),
          child: Row(
            children: [
              // UPDATED: Real shop profile image instead of Icons.pets.
              _buildShopAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF30313A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: Color(0xFF3155B7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Color(0xFF8C8F98),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address.isNotEmpty ? address : 'Address',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8C8F98),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: Color(0xFF8C8F98),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            contact.isNotEmpty ? contact : 'Contact Info',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8C8F98),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF0F0F1),
                ),
                child: const Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: Color(0xFFA5A6AB),
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
      height: MediaQuery.of(context).size.width * 0.70,
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
              color: AppColors.brandPrimary.withOpacity(0.1),
              child: Center(
                child: Icon(
                  Icons.image,
                  size: 100,
                  color: AppColors.brandPrimary.withOpacity(0.5),
                ),
              ),
            );
          }

          return Image.network(
            images[index],
            fit: BoxFit.cover,
            width: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return Container(
                color: AppColors.brandPrimary.withOpacity(0.08),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
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
                color: AppColors.brandPrimary.withOpacity(0.1),
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 80,
                    color: AppColors.brandPrimary.withOpacity(0.5),
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
            fontSize: 18,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(width: 12),
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
        final reviewsData =
            itemsProvider.getItemReviews(widget.productId);

        final isLoading =
            itemsProvider.isReviewsLoading(widget.productId);

        final error =
            itemsProvider.getReviewsError(widget.productId);

        final reviews =
            itemsProvider.getReviewsList(widget.productId);

        double averageRating = 0.0;

        if (reviews.isNotEmpty) {
          final totalRating = reviews.fold<double>(
            0.0,
            (sum, review) =>
                sum + ((review['rating'] as num?)?.toDouble() ?? 0.0),
          );

          averageRating = totalRating / reviews.length;
        } else if (reviewsData != null &&
            reviewsData['average_rating'] != null) {
          averageRating = _parseRating(
            reviewsData['average_rating'],
          );
        }

        final totalReviews = reviews.length;

        final ratingCounts = Map<int, int>.from({
          5: 0,
          4: 0,
          3: 0,
          2: 0,
          1: 0,
        });

        for (final review in reviews) {
          final rating = (review['rating'] as num?)?.toInt() ?? 0;

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
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const ListRowsSkeleton(
                count: 3,
                padding: EdgeInsets.zero,
              )
            else if (error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load reviews',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          itemsProvider.fetchItemReviews(
                            widget.productId,
                          );
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (reviews.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[200]!,
                  ),
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
                        const SizedBox(height: 4),
                        Text(
                          '$totalReviews reviews',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRatingBar(
                            5,
                            ratingCounts[5] ?? 0,
                            reviews.length,
                          ),
                          _buildRatingBar(
                            4,
                            ratingCounts[4] ?? 0,
                            reviews.length,
                          ),
                          _buildRatingBar(
                            3,
                            ratingCounts[3] ?? 0,
                            reviews.length,
                          ),
                          _buildRatingBar(
                            2,
                            ratingCounts[2] ?? 0,
                            reviews.length,
                          ),
                          _buildRatingBar(
                            1,
                            ratingCounts[1] ?? 0,
                            reviews.length,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...(_showAllReviews || reviews.length <= 3
                  ? reviews.map((review) => _buildReviewCard(review))
                  : reviews
                      .take(3)
                      .map((review) => _buildReviewCard(review))),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final percentage = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$stars',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.star,
            size: 14,
            color: AppColors.accentAmber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.accentAmber!,
                ),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    String formattedDate = '';

    if (review['created_at'] != null) {
      try {
        final dateTime = ManilaTime.fromUtc(
          ManilaTime.parseUtc(review['created_at']),
        );

        formattedDate =
            '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      } catch (e) {
        formattedDate = review['created_at'].toString();
      }
    }

    final username = (review['username'] ?? 'Anonymous').toString();
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = (review['comment'] ?? '').toString();

    final verified =
        review['verified'] == true || review['verified'] == 'true';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppColors.brandPrimary.withOpacity(0.2),
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'A',
                  style: TextStyle(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            username,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: AppColors.success,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
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
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              formattedDate,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
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
            const SizedBox(height: 12),
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
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.shopping_bag,
                          color: AppColors.brandPrimary,
                          size: 40,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
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
                          const SizedBox(height: 4),
                          Text(
                            '₱${(199.99 + index * 50).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandPrimaryDark,
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

  /// Resolves the catalog item ID used by the cart API.
  /// The generic `id` is only considered from a product record, never from a cart line.
  int? _getCartItemId() {
    Map<String, dynamic>? product = widget.productData;
    product ??= Provider.of<ItemsProvider>(
      context,
      listen: false,
    ).getItemById(widget.productId);
    if (product == null) return null;

    int? parsePositive(dynamic value) {
      if (value == null) return null;
      final parsed = value is num
          ? value.toInt()
          : int.tryParse(value.toString().trim());
      return parsed != null && parsed > 0 ? parsed : null;
    }

    final item = product['item'] is Map
        ? Map<String, dynamic>.from(product['item'] as Map)
        : <String, dynamic>{};
    final nestedProduct = product['product'] is Map
        ? Map<String, dynamic>.from(product['product'] as Map)
        : <String, dynamic>{};

    final candidates = <dynamic>[
      product['item_id'],
      product['product_item_id'],
      product['catalog_item_id'],
      item['item_id'],
      item['id'],
      nestedProduct['item_id'],
      nestedProduct['id'],
    ];

    for (final candidate in candidates) {
      final id = parsePositive(candidate);
      if (id != null) return id;
    }

    // The detail page's productId is the lookup key passed to ItemsProvider.
    // Use it only after confirming a product record was resolved.
    final resolvedLookupId = parsePositive(widget.productId);
    if (resolvedLookupId != null) return resolvedLookupId;

    // Last resort: some item endpoints serialize the database item primary key as `id`.
    // Avoid IDs that explicitly identify a cart row or a listing wrapper.
    final looksLikeProduct = product.containsKey('item_name') ||
        product.containsKey('item_price') ||
        product.containsKey('product_name') ||
        product.containsKey('selling_price');
    if (looksLikeProduct &&
        !product.containsKey('cart_item_id') &&
        !product.containsKey('cart_id') &&
        !product.containsKey('listing_id')) {
      return parsePositive(product['id']);
    }
    return null;
  }

  void _showInvalidItemIdMessage() {
    if (!mounted) return;
    SnackbarHelper.showError(
      context,
      'This gamefowl listing has no valid item ID. Please refresh the listing or check the product data.',
    );
  }

  Future<Map<String, dynamic>?> _findCartLine(
    CartService cartService,
    String userId,
    int itemId,
  ) async {
    final items = await cartService.fetchCartItemsFromAPI(userId);
    for (final item in items) {
      if (item['item_id']?.toString() == itemId.toString()) {
        return item;
      }
    }
    return null;
  }

  Future<void> _handleAddToCart(double price) async {
    if (_isAddingToCart || _isBuyingNow) return;
    if (!await requireAuth(context)) return;

    final itemId = _getCartItemId();
    if (itemId == null) {
      _showInvalidItemIdMessage();
      return;
    }
    if (price <= 0) {
      SnackbarHelper.showError(context, 'This gamefowl has an invalid price.');
      return;
    }

    setState(() => _isAddingToCart = true);
    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Please login again to use your cart.');
        }
        return;
      }

      final cartService = CartService();
      final existingLine = await _findCartLine(cartService, userId, itemId);
      if (existingLine != null) {
        final lineId = existingLine['cart_item_id'] ?? existingLine['id'];
        if (lineId != null) {
          final update = await cartService.updateCart(
            cartItemId: lineId,
            quantity: _quantity,
          );
          if (update['success'] != true) {
            if (mounted) {
              SnackbarHelper.showError(
                context,
                update['message']?.toString() ?? 'Could not update the item in your crate.',
              );
            }
            return;
          }
        }
        if (mounted) {
          context.read<BadgeProvider>().fetchBadges();
          SnackbarHelper.showSuccess(
            context,
            'This gamefowl is already in your crate.',
            duration: const Duration(seconds: 2),
          );
        }
        return;
      }

      final result = await cartService.addToCart(
        userId: userId,
        itemId: itemId.toString(),
        price: price,
        quantity: _quantity,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        context.read<BadgeProvider>().fetchBadges();
        SnackbarHelper.showSuccess(
          context,
          result['message']?.toString() ?? 'Added $_quantity item(s) to crate.',
          duration: const Duration(seconds: 2),
        );
      } else {
        SnackbarHelper.showError(
          context,
          result['message']?.toString() ?? 'Failed to add gamefowl to crate.',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error adding to crate: $e');
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  Future<void> _handleBuyNow(double price) async {
    if (_isBuyingNow || _isAddingToCart) {
      return;
    }

    if (!await requireAuth(context)) {
      return;
    }

    final itemId = _getCartItemId();

    if (itemId == null) {
      _showInvalidItemIdMessage();
      return;
    }

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
      final productIdStr = itemId.toString();

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

      final nestedCart = cartLine['cart'] is Map
          ? Map<String, dynamic>.from(cartLine['cart'] as Map)
          : <String, dynamic>{};
      final rawCartId = cartLine['cart_id'] ??
          cartLine['cartId'] ??
          nestedCart['id'] ??
          nestedCart['cart_id'];
      final checkoutCartId = int.tryParse(rawCartId?.toString() ?? '');

      if (checkoutCartId == null) {
        SnackbarHelper.showError(
          context,
          'The cart API did not return a valid parent cart ID. Please refresh your cart and try again.',
        );
        return;
      }
      final product = Provider.of<ItemsProvider>(
        context,
        listen: false,
      ).getItemById(widget.productId);

      final checkoutItem = <String, dynamic>{
        'cart_id': checkoutCartId,
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
            cartId: checkoutCartId,
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

  Future<void> _showOrderRequestConfirmation(dynamic shopId) async {
    if (_isAddingToCart || _isBuyingNow) return;

    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                heightFactor: 0.65,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFD6D6D6),
                    fixedSize: const Size(30, 30),
                  ),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF9AA9D7)),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF9AA9D7),
                  size: 32,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ready to Order?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Have you already inquired with the seller and confirmed the details of your chosen gamefowl?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF444444)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0E0E0),
                          foregroundColor: const Color(0xFF777777),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('No'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C66B3),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Yes'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice) {
      await _handleOrderRequest(shopId);
    } else {
      await _handleInquiry(shopId);
    }
  }

  Future<void> _handleOrderRequest(dynamic shopId) async {
    if (_isAddingToCart || _isBuyingNow) return;
    if (!await requireAuth(context)) return;

    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
    final requestProduct =
        widget.productData ?? itemsProvider.getItemById(widget.productId);
    final itemId = _getCartItemId();
    final price = _parsePrice(
      requestProduct?['item_price'] ??
          requestProduct?['price'] ??
          requestProduct?['selling_price'] ??
          requestProduct?['product_price'],
    );
    final resolvedShopId = shopId ?? _resolveShopId(requestProduct);

    if (requestProduct == null || itemId == null) {
      _showInvalidItemIdMessage();
      return;
    }
    if (resolvedShopId == null || resolvedShopId.toString().trim().isEmpty) {
      SnackbarHelper.showError(context, 'This gamefowl has no valid shop ID.');
      return;
    }
    if (price <= 0) {
      SnackbarHelper.showError(context, 'This gamefowl has an invalid price.');
      return;
    }

    setState(() => _isBuyingNow = true);
    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Please login again to continue.');
        }
        return;
      }

      final cartService = CartService();
      var cartLine = await _findCartLine(cartService, userId, itemId);
      if (cartLine == null) {
        final addResult = await cartService.addToCart(
          userId: userId,
          itemId: itemId.toString(),
          price: price,
          quantity: _quantity,
        );
        if (addResult['success'] != true) {
          if (mounted) {
            SnackbarHelper.showError(
              context,
              addResult['message']?.toString() ?? 'Could not add gamefowl to crate.',
            );
          }
          return;
        }
        cartLine = await _findCartLine(cartService, userId, itemId);
      }
      if (cartLine == null) {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            'The gamefowl was added, but could not be found in your crate. Please refresh and try again.',
          );
        }
        return;
      }

      if (!mounted) return;
      context.read<BadgeProvider>().fetchBadges();
      final normalizedProduct = Map<String, dynamic>.from(requestProduct)
        ..['item_id'] = itemId
        ..['shop_id'] = resolvedShopId
        ..putIfAbsent('item_price', () => price);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GamefowlOrderReq(
            productData: normalizedProduct,
            shopName: _getShopDisplayName(),
            shopId: resolvedShopId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Unable to open order request: $e');
      }
    } finally {
      if (mounted) setState(() => _isBuyingNow = false);
    }
  }

  Future<void> _handleInquiry(dynamic shopId) async {
    if (!await requireAuth(context)) {
      return;
    }

    final itemsProvider =
        Provider.of<ItemsProvider>(context, listen: false);

    final inquiryProduct =
        widget.productData ?? itemsProvider.getItemById(widget.productId);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InquiryChat(
          shopId: shopId,
          shopName: _getShopDisplayName(),
          productData: inquiryProduct,
        ),
      ),
    );

    if (!mounted) return;

  }

  Widget _buildBottomActionBar(
    double price,
    bool inStock,
    dynamic shopId,
  ) {
    final actionsBusy = _isAddingToCart || _isBuyingNow;
    final canAct = inStock && !actionsBusy;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: canAct
                    ? const Color(0xFF4C66B3)
                    : const Color(0xFF4C66B3).withOpacity(0.5),
                child: InkWell(
                  onTap: canAct ? () => _handleAddToCart(price) : null,
                  child: const SizedBox(
                    height: 52,
                    child: Center(
                      child: Text(
                        'Add to Crate',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
                    ? const Color(0xFF29479A)
                    : const Color(0xFF29479A).withOpacity(0.5),
                child: InkWell(
                  onTap: canAct
                      ? () => _showOrderRequestConfirmation(shopId)
                      : null,
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: _isBuyingNow
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Order Request',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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
      ),
    );
  }
}