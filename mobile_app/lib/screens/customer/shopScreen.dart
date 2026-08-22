import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/constants.dart';
import '../../provider/provider.dart';
import '../../utils/auth_guard.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'conversationScreen.dart';
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
  bool _isFollowing = false;
  int _selectedTab = 0; // 0 = Products, 1 = Reviews
  dynamic _selectedCategoryId;

  List<Map<String, dynamic>> get _filteredShopItems {
    if (_selectedCategoryId == null) return _shopItems;

    final categories =
        Provider.of<CategoryProvider>(context, listen: false).categories;
    Map<String, dynamic>? selectedCategory;
    for (final category in categories) {
      if (category['id'] == _selectedCategoryId) {
        selectedCategory = category;
        break;
      }
    }
    if (selectedCategory == null) return _shopItems;

    return _shopItems
        .where((item) => _itemMatchesCategory(item, selectedCategory!))
        .toList();
  }

  bool _itemMatchesCategory(
    Map<String, dynamic> item,
    Map<String, dynamic> category,
  ) {
    final raw = (item['category'] ?? '').toString().trim();
    if (raw.isEmpty) return false;

    final categoryId = category['id']?.toString();
    final categoryName = (category['name'] ?? '').toString();

    return raw == categoryId || raw.toLowerCase() == categoryName.toLowerCase();
  }

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
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      // Fetch shop details, items, reviews, and categories in parallel
      await Future.wait([
        shopsProvider.fetchShopDetails(widget.shopId),
        shopsProvider.fetchShopItems(widget.shopId),
        shopsProvider.fetchShopReviews(widget.shopId),
        categoryProvider.fetchCategories(),
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

  String _formatOperatingHours(String hours) {
    final match = RegExp(
      r'(\d{1,2}):(\d{2})\s*[-–]\s*(\d{1,2}):(\d{2})',
    ).firstMatch(hours);
    if (match == null) return hours;

    String formatPart(String hour, String minute) {
      final h = int.tryParse(hour) ?? 0;
      final period = h >= 12 ? 'PM' : 'AM';
      final displayHour = h % 12 == 0 ? 12 : h % 12;
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
      backgroundColor: AppColors.surfaceLight,
      body: _isLoading
          ? SafeArea(child: _buildLoadingState())
          : _error != null
              ? SafeArea(child: _buildErrorState())
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadShopData,
                      color: AppColors.primaryGreen,
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Shop Header (banner + overlapping info card)
                            _buildShopHeader(),

                            // Tabs: Products / Reviews
                            SizedBox(height: 15),
                            _buildTabBar(),

                            // Selected tab content
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.04, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                );
                              },
                              child: KeyedSubtree(
                                key: ValueKey<int>(_selectedTab),
                                child: _selectedTab == 0
                                    ? _buildProductsSection()
                                    : _buildReviewsPreview(),
                              ),
                            ),

                            SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // Pinned top controls (back, search, more)
                    _buildTopControls(),
                  ],
                ),
    );
  }

  Widget _buildTabBar() {
    final rating = _shopDetails?['shop_rating'];
    return Container(
      color: AppColors.surfaceLight,
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              label: 'Products',
              isActive: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          Expanded(
            child: _buildTab(
              label: 'Reviews',
              isActive: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
              trailing: rating != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star,
                            size: 16, color: AppColors.accentAmber),
                        SizedBox(width: 3),
                        Text(
                          _formatRating(rating),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : AppColors.surfaceLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.grey[900] : Colors.grey[600],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: 6),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, _) {
        if (categoryProvider.isLoading && categoryProvider.categories.isEmpty) {
          return const CategoryChipsSkeleton(padding: EdgeInsets.zero);
        }

        final categories = categoryProvider.categories;
        if (categories.isEmpty) {
          return SizedBox(
            height: 36,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (categoryProvider.error != null)
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        size: 20,
                        color: AppColors.primaryGreen,
                      ),
                      onPressed: () =>
                          categoryProvider.fetchCategories(useCache: false),
                      tooltip: 'Retry',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  Text(
                    'No categories available',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              final categoryId = category['id'];
              final categoryName = category['name'] ?? 'Category';
              final isSelected = _selectedCategoryId == categoryId;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedCategoryId = null;
                    } else {
                      _selectedCategoryId = categoryId;
                    }
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreen.withOpacity(0.08)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreen.withOpacity(0.4)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryGreen
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
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppSkeletonizer(
              child: Row(
                children: [
                  SkeletonBox(width: 80, height: 80, radius: 40),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 160, height: 16),
                        SizedBox(height: 10),
                        SkeletonBox(width: double.infinity, height: 12),
                        SizedBox(height: 6),
                        SkeletonBox(width: 120, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ProductGridSkeleton(imageHeight: 130),
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
                backgroundColor: AppColors.primaryGreen,
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

  bool _isShopOpen() {
    final status = _shopDetails?['shop_status']?.toString().toLowerCase() ?? '';
    return status.contains('open') || status.contains('active');
  }

  Widget _buildTopControls() {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topInset + 8,
      left: 12,
      right: 12,
      child: Row(
        children: [
          _buildCircleButton(
            icon: Icons.chevron_left,
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 44,
              padding: EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: Colors.grey[500]),
                  SizedBox(width: 8),
                  Text(
                    'Search in store',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10),
          _buildCircleButton(
            icon: Icons.more_horiz,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Share shop'),
                  duration: Duration(seconds: 1),
                  backgroundColor: AppColors.primaryGreen,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShopHeader() {
    final shopLogo = _shopDetails?['shop_logo']?.toString();
    final hasLogo = shopLogo != null && shopLogo.isNotEmpty;
    final shopBanner = _shopDetails?['shop_banner']?.toString();
    final hasBanner = shopBanner != null && shopBanner.isNotEmpty;
    final shopName = _shopDetails?['shop_name'] ?? widget.shopName ?? 'Shop';
    final shopAddress = _shopDetails?['shop_address']?.toString() ?? '';
    final contactNumber = _shopDetails?['contact_number']?.toString() ?? '';
    final operatingHours =
        _shopDetails?['operating_hours']?.toString().trim() ?? '';
    final operatingDays =
        _shopDetails?['operating_days']?.toString().trim() ?? '';
    final isOpen = _isShopOpen();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Banner
        Container(
          height: 230,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryGreen,
                AppColors.primaryGreen.withOpacity(0.7),
              ],
            ),
          ),
          child: hasBanner
              ? Image.network(
                  shopBanner,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildFallbackBanner(),
                )
              : _buildFallbackBanner(),
        ),

        // Overlapping info card
        Padding(
          padding: EdgeInsets.only(top: 210),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo + name + status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, -24),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: hasLogo
                              ? Image.network(
                                  shopLogo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.storefront,
                                    size: 44,
                                    color: Colors.grey[400],
                                  ),
                                )
                              : Icon(
                                  Icons.storefront,
                                  size: 44,
                                  color: Colors.grey[400],
                                ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            shopName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 1),
                          Text(
                            isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: isOpen
                                  ? AppColors.primaryGreenLight
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),

                // Info rows
                if (shopAddress.isNotEmpty)
                  _buildInfoRow(Icons.location_on_outlined, shopAddress),
                if (contactNumber.isNotEmpty)
                  _buildInfoRow(
                    Icons.phone_outlined,
                    contactNumber,
                    onTap: () => _launchPhoneDialer(contactNumber),
                  ),
                if (operatingHours.isNotEmpty || operatingDays.isNotEmpty)
                  _buildInfoRow(
                    Icons.access_time,
                    operatingHours.isNotEmpty
                        ? _formatOperatingHours(operatingHours)
                        : operatingDays,
                    subtitle: operatingHours.isNotEmpty && operatingDays.isNotEmpty
                        ? operatingDays
                        : null,
                  ),
                SizedBox(height: 18),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: _isFollowing ? 'Following' : 'Follow',
                        icon: _isFollowing
                            ? Icons.favorite
                            : Icons.favorite_border,
                        filled: false,
                        onTap: () {
                          setState(() => _isFollowing = !_isFollowing);
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        label: 'Chat',
                        icon: Icons.chat_bubble_outline,
                        filled: true,
                        onTap: () async {
                          if (!await requireAuth(context)) return;
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConversationScreen(
                                shopId: widget.shopId,
                                shopName: widget.shopName ??
                                    _shopDetails?['shop_name']?.toString(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackBanner() {
    return Image.asset(
      'assets/images/store_sample.png',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Icon(
          Icons.store,
          size: 48,
          color: Colors.white.withOpacity(0.3),
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
      shape: CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.15),
      child: InkWell(
        customBorder: CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 24, color: Colors.grey[800]),
        ),
      ),
    );
  }

  Future<void> _launchPhoneDialer(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open phone dialer'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open phone dialer'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(
    IconData icon,
    String text, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final textStyle = TextStyle(
      fontSize: 14,
      color: onTap != null ? AppColors.primaryGreen : Colors.grey[700],
      height: 1.3,
      decoration: onTap != null ? TextDecoration.underline : null,
      decorationColor: AppColors.primaryGreen,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: textStyle),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryGreen),
          SizedBox(width: 10),
          Expanded(
            child: onTap != null
                ? InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(4),
                    child: content,
                  )
                : content,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: filled ? AppColors.primaryGreen : Colors.grey[100],
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: filled ? Colors.white : Colors.grey[700],
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: filled ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
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

        return Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      if (avgRating != null) ...[
                        SizedBox(width: 8),
                        Icon(Icons.star,
                            size: 16, color: AppColors.accentAmber),
                        SizedBox(width: 3),
                        Text(
                          _formatRating(avgRating),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
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
                          color: AppColors.primaryGreen,
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
                      color: AppColors.primaryGreen,
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
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : 'A',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
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
                            color: AppColors.accentAmber,
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
    final displayItems = _filteredShopItems;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategorySection(),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${displayItems.length} items',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 12),
          if (displayItems.isEmpty)
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
                      _selectedCategoryId != null
                          ? 'No products in this category'
                          : 'No products yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _selectedCategoryId != null
                          ? 'Try selecting a different category'
                          : 'This shop hasn\'t added any products',
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
                mainAxisExtent: 250,
              ),
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final product = displayItems[index];
                return ProductCard(
                  product: product,
                  onTap: () {
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
        ],
      ),
    );
  }
}
