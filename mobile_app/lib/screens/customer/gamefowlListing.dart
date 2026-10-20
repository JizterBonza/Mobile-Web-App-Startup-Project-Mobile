import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/constants.dart';
import '../../provider/provider.dart';
import '../../utils/gamefowl_item.dart';
import '../../utils/manila_time.dart';
import '../../utils/url.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'gamefowlProdDetail.dart';

class gamefowlListing extends StatefulWidget {
  final dynamic shopId;
  final String? shopName;

  // Image of the selected Local Farm.
  final String? shopImage;

  const gamefowlListing({
    super.key,
    required this.shopId,
    this.shopName,
    this.shopImage,
  });

  @override
  State<gamefowlListing> createState() => _gamefowlListingState();
}

class _gamefowlListingState extends State<gamefowlListing> {
  bool _isLoading = true;
  Map<String, dynamic>? _shopDetails;
  List<Map<String, dynamic>> _shopItems = [];
  String? _error;

  int _selectedTab = 0;
  dynamic _selectedCategoryId;

  String _selectedGamefowlType = 'All';

  bool _showAllBestSeller = false;
  bool _showAllPopular = false;

  final List<String> _gamefowlTypes = [
    'All',
    'One way / Pure',
    'Two-way cross',
    'Three-way cross',
    'Four-way cross',
    'Multiple cross / Unknown',
    'Bundles',
  ];

  List<Map<String, dynamic>> get _filteredShopItems {
    final categories = context.read<CategoryProvider>().categories;
    if (categories.isEmpty) return [];
    List<Map<String, dynamic>> items =
        _shopItems.where((item) => isGamefowlItem(
              item,
              categories: categories,
            )).toList();

    if (_selectedCategoryId != null) {
      final categories = Provider.of<CategoryProvider>(
        context,
        listen: false,
      ).categories;

      Map<String, dynamic>? selectedCategory;

      for (final category in categories) {
        if (category['id']?.toString() == _selectedCategoryId?.toString()) {
          selectedCategory = category;
          break;
        }
      }

      if (selectedCategory != null) {
        items = items
            .where(
              (item) => itemMatchesCategory(
                item,
                selectedCategory!,
              ),
            )
            .toList();
      }
    }

    if (_selectedGamefowlType != 'All') {
      items = items.where((item) {
        return _matchesSelectedGamefowlType(item);
      }).toList();
    }

    return items;
  }

