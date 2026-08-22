import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/klasrum_service.dart';
import '../../utils/auth_guard.dart';
import '../../utils/customer_nav.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/login_dialog.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import '../common/profileScreen.dart';
import 'cartScreenV2.dart';
import 'messagesScreen.dart';

class KlasrumScreen extends StatefulWidget {
  const KlasrumScreen({super.key});

  @override
  State<KlasrumScreen> createState() => _KlasrumScreenState();
}

class _KlasrumScreenState extends State<KlasrumScreen> {
  bool _isGuest = true;
  String? _userName;
  dynamic _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserState();
      _loadInitial();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserState() async {
    try {
      final token = await ApiService.getToken();
      final name = await ApiService.getUserName();
      if (!mounted) return;
      final isGuest = token == null || token.isEmpty;
      setState(() {
        _isGuest = isGuest;
        _userName = name;
      });
      if (isGuest) {
        _clearBadges();
      } else {
        await _fetchBadges();
        await _fetchMessageUnread();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isGuest = true;
          _userName = null;
        });
      }
    }
  }

  Future<void> _refreshAfterLogin() async {
    await _loadUserState();
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

  Future<void> _loadInitial() async {
    final provider = Provider.of<KlasrumProvider>(context, listen: false);
    await Future.wait([
      provider.fetchCategories(),
      provider.fetchFeatured(),
      provider.fetchContents(),
    ]);
  }

  Future<void> _reloadContents() async {
    final provider = Provider.of<KlasrumProvider>(context, listen: false);
    // Load the full contents list; search + category are applied locally.
    await provider.fetchContents();
  }

  List<Map<String, dynamic>> _filteredContents(
    List<Map<String, dynamic>> contents,
  ) {
    var filtered = contents;

    if (_selectedCategoryId != null) {
      final selected = _selectedCategoryId.toString();
      filtered = filtered
          .where((article) => article['category_id']?.toString() == selected)
          .toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return filtered;

    return filtered.where((article) {
      final haystack = [
        article['title']?.toString() ?? '',
        article['description']?.toString() ?? '',
        article['heading']?.toString() ?? '',
        article['category_name']?.toString() ?? '',
        stripHtml(article['body']?.toString() ?? ''),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _onRefresh() async {
    final provider = Provider.of<KlasrumProvider>(context, listen: false);
    await Future.wait([
      provider.fetchCategories(),
      provider.fetchFeatured(),
      _reloadContents(),
    ]);
  }

  void _onSearchChanged(String value) {
    setState(() {});
  }

  void _onAuthenticatedTap(VoidCallback action) {
    if (!requireAuthOrShowLogin(
      context,
      isGuest: _isGuest,
    )) {
      return;
    }
    action();
  }

  void _navigateToCart() {
    if (_isGuest) {
      showLoginDialog(context, onLoginSuccess: _refreshAfterLogin);
      return;
    }
    Navigator.push(
      context,
      _createFadeRoute(CartScreenV2()),
    ).then((_) {
      if (mounted) _fetchBadges();
    });
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
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
    );
  }

  void _openArticle(Map<String, dynamic> article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KlasrumArticleScreen(article: article),
      ),
    );
  }

  /// Estimate reading time from body / heading / description when API has no read_time.
  static String estimateReadTime(Map<String, dynamic> article) {
    final explicit = article['read_time']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) {
      if (explicit.toLowerCase().contains('min')) return explicit;
      return '$explicit min read';
    }
    final bodyPlain = stripHtml(article['body']?.toString() ?? '');
    final text = [
      bodyPlain,
      article['heading']?.toString() ?? '',
      article['description']?.toString() ?? '',
      article['title']?.toString() ?? '',
    ].join(' ');
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final minutes = words < 1 ? 1 : (words / 200).ceil().clamp(1, 60);
    return '$minutes min read';
  }

  static String stripHtml(String html) {
    if (html.isEmpty) return '';
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Consumer<KlasrumProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primaryGreen,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGreenHeader(topInset),
                      _buildFeaturedHero(provider),
                      _buildSectionHeader(),
                      _buildCategoryChips(provider),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Text(
                          'MORE ARTICLE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildArticleListSliver(provider),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: buildCustomerBottomNavigationBar(
        context: context,
        currentIndex: CustomerNavIndex.klasrum,
        isGuest: _isGuest,
        onLoginSuccess: _refreshAfterLogin,
      ),
    );
  }

  Widget _buildGreenHeader(double topInset) {
    return Container(
      width: double.infinity,
      color: AppColors.primaryGreen,
      padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _onAuthenticatedTap(() {
              Navigator.push(
                context,
                _createFadeRoute(const ProfileScreen()),
              );
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
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
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
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
            child: Center(child: iconWidget),
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

  Widget _buildFeaturedHero(KlasrumProvider provider) {
    final featured = provider.featuredContent;
    final coverUrl = featured?['cover_url']?.toString();
    final title = featured?['title']?.toString().trim() ?? '';
    final description = featured?['description']?.toString().trim() ?? '';
    final categoryName = featured?['category_name']?.toString().trim() ?? '';
    final readTime =
        featured != null ? estimateReadTime(featured) : '1 min read';

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: SizedBox(
        height: 320,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: featured == null ? null : () => _openArticle(featured),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  coverUrl != null && coverUrl.isNotEmpty
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverFallback(),
                        )
                      : _coverFallback(),
                  // Soft green fade from header into the image
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 72,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primaryGreen.withOpacity(0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom readability gradient
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.25),
                          Colors.black.withOpacity(0.78),
                        ],
                        stops: const [0.25, 0.55, 1.0],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 72),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Row(
                          children: [
                            _buildHeroBadge(
                              label: 'FEATURED',
                              background: AppColors.accentAmber,
                              foreground: Colors.black,
                            ),
                            if (categoryName.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _buildHeroBadge(
                                label: categoryName.toUpperCase(),
                                background: AppColors.primaryGreen,
                                foreground: Colors.white,
                              ),
                            ],
                            const SizedBox(width: 10),
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.white.withOpacity(0.95),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                readTime,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.95),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title.isNotEmpty ? title : 'Learn with Klasmeyt',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.88),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Search sits inside the dark bottom of the featured card
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildSearchField(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBadge({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 40,
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(20),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search articles...',
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
            prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[500]),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, size: 16, color: Colors.grey[500]),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/klasrum-icon.svg',
                height: 18,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Text(
                'KLASRUM',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: Colors.grey[900],
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Learn with Klasmeyt',
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(KlasrumProvider provider) {
    return SizedBox(
      height: 40,
      child: provider.isCategoriesLoading && provider.categories.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip(
                  label: 'All',
                  selected: _selectedCategoryId == null,
                  onTap: () {
                    setState(() => _selectedCategoryId = null);
                  },
                ),
                ...provider.categories.map((category) {
                  final id = category['id'];
                  return _buildCategoryChip(
                    label: category['name']?.toString() ?? '',
                    selected:
                        _selectedCategoryId?.toString() == id?.toString(),
                    onTap: () {
                      setState(() => _selectedCategoryId = id);
                    },
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primaryGreen : Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? AppColors.primaryGreen : Colors.grey[300]!,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArticleListSliver(KlasrumProvider provider) {
    if (provider.isContentsLoading && provider.contents.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ListRowsSkeleton(count: 5),
        ),
      );
    }

    if (provider.contentsError != null && provider.contents.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyStateWidget(
          icon: Icons.error_outline,
          message: 'Could not load articles',
          subtitle: 'Pull down to try again.',
        ),
      );
    }

    final articles = _filteredContents(provider.contents);

    if (articles.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyStateWidget(
          icon: Icons.menu_book_outlined,
          message: 'No articles yet',
          subtitle: 'Try another category or search.',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList.separated(
        itemCount: articles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildArticleRowCard(articles[index]);
        },
      ),
    );
  }

  Widget _buildArticleRowCard(Map<String, dynamic> article) {
    final coverUrl = article['cover_url']?.toString();
    final categoryName = article['category_name']?.toString() ?? '';
    final title = article['title']?.toString() ?? '';
    final description = article['description']?.toString() ?? '';
    final readTime = estimateReadTime(article);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openArticle(article),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: coverUrl != null && coverUrl.isNotEmpty
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverFallback(),
                        )
                      : _coverFallback(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categoryName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          categoryName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    if (categoryName.isNotEmpty) const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                        height: 1.25,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          readTime,
                          style: TextStyle(
                            fontSize: 11,
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
        ),
      ),
    );
  }

  Widget _coverFallback() {
    return Image.asset(
      'assets/images/manok.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.primaryGreen.withOpacity(0.12),
        child: const Icon(
          Icons.menu_book_outlined,
          color: AppColors.primaryGreen,
          size: 40,
        ),
      ),
    );
  }
}

class KlasrumArticleScreen extends StatefulWidget {
  final Map<String, dynamic> article;

  const KlasrumArticleScreen({super.key, required this.article});

  @override
  State<KlasrumArticleScreen> createState() => _KlasrumArticleScreenState();
}

class _KlasrumArticleScreenState extends State<KlasrumArticleScreen> {
  bool _isGuest = true;
  late Map<String, dynamic> _article;
  bool _isLoadingBody = false;

  @override
  void initState() {
    super.initState();
    _article = Map<String, dynamic>.from(widget.article);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGuestState();
      _ensureFullArticle();
    });
  }

  Future<void> _loadGuestState() async {
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

  /// If opened from featured list without body, try to hydrate from contents API.
  Future<void> _ensureFullArticle() async {
    final body = _article['body']?.toString();
    if (body != null && body.isNotEmpty && body != 'null') return;

    final id = _article['id'];
    if (id == null) return;

    setState(() => _isLoadingBody = true);
    try {
      final service = KlasrumService();
      final items = await service.fetchContents();
      Map<String, dynamic>? match;
      for (final item in items) {
        if (item['id']?.toString() == id.toString()) {
          match = item;
          break;
        }
      }
      if (match != null && mounted) {
        setState(() {
          _article = {..._article, ...match!};
        });
      }
    } catch (_) {
      // Keep summary fields if detail hydrate fails.
    } finally {
      if (mounted) setState(() => _isLoadingBody = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = _article['cover_url']?.toString();
    final categoryName = _article['category_name']?.toString() ?? '';
    final title = _article['title']?.toString() ?? 'Article';
    final description = _article['description']?.toString() ?? '';
    final caption = _article['caption']?.toString() ?? '';
    final bodyPlain =
        _KlasrumScreenState.stripHtml(_article['body']?.toString() ?? '');
    final mediaUrl = _article['media_url']?.toString();
    final mediaType = _article['media_type']?.toString().toLowerCase() ?? '';
    final readTime = _KlasrumScreenState.estimateReadTime(_article);
    final bodyParagraphs = bodyPlain
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: const Text(
          'Klasrum',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/manok.png',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      'assets/images/manok.png',
                      fit: BoxFit.cover,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (categoryName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            categoryName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      if (categoryName.isNotEmpty) const SizedBox(width: 10),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        readTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[900],
                      height: 1.25,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                  if (_isLoadingBody) ...[
                    const SizedBox(height: 24),
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ] else ...[
                    if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      if (mediaType == 'image')
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            mediaUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                mediaType == 'video'
                                    ? Icons.play_circle_outline
                                    : Icons.attach_file,
                                color: AppColors.primaryGreen,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  mediaType == 'video'
                                      ? 'Video attached'
                                      : 'Media attached',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          caption,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                    if (bodyParagraphs.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      ...bodyParagraphs.map(
                        (paragraph) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            paragraph,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.55,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ] else if (description.isEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'No article content available.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildCustomerBottomNavigationBar(
        context: context,
        currentIndex: CustomerNavIndex.klasrum,
        isGuest: _isGuest,
        onLoginSuccess: _loadGuestState,
      ),
    );
  }
}
