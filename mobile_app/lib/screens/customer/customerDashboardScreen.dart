import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../services/api_service.dart';
import '../../services/items_services.dart';
import '../../provider/provider.dart';
import '../../utils/auth_guard.dart';
import '../../utils/customer_nav.dart';
import '../../widgets/login_dialog.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'customerPlaceholderScreen.dart';
import 'messagesScreen.dart';
import 'conversationScreen.dart';
import 'cartScreenV2.dart';
import '../common/profileScreen.dart';
import '../common/myOrderScreen.dart';
import 'favoriteScreen.dart';
import 'productDetailScreen.dart';
import 'shopScreen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;
  String? _categoryError;
  List<Map<String, dynamic>> _featuredProducts = [];
  bool _isLoadingProducts = true;
  final ItemsService _itemsService = ItemsService();
  List<Map<String, dynamic>> _buyAgainProducts = [];
  bool _isLoadingBuyAgain = true;
  String? _buyAgainError;
  String? _userName;
  bool _isGuest = true;

  // Suggested Stores
  List<Map<String, dynamic>> _suggestedStores = [];
  bool _isLoadingStores = true;
  String? _storeError;

  // Stores Near You slider
  final PageController _storePageController =
      PageController(viewportFraction: 0.85);
  int _currentStorePage = 0;

  // Selected Category
  String? _selectedCategoryName;
  final GlobalKey _categorySectionKey = GlobalKey();

  // For SearchBar
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer loading until after the build phase completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
      _loadOnSaleProducts();
      _loadFeaturedProducts();
      _loadSuggestedStores();
      _loadUserName().then((_) {
        if (!mounted) return;
        if (!_isGuest) {
          _loadBuyAgainProducts();
          _fetchBadges();
          _fetchMessageUnread();
        } else {
          _clearBadges();
        }
      });
    });

    // Listen to text changes with debounce
    _searchController.addListener(_onSearchChanged);

    // Pin search panel and hide overlay on focus changes
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus) {
        _scrollToPinSearchPanel();
      } else {
        // Delay to allow tap on results
        Future.delayed(Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _showOverlay = false);
          }
        });
      }
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text;

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Clear results if query is empty or too short
    if (query.trim().isEmpty || query.trim().length < 2) {
      final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
      itemsProvider.clearSearch();
      setState(() => _showOverlay = false);
      return;
    }

    // Debounce search requests
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
    await itemsProvider.searchItems(query);

    if (mounted) {
      setState(() {
        _showOverlay = query.trim().length >= 2;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
    itemsProvider.clearSearch();
    setState(() => _showOverlay = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final messages = Provider.of<MessageProvider>(context, listen: false);
    if (state == AppLifecycleState.resumed && !_isGuest) {
      messages.startLiveUpdates();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      messages.pauseLiveUpdates();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    _storePageController.dispose();
    super.dispose();
  }

  void _scrollToPinSearchPanel() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset >= _headerCollapseRange) return;
    _scrollController.animateTo(
      _headerCollapseRange,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadCategories({bool useCache = true}) async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    if (!mounted) return;
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });

    await categoryProvider.fetchCategories(useCache: useCache);

    if (!mounted) return;
    setState(() {
      _categories = categoryProvider.categories;
      _isLoadingCategories = categoryProvider.isLoading;
      _categoryError = categoryProvider.error;
      if (categoryProvider.fromCache && _categories.isNotEmpty) {
        _categoryError = 'Using cached data (connection lost)';
      }

      // Fallback to default categories if both API and cache failed
      if (_categories.isEmpty && _categoryError != null) {
        _categories = [
          {'name': 'Accessories', 'icon': Icons.shopping_bag_outlined},
          {'name': 'Feeds', 'icon': Icons.feed},
          {'name': 'Health', 'icon': Icons.health_and_safety},
          {'name': 'Tools', 'icon': Icons.build},
        ];
      } else {
        _categories = _sortCategories(_categories);
      }
    });
  }

  Future<void> _loadUserName() async {
    try {
      final token = await ApiService.getToken();
      final name = await ApiService.getUserName();
      if (!mounted) return;
      setState(() {
        _userName = name;
        _isGuest = token == null || token.isEmpty;
      });
    } catch (e) {
      print('Error loading user name: $e');
      if (!mounted) return;
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
  }

  Future<void> _refreshAfterLogin() async {
    await _loadUserName();
    await _loadBuyAgainProducts();
    await _fetchBadges();
    await _fetchMessageUnread();
  }

  Future<void> _fetchBadges() async {
    if (!mounted) return;
    await Provider.of<BadgeProvider>(context, listen: false).fetchBadges();
  }

  Future<void> _fetchMessageUnread() async {
    if (!mounted) return;
    final messages = Provider.of<MessageProvider>(context, listen: false);
    await messages.fetchUnreadCount();
    messages.startLiveUpdates();
  }

  void _clearBadges() {
    if (!mounted) return;
    Provider.of<BadgeProvider>(context, listen: false).clear();
    Provider.of<MessageProvider>(context, listen: false).clear();
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

  Future<void> _loadFeaturedProducts({bool useCache = true}) async {
    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);

    if (!mounted) return;
    setState(() {
      _isLoadingProducts = true;
    });

    await itemsProvider.fetchItems(useCache: useCache);

    if (!mounted) return;
    // Take first 4 items as featured products
    setState(() {
      _featuredProducts = itemsProvider.items.take(4).toList();
      _isLoadingProducts = itemsProvider.isLoading;
    });
  }

  Future<void> _loadOnSaleProducts() async {
    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
    await itemsProvider.fetchItemsOnSale();
  }

  Future<void> _loadSuggestedStores({bool useCache = true}) async {
    final shopsProvider = Provider.of<ShopsProvider>(context, listen: false);

    if (!mounted) return;
    setState(() {
      _isLoadingStores = true;
      _storeError = null;
    });

    await shopsProvider.fetchShops(useCache: useCache, limit: 6);

    if (!mounted) return;
    setState(() {
      _suggestedStores = shopsProvider.shops;
      _isLoadingStores = shopsProvider.isLoading;
      _storeError = shopsProvider.error;
      if (shopsProvider.fromCache && _suggestedStores.isNotEmpty) {
        _storeError = 'Using cached data (connection lost)';
      }
    });
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
      print('Error formatting price: $e');
    }

    return '₱0.00';
  }

  String _formatRating(dynamic rating) {
    if (rating == null) return 'N/A';

    try {
      if (rating is num) {
        return rating.toStringAsFixed(1);
      } else if (rating is String) {
        final parsed = double.tryParse(rating);
        return parsed != null ? parsed.toStringAsFixed(1) : 'N/A';
      }
    } catch (e) {
      print('Error formatting rating: $e');
    }

    return 'N/A';
  }

  /// Reusable product card matching the marketplace card layout:
  /// image on top, category label, bold name, store name, sold count, price.
  Widget _buildItemCard(
    Map<String, dynamic> product, {
    double imageHeight = 130,
  }) {
    return ProductCard(
      product: product,
      imageHeight: imageHeight,
      onTap: () {
        Navigator.push(
          context,
          _createFadeRoute(
            ProductDetailScreen(productId: product['id']),
          ),
        );
      },
    );
  }

  Future<void> _loadBuyAgainProducts() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _buyAgainProducts = [];
        _isLoadingBuyAgain = false;
        _buyAgainError = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingBuyAgain = true;
      _buyAgainError = null;
    });

    try {
      final items = await _itemsService.fetchOrderedItemsByUserId();
      if (!mounted) return;
      setState(() {
        _buyAgainProducts = items;
        _isLoadingBuyAgain = false;
        _buyAgainError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buyAgainProducts = [];
        _isLoadingBuyAgain = false;
        _buyAgainError = e.toString();
      });
    }
  }

  Future<void> _onRefresh() async {
    final refreshTasks = <Future<void>>[
      _loadCategories(),
      _loadOnSaleProducts(),
      _loadFeaturedProducts(),
      _loadSuggestedStores(),
    ];
    if (!_isGuest) {
      refreshTasks.add(_loadBuyAgainProducts());
    }
    await Future.wait(refreshTasks);
    // Add a small delay to show the refresh indicator
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primaryGreen,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CollapsingHeaderDelegate(
                      minExtentValue: _collapsedHeaderExtent,
                      maxExtentValue: _expandedHeaderExtent,
                      headerHeight: _headerHeight,
                      heroHeight: _heroBannerHeight,
                      searchBarHeight: _searchBarHeight,
                      searchBarWidthFactor: _searchBarWidthFactor,
                      searchOverlap: _searchBarOverlap,
                      searchTopGap: _searchTopGap,
                      searchCategoriesGap: _searchCategoriesGap,
                      categoriesHeight: _categoriesHeight,
                      categoriesBottomPad: _categoriesBottomPad,
                      fadeHeight: _headerFadeHeight,
                      backgroundColor: AppColors.surfaceLight,
                      header: _buildCustomerHeader(),
                      hero: _buildHeroBanner(),
                      searchBar: _buildSearchBar(),
                      categories: _buildCategoriesSection(),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildBelowFoldContent()),
                ],
              ),
            ),
            _buildSearchOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  void _onAuthenticatedTap(VoidCallback action) {
    if (!requireAuthOrShowLogin(context, isGuest: _isGuest)) return;
    action();
  }

  void _navigateToCart() {
    if (_isGuest) {
      showLoginDialog(
        context,
        onLoginSuccess: _refreshAfterLogin,
      );
      return;
    }
    Navigator.push(
      context,
      _createFadeRoute(CartScreenV2()),
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
        _fetchBadges();
      }
    });
  }

  static const List<String> _categoryDisplayOrder = [
    'Accessories',
    'Feeds',
    'Health',
    'Tools',
    'Bundle',
  ];

  /// Smoothly scrolls the dashboard so the selected-category products section
  /// is brought into view, sitting just below the pinned header.
  void _scrollToCategorySection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _categorySectionKey.currentContext;
      if (ctx == null || !mounted) return;
      final screenHeight = MediaQuery.of(context).size.height;
      // Stop just below the pinned header, plus a little breathing room so the
      // section's "<Category> Products" label clears the header and stays
      // fully visible instead of being tucked behind it.
      const labelClearance = 16.0;
      final alignment = screenHeight > 0
          ? ((_collapsedHeaderExtent + labelClearance) / screenHeight)
          : 0.0;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: alignment.clamp(0.0, 1.0),
      );
    });
  }

  List<Map<String, dynamic>> _sortCategories(
      List<Map<String, dynamic>> categories) {
    int orderIndex(String name) {
      final index = _categoryDisplayOrder.indexOf(name);
      return index >= 0 ? index : _categoryDisplayOrder.length;
    }

    final sorted = List<Map<String, dynamic>>.from(categories);
    sorted.sort((a, b) {
      final aName = (a['name'] ?? '').toString();
      final bName = (b['name'] ?? '').toString();
      return orderIndex(aName).compareTo(orderIndex(bName));
    });
    return sorted;
  }

  // Collapsing header geometry
  static const double _headerHeight = 68.0;
  static const double _heroBannerHeight = 250.0;
  static const double _searchBarHeight = 45.0;
  static const double _searchBarWidthFactor = 0.9; // 90% of screen
  static const double _searchBarOverlap = _searchBarHeight / 2;
  static const double _searchTopGap = 12.0; // gap below app bar when pinned
  static const double _categoriesHeight = 40.0;
  static const double _searchCategoriesGap = 12.0;
  static const double _categoriesBottomPad = 6.0;
  static const double _headerFadeHeight = 16.0;

  // Collapsed (pinned) and expanded total heights of the header region.
  static const double _collapsedHeaderExtent = _headerHeight +
      _searchTopGap +
      _searchBarHeight +
      _searchCategoriesGap +
      _categoriesHeight +
      _categoriesBottomPad +
      _headerFadeHeight;
  static const double _expandedHeaderExtent = _headerHeight +
      _heroBannerHeight +
      _searchBarOverlap +
      _searchCategoriesGap +
      _categoriesHeight +
      _categoriesBottomPad +
      _headerFadeHeight;
  static const double _headerCollapseRange =
      _expandedHeaderExtent - _collapsedHeaderExtent;
  static const double _searchOverlayTop =
      _headerHeight + _searchTopGap + _searchBarHeight + 4;

  Widget _buildBelowFoldContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildKlasrumSection(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildSuggestedStores(),
              const SizedBox(height: 24),
              _buildOnSaleSection(),
              const SizedBox(height: 24),
              _buildCategoryItems(),
              _buildFeaturedProducts(),
              const SizedBox(height: 24),
              if (!_isGuest) ...[
                _buildRecentOrders(),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerHeader() {
    final avatar = GestureDetector(
      onTap: () => _onAuthenticatedTap(() {
        Navigator.push(
          context,
          _createFadeRoute(const ProfileScreen()),
        ).then((_) {
          if (mounted) setState(() => _selectedIndex = 0);
        });
      }),
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, color: Colors.grey[600], size: 22),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kumusta!',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.0,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  _isGuest ? 'Guest' : (_userName ?? 'Customer'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (_isGuest)
            TextButton(
              onPressed: () {
                showLoginDialog(
                  context,
                  onLoginSuccess: _refreshAfterLogin,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: Colors.white.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Login',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_isGuest) const SizedBox(width: 8),
          Consumer<BadgeProvider>(
            builder: (context, badges, _) {
              return _buildHeaderIconButton(
                iconWidget: SvgPicture.asset(
                  'assets/icons/Crate.svg',
                  height: 24,
                  fit: BoxFit.contain,
                ),
                onTap: _navigateToCart,
                badgeCount: _isGuest
                    ? null
                    : BadgeProvider.formatBadgeCount(badges.cartCount),
              );
            },
          ),
          const SizedBox(width: 12),
          Consumer<MessageProvider>(
            builder: (context, messages, _) {
              return _buildHeaderIconButton(
                iconWidget: SvgPicture.asset(
                  'assets/icons/chat.svg',
                  height: 24,
                  fit: BoxFit.contain,
                ),
                onTap: () => _onAuthenticatedTap(() {
                  final messagesProvider =
                      Provider.of<MessageProvider>(context, listen: false);
                  Navigator.push(
                    context,
                    _createFadeRoute(const MessagesScreen()),
                  ).then((_) {
                    if (!mounted || _isGuest) return;
                    messagesProvider.fetchUnreadCount();
                  });
                }),
                badgeCount: _isGuest
                    ? null
                    : BadgeProvider.formatBadgeCount(messages.unreadCount),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    IconData? icon,
    Widget? iconWidget,
    required VoidCallback onTap,
    String? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: iconWidget ?? Icon(icon, color: Colors.white, size: 24),
            ),
          ),
          if (badgeCount != null) _buildCountBadge(badgeCount),
        ],
      ),
    );
  }

  Widget _buildCountBadge(String count) {
    return Positioned(
      right: -8,
      top: -10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accentAmber,
          borderRadius: BorderRadius.circular(4),
        ),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Text(
          count,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: SizedBox(
        height: _heroBannerHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: 1.22,
              alignment: const Alignment(0, 0.4),
              child: Image.asset(
                'assets/images/farmer_image.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: _heroBannerHeight,
                alignment: const Alignment(0, -0.2),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: Colors.grey[500],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _heroBannerHeight * 0.3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryGreen.withOpacity(0.6),
                      Colors.transparent,
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

  // Widget _buildSearchBar() {
  //   return Container(
  //     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(color: Colors.grey[300]!),
  //     ),
  //     child: TextField(
  //       decoration: InputDecoration(
  //         hintText: 'Search for products...',
  //         border: InputBorder.none,
  //         prefixIcon: Icon(Icons.search, color: AppColors.primaryGreen),
  //         suffixIcon: Icon(Icons.filter_list, color: Colors.grey[600]),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildSearchBar() {
    return Consumer<ItemsProvider>(
      builder: (context, itemsProvider, child) {
        final isSearching = itemsProvider.isSearching;

        return Container(
          height: _searchBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: 'Search items or stores...',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 40, minHeight: 40),
              prefixIcon: isSearching
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    )
                  : Icon(Icons.search, color: Colors.grey[500], size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon:
                          Icon(Icons.clear, color: Colors.grey[600], size: 20),
                      onPressed: _clearSearch,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    )
                  : null,
            ),
            onTap: () {
              _scrollToPinSearchPanel();
              if (_searchController.text.trim().length >= 2) {
                setState(() => _showOverlay = true);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchOverlay() {
    const overlayRadius = 16.0;

    return Consumer<ItemsProvider>(
      builder: (context, itemsProvider, child) {
        final searchResults = itemsProvider.searchResults;
        final query = _searchController.text.trim();

        if (!_showOverlay || query.length < 2 || itemsProvider.isSearching) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: _searchOverlayTop,
          left: 16,
          right: 16,
          child: Material(
            elevation: 6,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(overlayRadius),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(overlayRadius),
              ),
              child: searchResults.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      child: Text(
                        'No results found for "$query"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: searchResults.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = searchResults[index];

                        final itemImages = product['item_images'];
                        final hasImage = itemImages != null &&
                            itemImages is List &&
                            (itemImages as List).isNotEmpty;
                        final imageUrl = hasImage
                            ? (itemImages as List).first.toString()
                            : null;

                        return ListTile(
                          leading: hasImage
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrl!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.shopping_bag,
                                            color: Colors.grey),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.shopping_bag,
                                      color: Colors.grey),
                                ),
                          title: Text(
                            product['item_name'] ?? 'Unknown Product',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _formatPrice(product['item_price']),
                            style: const TextStyle(
                              color: AppColors.primaryGreenDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            _clearSearch();
                            _searchFocus.unfocus();

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
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesSection() {
    if (_isLoadingCategories) {
      return const CategoryChipsSkeleton(padding: EdgeInsets.zero);
    }

    if (_categories.isEmpty) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_categoryError != null)
                IconButton(
                  icon: const Icon(Icons.refresh,
                      size: 20, color: AppColors.primaryGreen),
                  onPressed: _loadCategories,
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
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final itemsProvider = Provider.of<ItemsProvider>(context);
          final isSelected = itemsProvider.selectedCategoryId == category['id'];

          return Padding(
            padding: EdgeInsets.only(
              right: index < _categories.length - 1 ? 8 : 0,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  final categoryId = category['id'];
                  final categoryName = category['name'] ?? 'Category';

                  if (itemsProvider.selectedCategoryId == categoryId) {
                    itemsProvider.clearCategorySelection();
                    setState(() {
                      _selectedCategoryName = null;
                    });
                  } else {
                    setState(() {
                      _selectedCategoryName = categoryName;
                    });
                    itemsProvider.fetchItemsByCategory(categoryId);
                    _scrollToCategorySection();
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreen.withOpacity(0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : Colors.grey[200]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      category['name'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? AppColors.primaryGreen
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKlasrumSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/icons/klasrum-icon.svg',
              height: 20,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Text(
              'Learn with Kalsmeyt',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 280,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/manok.png',
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.8),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      const Text(
                        'Your First Gamefowl: A Complete Beginner\'s Guide',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Everything you need before raising your first rooster — housing, feeding, and health checks.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  _createFadeRoute(
                                    const CustomerPlaceholderScreen(
                                      title: 'Klasrum',
                                      icon: Icons.school_outlined,
                                      navIndex: CustomerNavIndex.klasrum,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  top: 8,
                                  bottom: 8,
                                  right: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Learn More',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accentAmber,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accentAmber,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          SvgPicture.asset(
                            'assets/icons/klasrum-wordmark.svg',
                            height: 14,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnSaleSection() {
    return Consumer<ItemsProvider>(
      builder: (context, itemsProvider, child) {
        final onSaleProducts = itemsProvider.onSaleItems;
        final isLoading = itemsProvider.isOnSaleLoading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/offers.svg',
                      height: 20,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Best Offer!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                  ],
                ),
                if (itemsProvider.onSaleError != null)
                  IconButton(
                    icon: Icon(Icons.refresh,
                        size: 20, color: AppColors.primaryGreen),
                    onPressed: _loadOnSaleProducts,
                    tooltip: 'Retry',
                  ),
              ],
            ),
            SizedBox(height: 16),
            if (isLoading)
              const ProductRowSkeleton(
                height: 288,
                cardWidth: 165,
                imageHeight: 130,
                padding: EdgeInsets.zero,
              )
            else if (onSaleProducts.isEmpty)
              Container(
                height: 175,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_offer_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No items on sale',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 288,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: onSaleProducts.length,
                  itemBuilder: (context, index) {
                    final product = onSaleProducts[index];
                    return Container(
                      width: 165,
                      margin: const EdgeInsets.only(right: 12),
                      child: _buildItemCard(product),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Featured Products',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            // TextButton(
            //   onPressed: () {
            //     // Handle view all
            //   },
            //   child: Text(
            //     'View All',
            //     style: TextStyle(
            //       color: AppColors.primaryGreen,
            //       fontWeight: FontWeight.w600,
            //     ),
            //   ),
            // ),
          ],
        ),
        SizedBox(height: 16),
        if (_isLoadingProducts)
          const ProductRowSkeleton(
            height: 250,
            cardWidth: 165,
            imageHeight: 130,
            padding: EdgeInsets.zero,
          )
        else if (_featuredProducts.isEmpty)
          Container(
            height: 160,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No products available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _featuredProducts.length,
              itemBuilder: (context, index) {
                final product = _featuredProducts[index];
                return Container(
                  width: 165,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildItemCard(product),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryItems() {
    return Consumer<ItemsProvider>(
      key: _categorySectionKey,
      builder: (context, itemsProvider, child) {
        final hasSelection = itemsProvider.selectedCategoryId != null;
        final categoryItems = itemsProvider.categoryItems;
        final isLoading = itemsProvider.isCategoryLoading;
        final error = itemsProvider.categoryError;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.12),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: !hasSelection
              ? const SizedBox.shrink(key: ValueKey('category-none'))
              : Column(
                  key: ValueKey('category-${itemsProvider.selectedCategoryId}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedCategoryName != null
                                ? '$_selectedCategoryName Products'
                                : 'Category Products',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              size: 20, color: Colors.grey[600]),
                          onPressed: () {
                            itemsProvider.clearCategorySelection();
                            setState(() {
                              _selectedCategoryName = null;
                            });
                          },
                          tooltip: 'Clear selection',
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    if (isLoading)
                      const ProductGridSkeleton(
                        count: 4,
                        imageHeight: 130,
                        padding: EdgeInsets.zero,
                      )
                    else if (error != null)
                      Container(
                        height: 200,
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: AppColors.error,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load products',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  if (itemsProvider.selectedCategoryId !=
                                      null) {
                                    itemsProvider.fetchItemsByCategory(
                                        itemsProvider.selectedCategoryId!);
                                  }
                                },
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (categoryItems.isEmpty)
                      Container(
                        height: 200,
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No products in this category',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
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
                        itemCount: categoryItems.length,
                        itemBuilder: (context, index) {
                          final product = categoryItems[index];
                          return _buildItemCard(product);
                        },
                      ),
                    SizedBox(height: 24),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSuggestedStores() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/near-stores.svg',
                  height: 20,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Text(
                  'Stores Near You',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
            if (_storeError != null)
              IconButton(
                icon: Icon(Icons.refresh,
                    size: 20, color: AppColors.primaryGreen),
                onPressed: () => _loadSuggestedStores(useCache: false),
                tooltip: 'Retry',
              )
          ],
        ),
        SizedBox(height: 16),
        if (_isLoadingStores)
          const StoreBannerSkeleton(height: 200, padding: EdgeInsets.zero)
        else if (_suggestedStores.isEmpty)
          Container(
            height: 140,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8),
                  Text(
                    _storeError != null
                        ? 'Failed to load stores'
                        : 'No stores available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _storePageController,
              itemCount: _suggestedStores.length,
              padEnds: false,
              onPageChanged: (index) {
                setState(() {
                  _currentStorePage = index;
                });
              },
              itemBuilder: (context, index) {
                final store = _suggestedStores[index];
                return Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: _buildStoreSlide(store),
                );
              },
            ),
          ),
          if (_suggestedStores.length > 1) ...[
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _suggestedStores.length,
                (index) {
                  final bool isActive = _currentStorePage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primaryGreen
                          : AppColors.primaryGreen.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildStoreSlide(Map<String, dynamic> store) {
    final shopRating = store['shop_rating'];
    final totalReviews = store['total_reviews'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed store background image
            Image.asset(
              'assets/images/store_sample.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  child: Icon(
                    Icons.store,
                    color: AppColors.primaryGreen,
                    size: 48,
                  ),
                );
              },
            ),
            // Gradient overlay for text legibility
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.75),
                  ],
                  stops: const [0.35, 0.6, 1.0],
                ),
              ),
            ),
            // Store info overlaid on the image
            Positioned(
              left: 18,
              right: 58,
              bottom: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Store name
                        Text(
                          store['shop_name'] ?? 'Unknown Store',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),
                        // Rating and reviews count
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 15,
                              color: AppColors.accentAmber,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _formatRating(shopRating),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Icon(
                              Icons.rate_review_outlined,
                              size: 15,
                              color: Colors.white.withOpacity(0.85),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '$totalReviews reviews',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Tap layer
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.push(
                      context,
                      _createFadeRoute(
                        ShopScreen(
                          shopId: store['id'],
                          shopName: store['shop_name'],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Message store button (above tap layer)
            Positioned(
              right: 18,
              bottom: 18,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _onAuthenticatedTap(() {
                    Navigator.push(
                      context,
                      _createFadeRoute(
                        ConversationScreen(
                          shopId: store['id'],
                          shopName: store['shop_name']?.toString(),
                        ),
                      ),
                    );
                  }),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/chat.svg',
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
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

  Widget _buildRecentOrders() {
    if (_isGuest) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/buy-again.svg',
                  width: 20,
                  height: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Buy Again!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
            if (_buyAgainError != null)
              IconButton(
                icon: Icon(Icons.refresh,
                    size: 20, color: AppColors.primaryGreen),
                onPressed: _loadBuyAgainProducts,
                tooltip: 'Retry',
              )
            else
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    _createFadeRoute(MyOrderScreen()),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        if (_isLoadingBuyAgain)
          const ProductRowSkeleton(
            height: 250,
            cardWidth: 165,
            imageHeight: 130,
            padding: EdgeInsets.zero,
          )
        else if (_buyAgainProducts.isEmpty)
          Container(
            height: 160,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8),
                  Text(
                    _buyAgainError != null
                        ? 'Failed to load items'
                        : 'No items to buy again',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _buyAgainProducts.length,
              itemBuilder: (context, index) {
                final product = _buyAgainProducts[index];
                return Container(
                  width: 165,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildItemCard(product),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return buildCustomerBottomNavigationBar(
      context: context,
      currentIndex: CustomerNavIndex.home,
      isGuest: _isGuest,
      onLoginSuccess: _refreshAfterLogin,
    );
  }
}

/// A single collapsing header that keeps the green app bar pinned at the top,
/// lets the hero banner scroll away (with slight parallax), and floats the
/// search bar over the hero's bottom edge before pinning it (with the category
/// chips tucked beneath) under the header as the user scrolls.
class _CollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CollapsingHeaderDelegate({
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.headerHeight,
    required this.heroHeight,
    required this.searchBarHeight,
    required this.searchBarWidthFactor,
    required this.searchOverlap,
    required this.searchTopGap,
    required this.searchCategoriesGap,
    required this.categoriesHeight,
    required this.categoriesBottomPad,
    required this.fadeHeight,
    required this.backgroundColor,
    required this.header,
    required this.hero,
    required this.searchBar,
    required this.categories,
  });

  final double minExtentValue;
  final double maxExtentValue;
  final double headerHeight;
  final double heroHeight;
  final double searchBarHeight;
  final double searchBarWidthFactor;
  final double searchOverlap;
  final double searchTopGap;
  final double searchCategoriesGap;
  final double categoriesHeight;
  final double categoriesBottomPad;
  final double fadeHeight;
  final Color backgroundColor;
  final Widget header;
  final Widget hero;
  final Widget searchBar;
  final Widget categories;

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtentValue - minExtentValue;
    final shrink = shrinkOffset.clamp(0.0, range);

    // Hero scrolls up a touch faster so it fully clears the search bar by the
    // time the header is pinned.
    final parallax = range > 0 ? heroHeight / range : 0.0;
    final heroTop = headerHeight - parallax * shrink;

    // Search bar starts centered on the hero's bottom edge, then rises until it
    // rests just below the green header.
    final searchTop = (headerHeight + heroHeight - searchOverlap - shrink)
        .clamp(headerHeight + searchTopGap, double.infinity);
    final categoriesTop = searchTop + searchBarHeight + searchCategoriesGap;
    final fadeTop = categoriesTop + categoriesHeight + categoriesBottomPad;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Opaque background hides below-fold content scrolling under the header
        // (everything except the soft fade strip at the bottom).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: fadeTop,
          child: ColoredBox(color: backgroundColor),
        ),
        // Hero banner (full width, parallax upward).
        Positioned(
          top: heroTop,
          left: 0,
          right: 0,
          height: heroHeight,
          child: hero,
        ),
        // Soft fade so content dissolves under the chips.
        Positioned(
          top: fadeTop,
          left: 0,
          right: 0,
          height: fadeHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  backgroundColor,
                  backgroundColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Category chips tucked beneath the search bar.
        Positioned(
          top: categoriesTop,
          left: 16,
          right: 16,
          height: categoriesHeight,
          child: categories,
        ),
        // Floating search bar (90% width, centered).
        Positioned(
          top: searchTop,
          left: 0,
          right: 0,
          height: searchBarHeight,
          child: Center(
            child: FractionallySizedBox(
              widthFactor: searchBarWidthFactor,
              child: searchBar,
            ),
          ),
        ),
        // Green app bar, always on top so the hero disappears beneath it.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: headerHeight,
          child: ColoredBox(
            color: AppColors.primaryGreenDark,
            child: header,
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _CollapsingHeaderDelegate oldDelegate) {
    return minExtentValue != oldDelegate.minExtentValue ||
        maxExtentValue != oldDelegate.maxExtentValue ||
        header != oldDelegate.header ||
        hero != oldDelegate.hero ||
        searchBar != oldDelegate.searchBar ||
        categories != oldDelegate.categories;
  }
}