  bool _matchesSelectedGamefowlType(
    Map<String, dynamic> item,
  ) {
    final selected =
        _selectedGamefowlType.toLowerCase().trim();

    final type =
        _getGamefowlType(item).toLowerCase().trim();

    final productName =
        _getProductName(item).toLowerCase().trim();

    final categoryName = (
      item['category_name'] ??
      item['category'] ??
      ''
    ).toString().toLowerCase().trim();

    final combined =
        '$type $productName $categoryName';

    if (selected == 'one way / pure') {
      return type.contains('one way') ||
          type.contains('one-way') ||
          type.contains('pure') ||
          combined.contains('one way') ||
          combined.contains('one-way') ||
          combined.contains('pure');
    }

    if (selected == 'two-way cross') {
      return type.contains('two-way') ||
          type.contains('two way') ||
          type.contains('2-way') ||
          combined.contains('two-way') ||
          combined.contains('two way') ||
          combined.contains('2-way');
    }

    if (selected == 'three-way cross') {
      return type.contains('three-way') ||
          type.contains('three way') ||
          type.contains('3-way') ||
          combined.contains('three-way') ||
          combined.contains('three way') ||
          combined.contains('3-way');
    }

    if (selected == 'four-way cross') {
      return type.contains('four-way') ||
          type.contains('four way') ||
          type.contains('4-way') ||
          combined.contains('four-way') ||
          combined.contains('four way') ||
          combined.contains('4-way');
    }

    if (selected == 'multiple cross / unknown') {
      final isMultipleCross =
          type.contains('multiple') ||
          type.contains('multi') ||
          combined.contains('multiple cross') ||
          combined.contains('multiple-cross') ||
          combined.contains('multi cross');

      final isUnknown =
          type.isEmpty ||
          type.contains('unknown') ||
          categoryName.contains('unknown');

      return isMultipleCross || isUnknown;
    }

    if (selected == 'bundles') {
      return type.contains('bundle') ||
          productName.contains('bundle') ||
          categoryName.contains('bundle') ||
          combined.contains('bundle');
    }

    return type.isNotEmpty &&
        (type.contains(selected) || selected.contains(type));
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShopData();
    });
  }

  Future<void> _loadShopData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final shopsProvider =
          Provider.of<ShopsProvider>(
        context,
        listen: false,
      );

      final categoryProvider =
          Provider.of<CategoryProvider>(
        context,
        listen: false,
      );

      await Future.wait([
        shopsProvider.fetchShopDetails(
          widget.shopId,
        ),
        shopsProvider.fetchShopItems(
          widget.shopId,
        ),
        shopsProvider.fetchShopReviews(
          widget.shopId,
        ),
        categoryProvider.fetchCategories(),
      ]);

      final shopData =
          shopsProvider.getShopDetails(
        widget.shopId,
      );

      final items = shopsProvider.getShopItems(widget.shopId);

      if (mounted) {
        setState(() {
          _shopDetails = shopData;
          _shopItems = List<Map<String, dynamic>>.from(items);
          _isLoading = false;
          _error =
              shopsProvider.getDetailsError(
                    widget.shopId,
                  ) ??
                  shopsProvider.getItemsError(
                    widget.shopId,
                  );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  String _formatOperatingHours(
    String hours,
  ) {
    final match = RegExp(
      r'(\d{1,2}):(\d{2})\s*[-–]\s*(\d{1,2}):(\d{2})',
    ).firstMatch(hours);

    if (match == null) return hours;

    String formatPart(
      String hour,
      String minute,
    ) {
      final h = int.tryParse(hour) ?? 0;
      final period = h >= 12 ? 'PM' : 'AM';
      final displayHour =
          h % 12 == 0 ? 12 : h % 12;

      return '$displayHour:${minute.padLeft(2, '0')} $period';
    }

    return '${formatPart(match.group(1)!, match.group(2)!)} - '
        '${formatPart(match.group(3)!, match.group(4)!)}';
  }

  String _formatRating(dynamic rating) {
    if (rating == null) return '0.0';

    try {
      if (rating is num) {
        return rating.toStringAsFixed(1);
      }

      if (rating is String) {
        final parsed =
            double.tryParse(rating);

        return parsed != null
            ? parsed.toStringAsFixed(1)
            : '0.0';
      }
    } catch (_) {}

    return '0.0';
  }

  PageRoute _createFadeRoute(
    Widget page,
  ) {
    return PageRouteBuilder(
      pageBuilder: (
        context,
        animation,
        secondaryAnimation,
      ) =>
          page,
      transitionsBuilder: (
        context,
        animation,
        secondaryAnimation,
        child,
      ) {
        final curvedAnimation =
            CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.98,
              end: 1.0,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      transitionDuration:
          const Duration(milliseconds: 150),
      reverseTransitionDuration:
          const Duration(milliseconds: 150),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.surfaceLight,
      body: _isLoading
          ? SafeArea(
              child: _buildLoadingState(),
            )
          : _error != null
              ? SafeArea(
                  child: _buildErrorState(),
                )
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadShopData,
                      color:
                          AppColors.brandPrimary,
                      child:
                          SingleChildScrollView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _buildShopHeader(),

                            const SizedBox(
                              height: 14,
                            ),

                            _buildTabBar(),

                            AnimatedSwitcher(
                              duration:
                                  const Duration(
                                milliseconds: 250,
                              ),
                              switchInCurve:
                                  Curves.easeOutCubic,
                              switchOutCurve:
                                  Curves.easeInCubic,
                              transitionBuilder:
                                  (
                                    child,
                                    animation,
                                  ) {
                                return FadeTransition(
                                  opacity:
                                      animation,
                                  child:
                                      SlideTransition(
                                    position:
                                        Tween<Offset>(
                                      begin:
                                          const Offset(
                                        0.04,
                                        0,
                                      ),
                                      end:
                                          Offset.zero,
                                    ).animate(
                                      animation,
                                    ),
                                    child:
                                        child,
                                  ),
                                );
                              },
                              layoutBuilder: (
                                currentChild,
                                previousChildren,
                              ) {
                                return Stack(
                                  alignment:
                                      Alignment.topCenter,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild !=
                                        null)
                                      currentChild,
                                  ],
                                );
                              },
                              child:
                                  KeyedSubtree(
                                key:
                                    ValueKey<int>(
                                  _selectedTab,
                                ),
                                child:
                                    _selectedTab ==
                                            0
                                        ? _buildGamefowlListing()
                                        : _buildReviewsPreview(),
                              ),
                            ),

                            const SizedBox(
                              height: 30,
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildTopControls(),
                  ],
                ),
    );
  }

  Widget _buildTabBar() {
    final rating =
        _shopDetails?['shop_rating'];

    return Container(
      color: AppColors.surfaceLight,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              label: 'Gamefowl',
              isActive: _selectedTab == 0,
              onTap: () {
                setState(() {
                  _selectedTab = 0;
                });
              },
            ),
          ),
          Expanded(
            child: _buildTab(
              label: 'Reviews',
              isActive: _selectedTab == 1,
              onTap: () {
                setState(() {
                  _selectedTab = 1;
                });
              },
              trailing: rating != null
                  ? Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 15,
                          color:
                              AppColors.accentAmber,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatRating(
                            rating,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                Colors.grey[700],
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior:
          HitTestBehavior.opaque,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white
              : AppColors.surfaceLight,
          borderRadius:
              const BorderRadius.vertical(
            top: Radius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: isActive
                    ? Colors.grey[900]
                    : Colors.grey[600],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 5),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  // ================================================================
  // GAMEFOWL LISTING
  // ================================================================

  Widget _buildGamefowlListing() {
  final List<Map<String, dynamic>> displayItems =
    _filteredShopItems;

    final bestSellerItems =
        displayItems.take(8).toList();

    final popularItems =
        bestSellerItems.toList();

    final visibleBestSeller =
        _showAllBestSeller
            ? bestSellerItems
            : bestSellerItems.take(6).toList();

    final visiblePopular =
        _showAllPopular
            ? popularItems
            : popularItems.take(6).toList();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding:
          const EdgeInsets.fromLTRB(
        8,
        8,
        8,
        24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildGamefowlFilter(),

          const SizedBox(height: 10),

          if (bestSellerItems.isNotEmpty)
            _buildGamefowlSection(
              title: 'Best Seller',
              items: visibleBestSeller,
              totalItems:
                  bestSellerItems.length,
              showAll:
                  _showAllBestSeller,
              onViewAll: () {
                setState(() {
                  _showAllBestSeller =
                      !_showAllBestSeller;
                });
              },
            ),

          if (popularItems.isNotEmpty)
            _buildGamefowlSection(
              title: 'Popular',
              items: visiblePopular,
              totalItems:
                  popularItems.length,
              showAll:
                  _showAllPopular,
              onViewAll: () {
                setState(() {
                  _showAllPopular =
                      !_showAllPopular;
                });
              },
            ),

          if (displayItems.isEmpty)
            _buildEmptyGamefowlState(),
        ],
      ),
    );
  }

  Widget _buildGamefowlFilter() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection:
            Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 4,
        ),
        itemCount:
            _gamefowlTypes.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 7),
        itemBuilder: (
          context,
          index,
        ) {
          final type =
              _gamefowlTypes[index];

          final isSelected =
              _selectedGamefowlType ==
                  type;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedGamefowlType =
                    type;

                _showAllBestSeller =
                    false;
                _showAllPopular = false;
              });
            },
            child: AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 13,
              ),
              alignment:
                  Alignment.center,
              decoration:
                  BoxDecoration(
                color: isSelected
                    ? AppColors
                        .brandPrimary
                    : Colors.grey[100],
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
                border: Border.all(
                  color: isSelected
                      ? AppColors
                          .brandPrimary
                      : Colors.grey[300]!,
                ),
              ),
              child: Text(
                type,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : Colors.grey[700],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ================================================================
  // REUSABLE GAMEFOWL SECTION
  // ================================================================

  Widget _buildGamefowlSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required int totalItems,
    required bool showAll,
    required VoidCallback onViewAll,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 4,
          ),
          child: Row(
            children: [
              Icon(
                title == 'Best Seller'
                    ? Icons.local_fire_department
                    : Icons.star,
                size: 18,
                color:
                    title == 'Best Seller'
                        ? AppColors
                            .brandPrimary
                        : AppColors
                            .accentAmber,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF252525),
                  ),
                ),
              ),

              if (totalItems > 1)
                GestureDetector(
                  onTap: onViewAll,
                  behavior:
                      HitTestBehavior.opaque,
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 5,
                      horizontal: 4,
                    ),
                    child: Text(
                      showAll
                          ? 'Show Less'
                          : 'View All',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                        color: AppColors
                            .brandPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        SizedBox(
          height: 288,
          child: ListView.separated(
            scrollDirection:
                Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 4,
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 10),
            itemBuilder: (
              context,
              index,
            ) {
              return SizedBox(
                width: 165,
                child:
                    _buildGamefowlCard(
                  items[index],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ================================================================
  // GAMEFOWL CARD
  // ================================================================

  Widget _buildGamefowlCard(
    Map<String, dynamic> product,
  ) {
    final productName =
        _getProductName(product);

    final price =
        _getProductPrice(product);

    final imageUrl =
        _getProductImage(product);

    final type =
        _getGamefowlType(product);

    final breeder =
        _getBreederName(product);

    final age =
        _getProductAge(product);

    return GestureDetector(
      onTap: () {
        /*
         * IMPORTANT:
         * Use each live item's ID when opening its details.
         *
         * This allows the card to proceed to Product Details.
         * The complete product information is passed through
         * productData so Product Details can use the exact
         * information shown on this card.
         */
        final productId =
            product['item_id'] ??
            product['product_id'] ??
            product['id'];

        if (productId == null) {
          return;
        }

        final detailProduct =
            Map<String, dynamic>.from(product);

        // Exact information displayed by this card.
        detailProduct['__listing_display_name'] =
            productName;

        detailProduct['__listing_display_price'] =
            price;

        detailProduct['__listing_display_image'] =
            imageUrl;

        detailProduct['__listing_display_type'] =
            type;

        detailProduct['__listing_display_breeder'] =
            breeder;

        detailProduct['__listing_display_age'] =
            age;

        detailProduct['__listing_display_description'] =
            product['description']?.toString() ??
                'Quality gamefowl from '
                    '${_getDisplayShopName()}.';

        // The shop/farm name that should appear
        // underneath the description in Product Details.
        detailProduct['__listing_shop_name'] =
            _getDisplayShopName();

        // Pass the farm/shop image too.
        detailProduct['__listing_shop_image'] =
            widget.shopImage;

        Navigator.push(
          context,
          _createFadeRoute(
            gamefowlProdDetail(
              productId: productId,
              productData: detailProduct,
              shopId: widget.shopId,
              shopName: _getDisplayShopName(),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.08),
              blurRadius: 6,
              offset:
                  const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.grey[200]!,
          ),
        ),
        clipBehavior:
            Clip.antiAlias,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 130,
              child: _buildGamefowlImage(
                imageUrl,
              ),
            ),

            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  10,
                  9,
                  10,
                  8,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.isNotEmpty
                          ? type
                          : 'One way / Pure',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w500,
                        color:
                            Color(0xFF444444),
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      productName,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            Color(0xFF23469C),
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      '₱$price',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF222222),
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      breeder.isNotEmpty
                          ? breeder
                          : 'Gamefowl breeder',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            Colors.grey[600],
                      ),
                    ),

                    if (age.isNotEmpty) ...[
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        age,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamefowlImage(
    String imageUrl,
  ) {
    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Icon(
          Icons.image_outlined,
          size: 36,
          color: Colors.grey[500],
        ),
      );
    }

    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return Container(
            color: Colors.grey[300],
            child: Icon(
              Icons.image_outlined,
              size: 36,
              color: Colors.grey[500],
            ),
          );
        },
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          color: Colors.grey[300],
          child: Icon(
            Icons.image_outlined,
            size: 36,
            color: Colors.grey[500],
          ),
        );
      },
      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }

        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  String _getProductName(
    Map<String, dynamic> product,
  ) {
    return (
      product['item_name'] ??
      product['product_name'] ??
      product['name'] ??
      product['title'] ??
      'Gamefowl'
    ).toString();
  }

  String _getProductPrice(
    Map<String, dynamic> product,
  ) {
    final raw =
        product['item_price'] ??
        product['price'] ??
        product['selling_price'] ??
        product['product_price'] ??
        product['amount'] ??
        '0.00';

    if (raw is num) {
      return raw.toStringAsFixed(2);
    }

    final parsed =
        double.tryParse(
      raw.toString(),
    );

    if (parsed != null) {
      return parsed.toStringAsFixed(2);
    }

    return raw.toString();
  }

  String _getProductImage(
    Map<String, dynamic> product,
  ) {
    final directAsset =
        product['image_asset'];

    if (directAsset is String &&
        directAsset.trim().isNotEmpty) {
      return directAsset.trim();
    }

    final rawImages =
        product['item_images'] ??
        product['images'] ??
        product['image_urls'];

    if (rawImages is List) {
      for (final entry in rawImages) {
        String? raw;

        if (entry is Map) {
          raw =
              entry['url']?.toString() ??
              entry['image_url']?.toString() ??
              entry['path']?.toString() ??
              entry['item_image']?.toString() ??
              entry['image']?.toString();
        } else {
          raw = entry?.toString();
        }

        if (raw != null &&
            raw.trim().startsWith('assets/')) {
          return raw.trim();
        }

        final resolved =
            _resolveMediaUrl(raw);

        if (resolved != null) {
          return resolved;
        }
      }
    }

    final image =
        product['image_url'] ??
        product['image'] ??
        product['product_image'] ??
        product['item_image'] ??
        product['photo'] ??
        product['thumbnail'];

    if (image is String &&
        image.trim().isNotEmpty) {
      final trimmed = image.trim();

      if (trimmed.startsWith('assets/')) {
        return trimmed;
      }

      return _resolveMediaUrl(trimmed) ??
          trimmed;
    }

    return '';
  }

  String? _resolveMediaUrl(
    String? raw,
  ) {
    if (raw == null) return null;

    final path = raw.trim();

    if (path.isEmpty) return null;

    if (path.startsWith('assets/')) {
      return path;
    }

    if (path.startsWith('http://') ||
        path.startsWith('https://')) {
      return path;
    }

    final baseUrl =
        Url.getUrl().replaceAll(
      RegExp(r'/+$'),
      '',
    );

    final normalized =
        path.startsWith('/')
            ? path
            : '/$path';

    return '$baseUrl$normalized';
  }

  String _getGamefowlType(
    Map<String, dynamic> product,
  ) {
    return (
      product['gamefowl_type'] ??
      product['fowl_type'] ??
      product['breed_type'] ??
      product['type'] ??
      product['category_name'] ??
      ''
    ).toString();
  }

  String _getBreederName(
    Map<String, dynamic> product,
  ) {
    return (
      product['breeder_name'] ??
      product['breeder'] ??
      product['seller_name'] ??
      product['shop_name'] ??
      ''
    ).toString();
  }

  String _getProductAge(
    Map<String, dynamic> product,
  ) {
    final age =
        product['age'] ??
        product['gamefowl_age'] ??
        product['fowl_age'];

    if (age == null) return '';

    final value =
        age.toString().trim();

    if (value.isEmpty) return '';

    final lowerValue =
        value.toLowerCase();

    return lowerValue.contains('week') ||
            lowerValue.contains('month') ||
            lowerValue.contains('year')
        ? value
        : '$value weeks old';
  }

  Widget _buildEmptyGamefowlState() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 50,
      ),
      child: Column(
        children: [
          Text(
            'No gamefowl available',
            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No gamefowl matches this category.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return Consumer<CategoryProvider>(
      builder: (
        context,
        categoryProvider,
        _,
      ) {
        if (categoryProvider.isLoading &&
            categoryProvider.categories
                .isEmpty) {
          return const CategoryChipsSkeleton(
            padding: EdgeInsets.zero,
          );
        }

        final categories =
            categoryProvider.categories;

        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection:
                Axis.horizontal,
            itemCount:
                categories.length,
            separatorBuilder: (
              _,
              __,
            ) =>
                const SizedBox(width: 8),
            itemBuilder: (
              context,
              index,
            ) {
              final category =
                  categories[index];

              final categoryId =
                  category['id'];

              final categoryName =
                  category['name'] ??
                  'Category';

              final isSelected =
                  _selectedCategoryId ==
                      categoryId;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategoryId =
                        isSelected
                            ? null
                            : categoryId;

                    _showAllBestSeller =
                        false;
                    _showAllPopular = false;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 16,
                  ),
                  alignment:
                      Alignment.center,
                  decoration:
                      BoxDecoration(
                    color: isSelected
                        ? AppColors
                            .brandPrimary
                            .withOpacity(
                            0.08,
                          )
                        : Colors.grey[100],
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    border: Border.all(
                      color: isSelected
                          ? AppColors
                              .brandPrimary
                              .withOpacity(
                              0.4,
                            )
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors
                              .brandPrimary
                          : Colors.grey[700],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics:
          const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Padding(
            padding:
                EdgeInsets.all(16),
            child: AppSkeletonizer(
              child: Row(
                children: [
                  SkeletonBox(
                    width: 80,
                    height: 80,
                    radius: 40,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(
                          width: 160,
                          height: 16,
                        ),
                        SizedBox(height: 10),
                        SkeletonBox(
                          width:
                              double.infinity,
                          height: 12,
                        ),
                        SizedBox(height: 6),
                        SkeletonBox(
                          width: 120,
                          height: 12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ProductGridSkeleton(
            imageHeight: 130,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load gamefarm',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ??
                  'An error occurred',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed:
                  _loadShopData,
              icon:
                  const Icon(Icons.refresh),
              label:
                  const Text('Retry'),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    AppColors
                        .brandPrimary,
                foregroundColor:
                    Colors.white,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isShopOpen() {
    final status =
        _shopDetails?['shop_status']
                ?.toString()
                .toLowerCase() ??
            '';

    return status.contains('open') ||
        status.contains('active');
  }

  Widget _buildTopControls() {
    final topInset =
        MediaQuery.of(context).padding.top;

    return Positioned(
      top: topInset + 8,
      left: 12,
      right: 12,
      child: Row(
        children: [
          _buildCircleButton(
            icon: Icons.chevron_left,
            onTap: () =>
                Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 44,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.08),
                    blurRadius: 8,
                    offset:
                        const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 20,
                    color:
                        Colors.grey[500],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Search in store',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildCircleButton(
            icon: Icons.more_horiz,
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content:
                      const Text(
                    'Share gamefarm',
                  ),
                  duration:
                      const Duration(
                    seconds: 1,
                  ),
                  backgroundColor:
                      AppColors
                          .brandPrimary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShopHeader() {
    final passedShopImage =
        widget.shopImage?.trim();

    final apiShopLogo =
        _shopDetails?['shop_logo']
            ?.toString();

    final apiShopBanner =
        _shopDetails?['shop_banner']
            ?.toString();

    final shopImage =
        passedShopImage != null &&
                passedShopImage.isNotEmpty
            ? passedShopImage
            : apiShopBanner;

    final shopLogo =
        passedShopImage != null &&
                passedShopImage.isNotEmpty
            ? passedShopImage
            : apiShopLogo;

    final hasLogo =
        shopLogo != null &&
        shopLogo.isNotEmpty;

    final hasBanner =
        shopImage != null &&
        shopImage.isNotEmpty;

    final shopName =
        _getDisplayShopName();

    final shopAddress =
        _shopDetails?['shop_address']
                ?.toString() ??
            '';

    final contactNumber =
        _shopDetails?['contact_number']
                ?.toString() ??
            '';

    final facebookAccount =
        _getFacebookAccount();

    final operatingHours =
        _shopDetails?['operating_hours']
                ?.toString()
                .trim() ??
            '';

    final operatingDays =
        _shopDetails?['operating_days']
                ?.toString()
                .trim() ??
            '';

    final isOpen =
        _isShopOpen();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 230,
          width: double.infinity,
          decoration:
              BoxDecoration(
            gradient:
                LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                AppColors
                    .brandPrimary,
                AppColors
                    .brandPrimary
                    .withOpacity(
                  0.7,
                ),
              ],
            ),
          ),
          child: hasBanner
              ? _buildHeaderImage(
                  shopImage!,
                  fallback:
                      _buildFallbackBanner(),
                )
              : _buildFallbackBanner(),
        ),

        Padding(
          padding:
              const EdgeInsets.only(
            top: 210,
          ),
          child: Container(
            width: double.infinity,
            decoration:
                const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            padding:
                const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              18,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset:
                          const Offset(0, -24),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.grey[100],
                          shape:
                              BoxShape.circle,
                          border:
                              Border.all(
                            color:
                                Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors
                                  .black
                                  .withOpacity(
                                0.1,
                              ),
                              blurRadius: 8,
                              offset:
                                  const Offset(
                                0,
                                2,
                              ),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: hasLogo
                              ? _buildHeaderImage(
                                  shopLogo!,
                                  fallback:
                                      _buildProfileFallback(
                                    shopImage,
                                  ),
                                )
                              : _buildProfileFallback(
                                  shopImage,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 16,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  shopName,
                                  style:
                                      const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                    color:
                                        Color(
                                      0xFF202020,
                                    ),
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              Icon(
                                Icons.verified,
                                size: 15,
                                color:
                                    AppColors
                                        .brandPrimary,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 1,
                          ),
                          Text(
                            isOpen
                                ? 'Open'
                                : 'Closed',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOpen
                                  ? AppColors
                                      .brandPrimaryLight
                                  : AppColors
                                      .error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 0),

                if (shopAddress.isNotEmpty)
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    shopAddress,
                  ),

                if (contactNumber.isNotEmpty)
                  _buildInfoRow(
                    Icons.phone_outlined,
                    contactNumber,
                  ),

                if (facebookAccount.isNotEmpty)
                  _buildInfoRow(
                    Icons.facebook,
                    facebookAccount,
                    onTap: null,
                  ),

                if (operatingHours.isNotEmpty ||
                    operatingDays.isNotEmpty)
                  _buildInfoRow(
                    Icons.access_time,
                    operatingHours.isNotEmpty
                        ? _formatOperatingHours(
                            operatingHours,
                          )
                        : operatingDays,
                    subtitle:
                        operatingHours.isNotEmpty &&
                                operatingDays
                                    .isNotEmpty
                            ? operatingDays
                            : null,
                  ),

              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderImage(
    String imageUrl, {
    required Widget fallback,
  }) {
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) =>
            fallback,
      );
    }

    return Image.network(
      _resolveMediaUrl(imageUrl) ??
          imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) =>
          fallback,
    );
  }

  String _getDisplayShopName() {
    final passedName =
        widget.shopName?.trim();

    if (passedName != null &&
        passedName.isNotEmpty) {
      return passedName;
    }

    final details = _shopDetails;

    final candidates = [
      details?['gamefarm_name'],
      details?['farm_name'],
      details?['shop_name'],
      details?['store_name'],
      details?['name'],
    ];

    for (final value in candidates) {
      final name =
          value?.toString().trim();

      if (name != null &&
          name.isNotEmpty) {
        return name;
      }
    }

    return 'Shop';
  }

  String _getFacebookAccount() {
    final value =
        _shopDetails?['facebook_account'] ??
        _shopDetails?['facebook'] ??
        _shopDetails?['facebook_name'] ??
        _shopDetails?['facebook_url'] ??
        _shopDetails?['facebook_link'] ??
        '';

    return value.toString().trim();
  }

  Widget _buildProfileFallback(
    String? bannerUrl,
  ) {
    if (bannerUrl != null &&
        bannerUrl.trim().isNotEmpty) {
      if (bannerUrl.startsWith('assets/')) {
        return Image.asset(
          bannerUrl,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return Container(
              color: Colors.grey[100],
              child: Icon(
                Icons.store,
                size: 42,
                color: Colors.grey[400],
              ),
            );
          },
        );
      }

      return Image.network(
        _resolveMediaUrl(bannerUrl) ??
            bannerUrl,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return Container(
            color: Colors.grey[100],
            child: Icon(
              Icons.store,
              size: 42,
              color: Colors.grey[400],
            ),
          );
        },
      );
    }

    return Container(
      color: Colors.grey[100],
      child: Icon(
        Icons.store,
        size: 42,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return Image.asset(
      'assets/images/store_sample.png',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) =>
          Center(
        child: Icon(
          Icons.store,
          size: 48,
          color:
              Colors.white.withOpacity(
            0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor:
          Colors.black.withOpacity(
        0.15,
      ),
      child: InkWell(
        customBorder:
            const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final textStyle =
        TextStyle(
      fontSize: 12,
      color: onTap != null
          ? AppColors.brandPrimary
          : Colors.grey[700],
      height: 1.3,
      decoration: onTap != null
          ? TextDecoration.underline
          : null,
      decorationColor:
          AppColors.brandPrimary,
    );

    final content = Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: textStyle,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
      ],
    );

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color:
                AppColors.brandPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: onTap != null
                ? InkWell(
                    onTap: onTap,
                    borderRadius:
                        BorderRadius.circular(
                      4,
                    ),
                    child: content,
                  )
                : content,
          ),
        ],
      ),
    );
  }

  // ================================================================
  // REVIEWS
  // ================================================================

  Widget _buildReviewsPreview() {
    return Consumer<ShopsProvider>(
      builder: (
        context,
        shopsProvider,
        child,
      ) {
        final reviewsData =
            shopsProvider.getShopReviews(
          widget.shopId,
        );

        final reviews =
            shopsProvider.getShopReviewsList(
          widget.shopId,
        );

        final isLoading =
            shopsProvider.isReviewsLoading(
          widget.shopId,
        );

        final totalReviews =
            reviewsData?['total_reviews'] ??
                reviews.length;

        final avgRating =
            reviewsData?['average_rating'];

        return Container(
          width: double.infinity,
          color: Colors.white,
          padding:
              const EdgeInsets.fromLTRB(
            16,
            18,
            16,
            24,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Customer Reviews',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w700,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (avgRating != null) ...[
                    Icon(
                      Icons.star,
                      size: 18,
                      color:
                          AppColors.accentAmber,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _formatRating(
                        avgRating,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            Colors.grey[700],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '$totalReviews review${totalReviews == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Colors.grey[500],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 16,
              ),

              if (isLoading)
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    border: Border.all(
                      color:
                          Colors.grey[200]!,
                    ),
                  ),
                  child: Center(
                    child:
                        CircularProgressIndicator(
                      color: AppColors
                          .brandPrimary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (reviews.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    border: Border.all(
                      color:
                          Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons
                            .rate_review_outlined,
                        size: 48,
                        color:
                            Colors.grey[300],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Text(
                        'No reviews yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w600,
                          color:
                              Colors.grey[600],
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        'Customer reviews will appear here.',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    border: Border.all(
                      color:
                          Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    children: reviews
                        .map(
                          (review) =>
                              _buildReviewCard(
                            review,
                            isLast:
                                review ==
                                    reviews.last,
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewCard(
    Map<String, dynamic> review, {
    bool isLast = false,
  }) {
    final username =
        review['username'] ??
            'Anonymous';

    final rating =
        review['rating'] is num
            ? (review['rating'] as num)
                .toDouble()
            : double.tryParse(
                  review['rating']
                          ?.toString() ??
                      '0',
                ) ??
                0.0;

    final comment =
        review['comment'] ?? '';

    final itemName =
        review['item_name'];

    final createdAt =
        review['created_at'];

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast
                ? Colors.transparent
                : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(
                  color: AppColors
                      .brandPrimary
                      .withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child: Center(
                  child: Text(
                    username
                            .toString()
                            .isNotEmpty
                        ? username
                            .toString()[0]
                            .toUpperCase()
                        : 'A',
                    style: TextStyle(
                      color: AppColors
                          .brandPrimary,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      username.toString(),
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w600,
                        fontSize: 14,
                        color:
                            Colors.grey[800],
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (index) {
                            return Icon(
                              index <
                                      rating
                                          .round()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 14,
                              color: AppColors
                                  .accentAmber,
                            );
                          },
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        if (createdAt !=
                            null)
                          Text(
                            _formatReviewDate(
                              createdAt.toString(),
                            ),
                            style:
                                TextStyle(
                              fontSize: 12,
                              color: Colors
                                  .grey[500],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (itemName != null &&
              itemName
                  .toString()
                  .isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.grey[100],
                borderRadius:
                    BorderRadius.circular(
                  4,
                ),
              ),
              child: Text(
                itemName.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
          ],

          if (comment
              .toString()
              .isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment.toString(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              maxLines: 5,
              overflow:
                  TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatReviewDate(
    String dateString,
  ) {
    try {
      final dateTime =
          ManilaTime.tryParseToManila(
        dateString,
      );

      if (dateTime != null) {
        final now =
            ManilaTime.now();

        final difference =
            now.difference(dateTime);

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
            'Dec',
          ];

          return '${months[dateTime.month - 1]} '
              '${dateTime.day}, '
              '${dateTime.year}';
        }
      }
    } catch (_) {}

    return '';
  }
}
