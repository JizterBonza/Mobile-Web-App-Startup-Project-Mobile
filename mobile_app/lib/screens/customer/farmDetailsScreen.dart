import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../constants/constants.dart';
import '../../provider/message_provider.dart';
import '../../services/farms_service.dart';
import 'InquiryChat.dart';
import 'farmGamefowlListingDetailScreen.dart';

class FarmDetailsScreen extends StatefulWidget {
  const FarmDetailsScreen({
    super.key,
    required this.farmId,
    this.farmName,
    this.farmsService,
  });

  final dynamic farmId;
  final String? farmName;
  final FarmsService? farmsService;

  @override
  State<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  static const _gamefowlTypes = [
    'All',
    'One way / Pure',
    'Two-way cross',
    'Three-way cross',
    'Four-way cross',
    'Multiple cross / Unknown',
    'Bundles',
  ];

  late final FarmsService _farmsService;
  Map<String, dynamic>? _farm;
  bool _isLoading = true;
  bool _isOpeningChat = false;
  String? _error;
  int _selectedTab = 0;
  String _selectedGamefowlType = 'All';

  @override
  void initState() {
    super.initState();
    _farmsService = widget.farmsService ?? FarmsService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFarm();
    });
  }

  Future<void> _loadFarm({bool refresh = false}) async {
    if (!refresh) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final farm = await _farmsService.fetchFarmWithListings(widget.farmId);
      if (!mounted) return;
      setState(() {
        _farm = farm;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (refresh && _farm != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refresh farm')),
        );
      } else {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openFarmChat() async {
    if (_isOpeningChat) return;
    final farmId = _farm?['id'] ?? widget.farmId;
    if (farmId == null) return;
    setState(() => _isOpeningChat = true);
    final provider = context.read<MessageProvider>();
    final farmName = _value('name') ?? widget.farmName;
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
      setState(() => _isOpeningChat = false);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => InquiryChat(
          conversationId: conversationId,
          farmId: farmId,
          shopName: farmName,
        ),
      ),
    );
    if (mounted) setState(() => _isOpeningChat = false);
  }

  String? _value(String key) {
    final value = _farm?[key]?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }
    return value;
  }

  String? _firstImage(List<String> keys) {
    for (final key in keys) {
      final value = _value(key);
      if (value != null) return value;
    }
    return null;
  }

  List<Map<String, dynamic>> get _listings =>
      (_farm?['listings'] as List? ?? const []).cast<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7E7E7),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _buildErrorState()
          else
            RefreshIndicator(
              color: AppColors.brandPrimary,
              onRefresh: () => _loadFarm(refresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 15),
                  _buildTabBar(),
                  _selectedTab == 0
                      ? _buildGamefowlSection()
                      : _buildReviewsSection(),
                  _buildAboutSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          _buildTopControls(),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 12,
      right: 12,
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                tooltip: 'Back',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left, color: Color(0xFF333333)),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    'Search in farm',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Material(
            color: Colors.white,
            shape: CircleBorder(),
            elevation: 2,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.more_horiz, size: 24, color: Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final fallbackName = widget.farmName?.trim();
    final name = _value('name') ??
        (fallbackName == null || fallbackName.isEmpty ? 'Farm' : fallbackName);
    final status = _value('status');
    final logo = _value('logo_url');
    final owner = _value('owner_name');
    final email = _value('email');
    final phone = _value('contact_number');
    final address = _value('address');
    final city = _value('city');
    final province = _value('province');
    final location = address ?? [city, province].whereType<String>().join(', ');
    final contact = [email, phone].whereType<String>().join(' / ');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 230,
          width: double.infinity,
          child: _image(_firstImage(['cover_url', 'banner_url', 'logo_url'])),
        ),
        Container(
          margin: const EdgeInsets.only(top: 210),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: ClipOval(
                        child: logo == null
                            ? const ColoredBox(color: Color(0xFFE5E7EB))
                            : _image(logo,
                                fallbackColor: const Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF202437),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_farm?['is_verified'] == true) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  size: 17, color: Color(0xFF245687)),
                            ],
                          ],
                        ),
                        if (status != null)
                          Text(
                            status.toLowerCase() == 'active'
                                ? 'Open'
                                : '${status[0].toUpperCase()}${status.substring(1)}',
                            style: const TextStyle(
                                color: Color(0xFF3150A2), fontSize: 14),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _stat('0', 'Followers'),
                            _stat('${_listings.length}', 'Products'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (owner != null) _profileRow(owner, Icons.person_outline),
              if (contact.isNotEmpty)
                _profileRow(contact, Icons.contact_phone_outlined),
              if (location.isNotEmpty)
                _profileRow(location, Icons.location_on_outlined),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                      child:
                          _actionPlaceholder(Icons.favorite, 'Follow', false)),
                  const SizedBox(width: 12),
                  Expanded(child: _chatButton()),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202437))),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF858C9A))),
        ],
      ),
    );
  }

  Widget _profileRow(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.brandPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, height: 1.3, color: Color(0xFF616161))),
          ),
        ],
      ),
    );
  }

  Widget _actionPlaceholder(IconData icon, String label, bool primary) {
    return Semantics(
      button: true,
      enabled: false,
      label: '$label unavailable',
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: primary ? const Color(0xFF273F90) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 19,
                color: primary ? Colors.white : const Color(0xFFB8BAC0)),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: primary ? Colors.white : const Color(0xFF202437),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _chatButton() => ElevatedButton.icon(
        onPressed: _isOpeningChat ? null : _openFarmChat,
        icon: _isOpeningChat
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : SvgPicture.asset(
                'assets/icons/chat.svg',
                width: 19,
                height: 19,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
        label: const Text('Chat'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: const Color(0xFF273F90),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF6578A8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      );

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surfaceLight,
      child: Row(
        children: [
          _tab('Gamefowl', 0),
          _tab('Reviews', 1),
        ],
      ),
    );
  }

  Widget _tab(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.grey.shade900 : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGamefowlSection() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _gamefowlTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final type = _gamefowlTypes[index];
                final selected = _selectedGamefowlType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedGamefowlType = type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brandPrimary.withOpacity(0.08)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.brandPrimary.withOpacity(0.4)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? AppColors.brandPrimary
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.local_fire_department,
                  size: 18, color: AppColors.brandPrimary),
              SizedBox(width: 6),
              Text(
                'Best Seller',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF252525),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_listings.isEmpty)
            _buildGamefowlEmptyState()
          else
            SizedBox(
              height: 245,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _listings.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) => _buildListingCard(_listings[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> listing) {
    final gamefowl = listing['gamefowl'];
    final gamefowlClass = gamefowl is Map ? gamefowl['class'] : null;
    final className =
        gamefowlClass is Map ? gamefowlClass['name']?.toString().trim() : null;
    final name = listing['name']?.toString().trim();
    final price = num.tryParse(listing['price']?.toString() ?? '');
    final unit = listing['selling_unit']?.toString().trim();
    final images = listing['images'];
    final primaryIndex = listing['primary_image_index'];
    String? imageUrl = listing['image']?.toString();
    if ((imageUrl == null || imageUrl.isEmpty) &&
        images is List &&
        images.isNotEmpty) {
      final index = primaryIndex is int &&
              primaryIndex >= 0 &&
              primaryIndex < images.length
          ? primaryIndex
          : 0;
      imageUrl = images[index]?.toString();
    }
    if ((imageUrl == null || imageUrl.isEmpty) && gamefowl is Map) {
      final gamefowlImages = gamefowl['images'];
      if (gamefowlImages is List && gamefowlImages.isNotEmpty) {
        imageUrl = gamefowlImages.first?.toString();
      }
    }

    return InkWell(
      onTap: listing['id'] == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FarmGamefowlListingDetailScreen(
                    listingId: listing['id'],
                    farmsService: _farmsService,
                  ),
                ),
              ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 145,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: _image(imageUrl),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (className != null && className.isNotEmpty)
                    Text(
                      className,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF616161)),
                    ),
                  Text(
                    name == null || name.isEmpty ? 'Gamefowl' : name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF3150A2)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price == null
                        ? 'Price unavailable'
                        : '₱${price.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  if (unit != null && unit.isNotEmpty)
                    Text(
                      '/$unit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF858C9A)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Reviews',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildReviewsEmptyState(),
        ],
      ),
    );
  }

  Widget _buildGamefowlEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.shopping_bag_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No gamefowl available',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text('Gamefowl listings will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildReviewsEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined,
              size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text('No reviews yet',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    final description = _value('description');
    if (description == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _section('About Farm', [Text(description)]),
    );
  }

  Widget _section(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _image(String? url, {Color fallbackColor = const Color(0xFFC8C8C8)}) {
    if (url == null) return ColoredBox(color: fallbackColor);
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(color: fallbackColor),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Failed to load farm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_error ?? 'An error occurred', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadFarm,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
