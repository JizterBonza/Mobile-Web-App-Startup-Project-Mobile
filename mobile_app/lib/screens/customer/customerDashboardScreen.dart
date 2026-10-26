import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../constants/constants.dart';
import '../../services/api_service.dart';
import '../../services/farms_service.dart';
import '../../services/favorite_services.dart';
import '../../provider/provider.dart';
import '../../utils/auth_guard.dart';
import '../../utils/customer_nav.dart';
import '../../utils/gamefowl_item.dart';
import '../../widgets/login_dialog.dart';
import '../../widgets/user_profile_avatar.dart';

import 'messagesScreen.dart';
import 'conversationScreen.dart';
import 'cartScreenV2.dart';
import '../common/profileScreen.dart';
import 'klasrumScreen.dart';
import 'shopScreen.dart';
import 'farmDetailsScreen.dart';
import 'gamefowlProdDetail.dart';
import 'productDetailScreen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  String? _userName;
  String? _profileImageUrl;
  bool _isGuest = true;

  bool _isLoadingKlasrum = true;

  List<Map<String, dynamic>> _suggestedStores = [];
  bool _isLoadingStores = true;
  String? _storeError;

  final FarmsService _farmsService = FarmsService();
  List<Map<String, dynamic>> _farms = [];
  bool _isLoadingFarms = true;
  String? _farmError;
  String? _openingFarmChatId;

  bool _isLoadingProducts = true;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];

  final PageController _storesPageController =
      PageController(viewportFraction: 0.84);

  final PageController _farmsPageController =
      PageController(viewportFraction: 0.84);

  int _currentStorePage = 0;
  int _currentFarmPage = 0;

  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocus = FocusNode();

  Timer? _debounceTimer;

  bool _showSearchResults = false;

  String _selectedCategory = 'All';
  dynamic _selectedCategoryId;

  final GlobalKey _productsSectionKey = GlobalKey();

  // FAVORITES
  final FavoriteService _favoriteService = FavoriteService();

  final Set<String> _favoriteProductIds = <String>{};

  final Map<String, String> _favoriteRecordIds = <String, String>{};

  final Set<String> _favoriteCardKeys = <String>{};

  final Map<String, String> _favoriteCardProductIds = <String, String>{};

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF1A2A5D),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  Future<void> _initializeDashboard() async {
    await Future.wait([
      _loadUserName(),
      _loadSuggestedStores(),
      _loadFarms(),
      _loadKlasrumFeatured(),
      _loadProducts(),
      _loadCategories(),
      _loadFavoriteState(),
    ]);

    _applyInitialFavoriteCardStates();
  }

  Future<void> _loadUserName() async {
    try {
      final token = await ApiService.getToken();
      final name = await ApiService.getUserName();

      final isGuest = token == null || token.isEmpty;

      String? profileImageUrl;

      if (!isGuest) {
        profileImageUrl = await ApiService.getProfileImageUrl();
      }

      if (!mounted) return;

      setState(() {
        _userName = name;
        _isGuest = isGuest;
        _profileImageUrl = profileImageUrl;
      });

      if (!_isGuest) {
        await _fetchBadges();
        await _fetchMessageUnread();
      } else {
        _clearBadges();
      }
    } catch (e) {
      debugPrint(
        'Error loading user name: $e',
      );

      if (!mounted) return;

      try {
        final token = await ApiService.getToken();

        setState(() {
          _isGuest = token == null || token.isEmpty;

          if (_isGuest) {
            _profileImageUrl = null;
          }
        });
      } catch (_) {
        if (!mounted) return;

        setState(() {
          _isGuest = true;
          _profileImageUrl = null;
        });
      }
    }
  }

  Future<void> _refreshAfterLogin() async {
    await _loadUserName();
    await _loadFavoriteState();

    if (!_isGuest) {
      await _fetchBadges();
      await _fetchMessageUnread();
    }

    _applyInitialFavoriteCardStates();
  }

  Future<void> _fetchBadges() async {
    if (!mounted) return;

    await Provider.of<BadgeProvider>(
      context,
      listen: false,
    ).fetchBadges();
  }

  Future<void> _fetchMessageUnread() async {
    if (!mounted) return;

    final messages = Provider.of<MessageProvider>(
      context,
      listen: false,
    );

    await messages.fetchUnreadCount();
    messages.startLiveUpdates();
  }

  void _clearBadges() {
    if (!mounted) return;

    Provider.of<BadgeProvider>(
      context,
      listen: false,
    ).clear();

    Provider.of<MessageProvider>(
      context,
      listen: false,
    ).clear();
  }

  // FAVORITES
  Future<void> _loadFavoriteState() async {
    try {
      final token = await ApiService.getToken();

      if (token == null || token.isEmpty) {
        if (!mounted) return;

        setState(() {
          _favoriteProductIds.clear();
          _favoriteRecordIds.clear();
          _favoriteCardKeys.clear();
          _favoriteCardProductIds.clear();
        });

        return;
      }

      final userId = await ApiService.getUserId();

      if (userId == null || userId.isEmpty) {
        return;
      }

      final favorites = await _favoriteService.fetchFavoritesFromAPI(userId);

      final favoriteProductIds = <String>{};
      final favoriteRecordIds = <String, String>{};

      for (final favorite in favorites) {
        final itemId = favorite['item_id'];
        final favoriteId = favorite['id'];

        if (itemId != null) {
          final itemIdString = itemId.toString();

          favoriteProductIds.add(itemIdString);

          if (favoriteId != null) {
            favoriteRecordIds[itemIdString] = favoriteId.toString();
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _favoriteProductIds
          ..clear()
          ..addAll(favoriteProductIds);

        _favoriteRecordIds
          ..clear()
          ..addAll(favoriteRecordIds);
      });
    } catch (e) {
      debugPrint(
        'Error loading favorites: $e',
      );
    }
  }

  bool _isProductFavorite(
    dynamic productId,
  ) {
    if (productId == null) {
      return false;
    }

    return _favoriteProductIds.contains(
      productId.toString(),
    );
  }

  String _getFavoriteCardKey(
    String section,
    int index,
  ) {
    return '$section:$index';
  }

  void _applyInitialFavoriteCardStates() {
    if (!mounted) return;

    final newFavoriteCardKeys = <String>{};
    final newFavoriteCardProductIds = <String, String>{};

    final alreadyAssignedProducts = <String>{};

    void registerSection(
      String section,
      List<Map<String, dynamic>> products,
    ) {
      for (int index = 0; index < products.length; index++) {
        final product = products[index];

        final productId = product['id'] ?? product['item_id'];

        if (productId == null) {
          continue;
        }

        final itemId = productId.toString();

        if (!_favoriteProductIds.contains(itemId)) {
          continue;
        }

        if (alreadyAssignedProducts.contains(itemId)) {
          continue;
        }

        final cardKey = _getFavoriteCardKey(
          section,
          index,
        );

        alreadyAssignedProducts.add(itemId);
        newFavoriteCardKeys.add(cardKey);
        newFavoriteCardProductIds[cardKey] = itemId;
      }
    }

    final filteredProducts = _getFilteredProducts();

    registerSection(
      'best_offers',
      filteredProducts.take(6).toList(),
    );

    registerSection(
      'featured',
      filteredProducts.take(4).toList(),
    );

    registerSection(
      'products',
      filteredProducts.take(6).toList(),
    );

    final gamefowl = _products.where(_isGamefowlProduct).take(6).toList();

    registerSection(
      'gamefowl',
      gamefowl,
    );

    final buyAgain = filteredProducts
        .skip(
          filteredProducts.length > 6 ? 6 : 0,
        )
        .take(6)
        .toList();

    registerSection(
      'buy_again',
      buyAgain,
    );

    setState(() {
      _favoriteCardKeys
        ..clear()
        ..addAll(newFavoriteCardKeys);

      _favoriteCardProductIds
        ..clear()
        ..addAll(newFavoriteCardProductIds);
    });
  }

  Future<void> _toggleProductFavorite(
    Map<String, dynamic> product, {
    String? favoriteCardKey,
  }) async {
    if (_isGuest) {
      showLoginDialog(
        context,
        onLoginSuccess: () async {
          await _refreshAfterLogin();
        },
      );
      return;
    }

    final productId = product['id'] ?? product['item_id'];

    if (productId == null) {
      return;
    }

    final itemId = productId.toString();

    final isCardFavorite = favoriteCardKey != null
        ? _favoriteCardKeys.contains(
            favoriteCardKey,
          )
        : _favoriteProductIds.contains(
            itemId,
          );

    if (isCardFavorite) {
      if (favoriteCardKey != null) {
        setState(() {
          _favoriteCardKeys.remove(
            favoriteCardKey,
          );

          _favoriteCardProductIds.remove(
            favoriteCardKey,
          );
        });
      }

      final anotherCardUsesProduct = _favoriteCardProductIds.entries.any(
        (entry) => entry.value == itemId && entry.key != favoriteCardKey,
      );

      if (anotherCardUsesProduct) {
        return;
      }

      final favoriteRecordId = _favoriteRecordIds[itemId];

      if (favoriteRecordId == null) {
        await _loadFavoriteState();
        return;
      }

      try {
        final result = await _favoriteService.removeFromFavorites(
          favoriteRecordId,
        );

        if (!mounted) return;

        if (result['success'] == true) {
          setState(() {
            _favoriteProductIds.remove(itemId);
            _favoriteRecordIds.remove(itemId);
          });

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Removed from favorites'),
                duration: Duration(seconds: 2),
              ),
            );
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  result['message'] ?? 'Failed to remove from favorites',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Error removing favorite: $e',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
      }

      return;
    }

    if (favoriteCardKey != null) {
      setState(() {
        _favoriteCardKeys.add(
          favoriteCardKey,
        );

        _favoriteCardProductIds[favoriteCardKey] = itemId;
      });
    }

    if (_favoriteProductIds.contains(itemId)) {
      return;
    }

    try {
      final userId = await ApiService.getUserId();

      if (userId == null || userId.isEmpty) {
        if (!mounted) return;

        if (favoriteCardKey != null) {
          setState(() {
            _favoriteCardKeys.remove(
              favoriteCardKey,
            );

            _favoriteCardProductIds.remove(
              favoriteCardKey,
            );
          });
        }

        showLoginDialog(
          context,
          onLoginSuccess: () async {
            await _refreshAfterLogin();
          },
        );

        return;
      }

      final result = await _favoriteService.addToFavorites(
        userId: userId,
        itemId: itemId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _favoriteProductIds.add(itemId);
        });

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Added to favorites'),
              duration: Duration(seconds: 2),
            ),
          );
      } else {
        if (favoriteCardKey != null) {
          setState(() {
            _favoriteCardKeys.remove(
              favoriteCardKey,
            );

            _favoriteCardProductIds.remove(
              favoriteCardKey,
            );
          });
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Failed to add to favorites',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;

      if (favoriteCardKey != null) {
        setState(() {
          _favoriteCardKeys.remove(
            favoriteCardKey,
          );

          _favoriteCardProductIds.remove(
            favoriteCardKey,
          );
        });
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Error adding favorite: $e',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _loadKlasrumFeatured() async {
    if (!mounted) return;

    setState(() {
      _isLoadingKlasrum = true;
    });

    try {
      final provider = Provider.of<KlasrumProvider>(
        context,
        listen: false,
      );

      await provider.fetchFeatured();
    } catch (e) {
      debugPrint(
        'Error loading Klasrum: $e',
      );
    }

    if (!mounted) return;

    setState(() {
      _isLoadingKlasrum = false;
    });
  }

  Future<void> _loadSuggestedStores({
    bool useCache = true,
  }) async {
    if (!mounted) return;

    setState(() {
      _isLoadingStores = true;
      _storeError = null;
    });

    try {
      final shopsProvider = Provider.of<ShopsProvider>(
        context,
        listen: false,
      );

      await shopsProvider.fetchShops(
        useCache: useCache,
        limit: 6,
      );

      if (!mounted) return;

      setState(() {
        _suggestedStores = shopsProvider.shops;
        _isLoadingStores = shopsProvider.isLoading;
        _storeError = shopsProvider.error;
      });
    } catch (e) {
      debugPrint(
        'Error loading stores: $e',
      );

      if (!mounted) return;

      setState(() {
        _suggestedStores = [];
        _isLoadingStores = false;
        _storeError = e.toString();
      });
    }
  }

  Future<void> _loadFarms() async {
    if (!mounted) return;

    setState(() {
      _isLoadingFarms = true;
      _farmError = null;
    });

    try {
      final farms = await _farmsService.fetchFarms();
      if (!mounted) return;

      final resetPage = _currentFarmPage >= farms.length;
      setState(() {
        _farms = farms;
        _isLoadingFarms = false;
        if (resetPage) _currentFarmPage = 0;
      });
      if (resetPage && _farmsPageController.hasClients) {
        _farmsPageController.jumpToPage(0);
      }
    } catch (e) {
      debugPrint('Error loading farms: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingFarms = false;
        _farmError = e.toString();
      });
    }
  }

  Future<void> _loadProducts({
    bool useCache = true,
  }) async {
    if (!mounted) return;

    setState(() {
      _isLoadingProducts = true;
    });

    try {
      final itemsProvider = Provider.of<ItemsProvider>(
        context,
        listen: false,
      );

      await itemsProvider.fetchItems(
        useCache: useCache,
      );

      if (!mounted) return;

      final loadedItems = List<Map<String, dynamic>>.from(
        itemsProvider.items,
      );

      setState(() {
        _products = loadedItems;
        _isLoadingProducts = false;
      });
    } catch (e) {
      debugPrint(
        'Error loading products: $e',
      );

      if (!mounted) return;

      setState(() {
        _products = [];
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    final provider = context.read<CategoryProvider>();
    await provider.fetchCategories();
    if (!mounted) return;
    setState(() {
      _categories = provider.categories
          .where((category) => !isGamefowlItem({
                'category_name': category['name'],
              }))
          .toList();
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    _debounceTimer?.cancel();

    if (query.isEmpty || query.length < 2) {
      if (mounted) {
        setState(() {
          _showSearchResults = false;
        });
      }

      Provider.of<ItemsProvider>(
        context,
        listen: false,
      ).clearSearch();

      return;
    }

    _debounceTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        _performSearch(query);
      },
    );
  }

  Future<void> _performSearch(
    String query,
  ) async {
    if (!mounted) return;

    final itemsProvider = Provider.of<ItemsProvider>(
      context,
      listen: false,
    );

    await itemsProvider.searchItems(query);

    if (!mounted) return;

    setState(() {
      _showSearchResults = query.length >= 2;
    });
  }

  void _clearSearch() {
    _searchController.clear();

    Provider.of<ItemsProvider>(
      context,
      listen: false,
    ).clearSearch();

    if (!mounted) return;

    setState(() {
      _showSearchResults = false;
    });
  }

  void _onAuthenticatedTap(
    VoidCallback action,
  ) {
    if (!requireAuthOrShowLogin(
      context,
      isGuest: _isGuest,
    )) {
      return;
    }

    action();
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
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 160),
      reverseTransitionDuration: const Duration(milliseconds: 160),
    );
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
      _createFadeRoute(
        CartScreenV2(),
      ),
    ).then((_) {
      if (!mounted) return;
      _fetchBadges();
    });
  }

  void _openProfile() {
    _onAuthenticatedTap(() {
      Navigator.push(
        context,
        _createFadeRoute(
          const ProfileScreen(),
        ),
      ).then((_) {
        if (!mounted) return;
        _loadUserName();
      });
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadUserName(),
      _loadSuggestedStores(
        useCache: false,
      ),
      _loadFarms(),
      _loadKlasrumFeatured(),
      _loadProducts(
        useCache: false,
      ),
      _loadCategories(),
      _loadFavoriteState(),
    ]);

    _applyInitialFavoriteCardStates();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF27489A),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFFF7F7F7),
        body: Column(
          children: [
            _buildFixedHeader(),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: AppColors.brandPrimary,
                    onRefresh: _onRefresh,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _RoosterCoverHeaderDelegate(
                            searchWidget: _buildSearchBar(),
                            categoriesWidget: _buildCategoryButtons(),
                            cover: _buildRoosterCover(),
                            maxHeight: 324,
                            minHeight: 112,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 18,
                            ),
                            child: _buildHomeSections(),
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(
                            height: 120,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showSearchResults) _buildSearchResultsOverlay(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: _buildBottomNavigationBar(),
        ),
      ),
    );
  }

  Widget _buildFixedHeader() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: 76 + topPadding,
      padding: EdgeInsets.only(
        top: topPadding,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A2A5D),
            Color(0xFF203A78),
            Color(0xFF294A91),
          ],
          stops: [
            0.0,
            0.55,
            1.0,
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: 10,
          ),
          child: _buildUserHeader(),
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _openProfile,
          child: UserProfileAvatar(
            size: 42,
            imageUrl: _isGuest ? null : _profileImageUrl,
            backgroundColor: Colors.white,
            iconColor: Colors.grey.shade600,
            iconSize: 23,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kumusta!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
              Text(
                _isGuest ? 'Guest' : (_userName ?? 'Customer'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Consumer<BadgeProvider>(
          builder: (
            context,
            badges,
            child,
          ) {
            return _buildHeaderAction(
              iconWidget: SvgPicture.asset(
                'assets/icons/Crate.svg',
                width: 25,
                height: 25,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              badgeCount: _isGuest
                  ? null
                  : BadgeProvider.formatBadgeCount(
                      badges.cartCount,
                    ),
              onTap: _navigateToCart,
            );
          },
        ),
        const SizedBox(width: 14),
        Consumer<MessageProvider>(
          builder: (
            context,
            messages,
            child,
          ) {
            return _buildHeaderAction(
              iconWidget: SvgPicture.asset(
                'assets/icons/chat.svg',
                width: 25,
                height: 25,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              badgeCount: _isGuest
                  ? null
                  : BadgeProvider.formatBadgeCount(
                      messages.unreadCount,
                    ),
              onTap: () {
                _onAuthenticatedTap(
                  () {
                    Navigator.push(
                      context,
                      _createFadeRoute(
                        const MessagesScreen(),
                      ),
                    ).then((_) {
                      if (!mounted || _isGuest) {
                        return;
                      }
                      Provider.of<MessageProvider>(
                        context,
                        listen: false,
                      ).fetchUnreadCount();
                    });
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeaderAction({
    required Widget iconWidget,
    required VoidCallback onTap,
    String? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: iconWidget,
            ),
          ),
          if (badgeCount != null)
            Positioned(
              right: -6,
              top: -7,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 15,
                  minHeight: 15,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white,
                    width: 1,
                  ),
                ),
                child: Text(
                  badgeCount,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoosterCover() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: SizedBox(
        height: 280,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/cover.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return Container(
                  color: const Color(0xFF3155B7),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.65),
                    ],
                    stops: const [
                      0.0,
                      0.40,
                      0.72,
                      1.0,
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

  Widget _buildStickySearchAndCategories() {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: const Color(0xFFF7F7F7),
        padding: const EdgeInsets.only(
          top: 6,
          bottom: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
              ),
              child: _buildSearchBar(),
            ),
            const SizedBox(height: 8),
            _buildCategoryButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStickySearchOnly() {
    return _buildStickySearchAndCategories();
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
          ),
          hintText: 'Search items or store...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 10,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 17,
            color: Colors.grey.shade500,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 35,
                    minHeight: 35,
                  ),
                  icon: Icon(
                    Icons.close,
                    size: 15,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: _clearSearch,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildCategoryButtons() {
    final categories = <Map<String, dynamic>>[
      {'id': null, 'name': 'All'},
      ..._categories,
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
        ),
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (
          context,
          index,
        ) =>
            const SizedBox(width: 7),
        itemBuilder: (
          context,
          index,
        ) {
          final category = categories[index];
          final categoryName = category['name']?.toString() ?? 'Category';

          final isSelected =
              _selectedCategoryId?.toString() == category['id']?.toString();

          return GestureDetector(
            onTap: () => _selectCategory(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF3155B7)
                    : const Color(0xFFE8EEFC),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                categoryName,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF3155B7),
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectCategory(Map<String, dynamic> category) async {
    if (!mounted) return;

    final id = category['id'];
    setState(() {
      _selectedCategoryId = id;
      _selectedCategory = category['name']?.toString() ?? 'All';
    });

    final itemsProvider = context.read<ItemsProvider>();
    if (id == null) {
      itemsProvider.clearCategorySelection();
    } else {
      await itemsProvider.fetchItemsByCategory(id);
      if (!mounted || _selectedCategoryId?.toString() != id.toString()) {
        return;
      }
      setState(() {});
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;

        final targetContext = _productsSectionKey.currentContext;

        if (targetContext == null) {
          return;
        }

        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          alignment: 0.05,
        );
      },
    );
  }

  Widget _buildHomeSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKlasrumSection(),
        const SizedBox(height: 22),
        _buildStoresSection(),
        const SizedBox(height: 22),
        _buildLocalFarmsSection(),
        const SizedBox(height: 22),
        _buildBestOffersSection(),
        const SizedBox(height: 22),
        _buildFeaturedProductsSection(),
        const SizedBox(height: 24),
        Container(
          key: _productsSectionKey,
          child: _buildProductsSection(),
        ),
        const SizedBox(height: 24),
        _buildAvailableGamefowlSection(),
        const SizedBox(height: 24),
        _buildBuyAgainSection(),
      ],
    );
  }

  Widget _buildKlasrumSection() {
    return Consumer<KlasrumProvider>(
      builder: (
        context,
        provider,
        child,
      ) {
        final featured = provider.featuredContent;

        final title = featured?['title']?.toString().trim();

        final description = featured?['description']?.toString().trim();

        final coverUrl = _getImageUrl(
          featured,
          [
            'cover_url',
            'cover_photo',
            'cover_image',
            'banner_url',
            'image_url',
            'image',
          ],
        );

        final displayTitle = title != null && title.isNotEmpty
            ? title
            : 'Your First Gamefowl: A Complete Beginner\'s Guide';

        final displayDescription = description != null && description.isNotEmpty
            ? description
            : 'Everything you need before raising your first rooster — housing, feeding, and health checks.';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              title: 'Learn with Klasmeyt',
              iconPath: 'assets/icons/klasrum-icon.svg',
              iconColor: const Color(0xFF334FA1),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              child: _buildKlasrumCard(
                title: displayTitle,
                description: displayDescription,
                coverUrl: coverUrl,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKlasrumCard({
    required String title,
    required String description,
    String? coverUrl,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          _createFadeRoute(
            const KlasrumScreen(),
          ),
        );
      },
      child: Container(
        height: 172,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildNetworkOrAssetImage(
                coverUrl,
                fallback: 'assets/images/manok.png',
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.12),
                        Colors.black.withOpacity(0.82),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 95,
                bottom: 47,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 85,
                bottom: 25,
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.90),
                    fontSize: 8.5,
                    height: 1.1,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 8,
                child: Container(
                  height: 31,
                  padding: const EdgeInsets.only(
                    left: 11,
                    right: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Learn More',
                        style: TextStyle(
                          color: Color(0xFF684F00),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 23,
                        height: 23,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB900),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right,
                          size: 17,
                          color: Colors.white,
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

  Widget _buildSectionTitle({
    required String title,
    required String iconPath,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            iconPath,
            width: 19,
            height: 19,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(
              iconColor,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF242424),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoresSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Stores Near You',
          iconPath: 'assets/icons/near-stores.svg',
          iconColor: const Color(0xFF4D9D45),
        ),
        const SizedBox(height: 10),
        if (_isLoadingStores)
          _buildStoreLoading()
        else if (_suggestedStores.isEmpty)
          _buildEmptyStoreState()
        else
          Column(
            children: [
              _buildStoreCarousel(
                controller: _storesPageController,
                onPageChanged: (index) {
                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    _currentStorePage = index;
                  });
                },
              ),
              const SizedBox(height: 8),
              _buildCarouselIndicator(
                currentIndex: _currentStorePage,
              ),
            ],
          ),
      ],
    );
  }

  // ============================================================
  // LOCAL FARMS
  // ============================================================

  Widget _buildLocalFarmsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Local Farms',
          iconPath: 'assets/icons/near-stores.svg',
          iconColor: const Color(0xFF4D9D45),
        ),
        const SizedBox(height: 10),
        if (_isLoadingFarms && _farms.isEmpty)
          _buildStoreLoading()
        else if (_farms.isEmpty)
          _buildFarmEmptyState()
        else
          Column(
            children: [
              SizedBox(
                height: 184,
                child: PageView.builder(
                  controller: _farmsPageController,
                  padEnds: false,
                  itemCount: _farms.length,
                  onPageChanged: (index) {
                    if (!mounted) return;
                    setState(() => _currentFarmPage = index);
                  },
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildFarmCard(_farms[index]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildLocalFarmCarouselIndicator(
                currentIndex: _currentFarmPage,
                itemCount: _farms.length,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFarmEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _farmError == null ? 'No farms available' : 'Failed to load farms',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildFarmCard(Map<String, dynamic> farm) {
    final farmId = farm['id'];
    final name = farm['name']?.toString().trim();
    final city = farm['city']?.toString().trim() ?? '';
    final province = farm['province']?.toString().trim() ?? '';
    final location =
        [city, province].where((part) => part.isNotEmpty).join(', ');
    final address = farm['address']?.toString().trim() ?? '';
    final imageUrl = _getImageUrl(farm, [
      'cover_url',
      'banner_url',
      'logo_url',
    ]);

    return GestureDetector(
      onTap: farmId == null
          ? null
          : () => Navigator.push(
                context,
                _createFadeRoute(FarmDetailsScreen(
                  farmId: farmId,
                  farmName: name,
                )),
              ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildNetworkOrAssetImage(
                imageUrl,
                fallback: 'assets/images/farmer_image.png',
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.10),
                      Colors.black.withOpacity(0.80),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 70,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name == null || name.isEmpty ? 'Unnamed Farm' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (location.isNotEmpty || address.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.white, size: 10),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              location.isNotEmpty ? location : address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: GestureDetector(
                  onTap: farmId == null || _openingFarmChatId != null
                      ? null
                      : () => _onAuthenticatedTap(
                            () => _openFarmConversation(
                              farmId,
                              name == null || name.isEmpty ? 'Farm' : name,
                            ),
                          ),
                  child: Container(
                    height: 31,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3155C5),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_openingFarmChatId == farmId?.toString())
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          SvgPicture.asset(
                            'assets/icons/chat.svg',
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        const SizedBox(width: 5),
                        const Text(
                          'Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFarmConversation(dynamic farmId, String farmName) async {
    if (_openingFarmChatId != null) return;
    setState(() => _openingFarmChatId = farmId.toString());
    final provider = Provider.of<MessageProvider>(context, listen: false);
    final success = await provider.startOrResumeFarmConversation(
      farmId: farmId,
      farmName: farmName,
    );
    if (!mounted) return;
    final conversationId = provider.activeThread?.conversation.id;
    if (!success || conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ?? 'Failed to start farm chat'),
      ));
      setState(() => _openingFarmChatId = null);
      return;
    }
    await Navigator.push(
      context,
      _createFadeRoute(ConversationScreen(
        conversationId: conversationId,
        farmId: farmId,
        shopName: farmName,
      )),
    );
    if (mounted) setState(() => _openingFarmChatId = null);
  }

  Widget _buildLocalFarmCarouselIndicator({
    required int currentIndex,
    required int itemCount,
  }) {
    if (itemCount <= 1) {
      return const SizedBox(
        height: 5,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
        (index) {
          final active = currentIndex == index;

          return AnimatedContainer(
            duration: const Duration(
              milliseconds: 220,
            ),
            margin: const EdgeInsets.symmetric(
              horizontal: 2,
            ),
            width: active ? 25 : 6,
            height: 5,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF496BC1) : const Color(0xFFD1D4DC),
              borderRadius: BorderRadius.circular(5),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoreCarousel({
    required PageController controller,
    required ValueChanged<int> onPageChanged,
  }) {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: controller,
        padEnds: false,
        itemCount: _suggestedStores.length,
        onPageChanged: onPageChanged,
        itemBuilder: (
          context,
          index,
        ) {
          return Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
            ),
            child: _buildStoreCard(
              _suggestedStores[index],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    final bannerUrl = _getImageUrl(
      store,
      [
        'rooster_photo',
        'roster_photo',
        'rooster_image',
        'roster_image',
        'rooster_photo_url',
        'roster_image_url',
        'roster',
        'rooster',
        'shop_banner',
        'cover_photo',
        'cover_image',
        'banner_url',
        'banner',
        'farm_image',
        'shop_image',
        'image_url',
        'image',
        'shop_logo',
      ],
    );

    final shopName = (store['shop_name'] ??
            store['farm_name'] ??
            store['name'] ??
            'Unknown Store')
        .toString();

    final rating = _formatRating(
      store['shop_rating'] ?? store['rating'],
    );

    final distance =
        (store['distance'] ?? store['distance_km'] ?? '2.1').toString();

    final shopId = store['id'] ?? store['shop_id'];

    return GestureDetector(
      onTap: () {
        if (shopId == null) {
          return;
        }

        Navigator.push(
          context,
          _createFadeRoute(
            ShopScreen(
              shopId: shopId,
              shopName: shopName,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildNetworkOrAssetImage(
                bannerUrl,
                fallback: 'assets/images/store_sample.png',
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.10),
                        Colors.black.withOpacity(0.80),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 8,
                right: 9,
                child: Icon(
                  Icons.more_horiz,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              Positioned(
                left: 12,
                right: 70,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 9,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$distance km away',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 9,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          rating,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: GestureDetector(
                  onTap: () {
                    if (shopId == null) {
                      return;
                    }

                    _onAuthenticatedTap(
                      () {
                        Navigator.push(
                          context,
                          _createFadeRoute(
                            ConversationScreen(
                              shopId: shopId,
                              shopName: shopName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    height: 31,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3155C5),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/chat.svg',
                          width: 14,
                          height: 14,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBestOffersSection() {
    if (_isLoadingDisplayedProducts) {
      return _buildProductLoading(
        'Best Offers',
      );
    }

    final products = _getFilteredProducts();

    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: Text(
            'Best Offers',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF242424),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildHorizontalProducts(
          products.take(6).toList(),
          sectionKey: 'best_offers',
        ),
      ],
    );
  }

  Widget _buildFeaturedProductsSection() {
    if (_isLoadingDisplayedProducts) {
      return _buildProductLoading(
        'Featured Products',
      );
    }

    final products = _getFilteredProducts();

    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: Text(
            'Featured Products',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF242424),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildHorizontalProducts(
          products.take(4).toList(),
          sectionKey: 'featured',
        ),
      ],
    );
  }

  Widget _buildProductsSection() {
    if (_isLoadingDisplayedProducts) {
      return _buildProductLoading(
        'Products',
      );
    }

    final products = _getFilteredProducts();

    if (products.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Text(
              'Products',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF242424),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'No products found for $_selectedCategory.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: Text(
            _selectedCategory == 'All'
                ? 'Products'
                : '$_selectedCategory Products',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF242424),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildHorizontalProducts(
          products.take(6).toList(),
          sectionKey: 'products',
        ),
      ],
    );
  }

  Widget _buildHorizontalProducts(
    List<Map<String, dynamic>> products, {
    required String sectionKey,
  }) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        itemCount: products.length,
        itemBuilder: (
          context,
          index,
        ) {
          final cardKey = _getFavoriteCardKey(
            sectionKey,
            index,
          );

          return Padding(
            padding: const EdgeInsets.only(
              right: 12,
            ),
            child: _buildProductCard(
              products[index],
              favoriteCardKey: cardKey,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvailableGamefowlSection() {
    if (_isLoadingProducts) {
      return _buildProductLoading(
        'Available Gamefowl',
      );
    }

    final gamefowl = _products
        .where(
          _isGamefowlProduct,
        )
        .take(6)
        .toList();
    if (gamefowl.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: Text(
            'Available Gamefowl',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF242424),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildHorizontalProducts(
          gamefowl,
          sectionKey: 'gamefowl',
        ),
      ],
    );
  }

  bool _isGamefowlProduct(
    Map<String, dynamic> product,
  ) {
    return isGamefowlItem(
      product,
      categories: context.read<CategoryProvider>().categories,
    );
  }

  Widget _buildBuyAgainSection() {
    if (_isLoadingDisplayedProducts) {
      return _buildProductLoading(
        'Buy Again',
      );
    }

    final products = _getFilteredProducts();

    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    final buyAgain = products
        .skip(
          products.length > 6 ? 6 : 0,
        )
        .take(6)
        .toList();

    if (buyAgain.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: Text(
            'Buy Again',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF242424),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildHorizontalProducts(
          buyAgain,
          sectionKey: 'buy_again',
        ),
      ],
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product, {
    String? favoriteCardKey,
  }) {
    final name = (product['item_name'] ??
            product['name'] ??
            product['product_name'] ??
            'Product')
        .toString();

    final price = product['item_price'] ??
        product['price'] ??
        product['selling_price'] ??
        0;

    final image = _getImageUrl(
      product,
      [
        'item_images',
        'images',
        'image_url',
        'image',
        'product_image',
      ],
    );

    final productId = product['id'] ?? product['item_id'];

    final isFavorite = favoriteCardKey != null
        ? _favoriteCardKeys.contains(
            favoriteCardKey,
          )
        : _isProductFavorite(productId);

    return SizedBox(
      width: 165,
      height: 250,
      child: GestureDetector(
        onTap: () {
          if (productId == null) {
            return;
          }

          Navigator.push(
            context,
            _createFadeRoute(
              _isGamefowlProduct(product)
                  ? gamefowlProdDetail(
                      productId: productId,
                      productData: product,
                      shopId: product['shop_id'],
                      shopName: product['shop_name']?.toString(),
                    )
                  : ProductDetailScreen(
                      productId: productId, productData: product),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 7,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 130,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildProductImage(image),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _toggleProductFavorite(
                              product,
                              favoriteCardKey: favoriteCardKey,
                            );
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    0.15,
                                  ),
                                  blurRadius: 5,
                                  offset: const Offset(
                                    0,
                                    2,
                                  ),
                                ),
                              ],
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite
                                  ? Colors.red
                                  : Colors.grey.shade700,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    10,
                    9,
                    10,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatPrice(price),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3155B7),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 28,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF3155B7,
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          'View Product',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
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

  Widget _buildProductImage(
    String? image,
  ) {
    if (image != null && image.isNotEmpty) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return _productPlaceholder();
        },
      );
    }

    return _productPlaceholder();
  }

  Widget _productPlaceholder() {
    return Container(
      color: const Color(0xFFF0F1F4),
      child: const Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          color: Color(0xFFB0B4BD),
          size: 40,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredProducts() {
    final categories = context.read<CategoryProvider>().categories;
    if (categories.isEmpty) return [];
    final provider = context.read<ItemsProvider>();
    final source =
        _selectedCategoryId == null ? _products : provider.categoryItems;
    return source
        .where((item) => !isGamefowlItem(item, categories: categories))
        .toList();
  }

  bool get _isLoadingDisplayedProducts =>
      _isLoadingProducts ||
      context.read<CategoryProvider>().isLoading ||
      (_selectedCategoryId != null &&
          context.read<ItemsProvider>().isCategoryLoading);

  String? _getImageUrl(
    Map<String, dynamic>? data,
    List<String> keys,
  ) {
    if (data == null) {
      return null;
    }

    for (final key in keys) {
      final value = data[key];

      if (value == null) {
        continue;
      }

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is List && value.isNotEmpty) {
        final first = value.first;

        if (first != null && first.toString().trim().isNotEmpty) {
          return first.toString().trim();
        }
      }

      if (value is Map) {
        final nested = value['url'] ?? value['path'] ?? value['image_url'];

        if (nested != null && nested.toString().trim().isNotEmpty) {
          return nested.toString().trim();
        }
      }
    }

    return null;
  }

  Widget _buildNetworkOrAssetImage(
    String? imageUrl, {
    required String fallback,
  }) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return Image.asset(
            fallback,
            fit: BoxFit.cover,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return Container(
                color: const Color(0xFFCCCCCC),
              );
            },
          );
        },
      );
    }

    return Image.asset(
      fallback,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          color: const Color(0xFFCCCCCC),
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              size: 42,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  String _formatRating(
    dynamic rating,
  ) {
    if (rating == null) {
      return '0.0';
    }

    if (rating is num) {
      return rating.toStringAsFixed(1);
    }

    final parsed = double.tryParse(
      rating.toString(),
    );

    return parsed != null ? parsed.toStringAsFixed(1) : '0.0';
  }

  String _formatPrice(
    dynamic value,
  ) {
    if (value is num) {
      return '₱${value.toStringAsFixed(2)}';
    }

    final parsed = double.tryParse(
      value.toString(),
    );

    if (parsed != null) {
      return '₱${parsed.toStringAsFixed(2)}';
    }

    return '₱0.00';
  }

  Widget _buildProductLoading(
    String title,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF242424),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            itemCount: 3,
            itemBuilder: (
              context,
              index,
            ) {
              return Container(
                width: 165,
                height: 250,
                margin: const EdgeInsets.only(
                  right: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStoreLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildEmptyStoreState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            _storeError != null
                ? 'Failed to load stores'
                : 'No stores available',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselIndicator({
    required int currentIndex,
  }) {
    if (_suggestedStores.length <= 1) {
      return const SizedBox(
        height: 5,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _suggestedStores.length,
        (index) {
          final active = currentIndex == index;

          return AnimatedContainer(
            duration: const Duration(
              milliseconds: 220,
            ),
            margin: const EdgeInsets.symmetric(
              horizontal: 2,
            ),
            width: active ? 25 : 6,
            height: 5,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF496BC1) : const Color(0xFFD1D4DC),
              borderRadius: BorderRadius.circular(5),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultsOverlay() {
    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: Consumer<ItemsProvider>(
        builder: (
          context,
          itemsProvider,
          child,
        ) {
          final categories = context.read<CategoryProvider>().categories;
          final results = categories.isEmpty
              ? <Map<String, dynamic>>[]
              : itemsProvider.searchResults
                  .where((item) => !isGamefowlItem(
                        item,
                        categories: categories,
                      ))
                  .toList();

          if (results.isEmpty) {
            return const SizedBox.shrink();
          }

          return Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 350,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                ),
                itemCount: results.length,
                separatorBuilder: (
                  context,
                  index,
                ) =>
                    const Divider(
                  height: 1,
                ),
                itemBuilder: (
                  context,
                  index,
                ) {
                  final product = results[index];

                  return ListTile(
                    dense: true,
                    title: Text(
                      product['item_name']?.toString() ?? 'Unknown Product',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _clearSearch,
                  );
                },
              ),
            ),
          );
        },
      ),
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

  @override
  void dispose() {
    _debounceTimer?.cancel();

    _searchController.removeListener(
      _onSearchChanged,
    );

    _searchController.dispose();
    _searchFocus.dispose();

    _storesPageController.dispose();
    _farmsPageController.dispose();

    super.dispose();
  }
}

class _RoosterCoverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget searchWidget;
  final Widget categoriesWidget;
  final Widget cover;
  final double maxHeight;
  final double minHeight;

  const _RoosterCoverHeaderDelegate({
    required this.searchWidget,
    required this.categoriesWidget,
    required this.cover,
    required this.maxHeight,
    required this.minHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapseRange = maxExtent - minExtent;

    final progress = collapseRange <= 0
        ? 1.0
        : (shrinkOffset / collapseRange).clamp(0.0, 1.0);

    const coverHeight = 280.0;
    const searchHeight = 40.0;
    const categoryHeight = 36.0;
    const spacing = 8.0;

    final expandedSearchTop = coverHeight - searchHeight - 10.0;

    final expandedCategoryTop = coverHeight + spacing;

    const collapsedSearchTop = 12.0;
    const collapsedCategoryTop = 60.0;

    final searchTop = expandedSearchTop -
        ((expandedSearchTop - collapsedSearchTop) * progress);

    final categoryTop = expandedCategoryTop -
        ((expandedCategoryTop - collapsedCategoryTop) * progress);

    final backgroundColor = Color.lerp(
      Colors.transparent,
      const Color(0xFFF7F7F7),
      progress,
    )!;

    return Material(
      color: Colors.transparent,
      elevation: progress >= 0.98 ? 3 : 0,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: -(progress * coverHeight),
            height: coverHeight,
            child: cover,
          ),
          Positioned(
            left: 0,
            right: 0,
            top: coverHeight,
            bottom: 0,
            child: Container(
              color: backgroundColor,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: searchTop,
            height: searchHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
              ),
              child: searchWidget,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: categoryTop,
            height: categoryHeight,
            child: categoriesWidget,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(
    covariant _RoosterCoverHeaderDelegate oldDelegate,
  ) {
    return oldDelegate.searchWidget != searchWidget ||
        oldDelegate.categoriesWidget != categoriesWidget ||
        oldDelegate.cover != cover ||
        oldDelegate.maxHeight != maxHeight ||
        oldDelegate.minHeight != minHeight;
  }
}
