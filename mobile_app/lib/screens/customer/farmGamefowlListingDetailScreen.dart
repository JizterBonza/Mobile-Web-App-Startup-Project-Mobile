import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../provider/message_provider.dart';
import '../../services/farms_service.dart';
import 'InquiryChat.dart';

class FarmGamefowlListingDetailScreen extends StatefulWidget {
  const FarmGamefowlListingDetailScreen({
    super.key,
    required this.listingId,
    this.farmsService,
  });

  final dynamic listingId;
  final FarmsService? farmsService;

  @override
  State<FarmGamefowlListingDetailScreen> createState() =>
      _FarmGamefowlListingDetailScreenState();
}

class _FarmGamefowlListingDetailScreenState
    extends State<FarmGamefowlListingDetailScreen> {
  static const _blue = Color(0xFF243E91);
  late final FarmsService _farmsService;
  final PageController _pageController = PageController();
  Map<String, dynamic>? _listing;
  String? _error;
  bool _isLoading = true;
  bool _isOpeningInquiry = false;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _farmsService = widget.farmsService ?? FarmsService();
    _loadListing();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadListing() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final listing =
          await _farmsService.fetchFarmGamefowlListing(widget.listingId);
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _imageIndex = 0;
        _isLoading = false;
      });
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load gamefowl listing';
        _isLoading = false;
      });
    }
  }

  String? _value(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  Map<String, dynamic> _nested(Map<String, dynamic> source, String key) {
    final value = source[key];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  List<String> _images(Map<String, dynamic> listing) {
    final images = <String>[];
    void add(dynamic value) {
      final url = _value(value);
      if (url != null && !images.contains(url)) images.add(url);
    }

    final listingImages = listing['images'];
    final gamefowlImages = _nested(listing, 'gamefowl')['images'];
    if (listingImages is List) {
      for (final image in listingImages) {
        add(image);
      }
    }
    if (images.isEmpty && gamefowlImages is List) {
      for (final image in gamefowlImages) {
        add(image);
      }
    }
    if (images.isEmpty) add(listing['image']);
    final primaryIndex = listing['primary_image_index'];
    if (primaryIndex is int &&
        primaryIndex > 0 &&
        primaryIndex < images.length) {
      final primary = images.removeAt(primaryIndex);
      images.insert(0, primary);
    }
    return images;
  }

  String _price(dynamic value) {
    final price = value is num ? value : num.tryParse(value?.toString() ?? '');
    return price == null ? 'Price unavailable' : '₱${price.toStringAsFixed(2)}';
  }

  Future<void> _openInquiry() async {
    if (_isOpeningInquiry || _listing == null) return;
    final listing = _listing!;
    final farm = _nested(listing, 'farm');
    final farmId = listing['farm_id'] ?? farm['id'];
    final listingId = listing['id'];
    if (farmId == null || listingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Listing information is unavailable'),
      ));
      return;
    }
    setState(() => _isOpeningInquiry = true);
    final provider = context.read<MessageProvider>();
    final farmName = _value(farm['name']);
    final success = await provider.startOrResumeFarmConversation(
      farmId: farmId,
      farmName: farmName,
      itemId: listingId,
    );
    if (!mounted) return;
    final conversationId = provider.activeThread?.conversation.id;
    if (!success || conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ?? 'Failed to start farm inquiry'),
      ));
      setState(() => _isOpeningInquiry = false);
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
    if (mounted) setState(() => _isOpeningInquiry = false);
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : listing == null
                  ? _buildError()
                  : _buildDetails(listing),
      bottomNavigationBar: !_isLoading && _error == null && listing != null
          ? SafeArea(
              top: false,
              child: Row(
                children: [
                  _bottomAction('Add to Crate', light: true),
                  _bottomAction('Order Request'),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Failed to load gamefowl listing'),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadListing,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      );

  Widget _buildDetails(Map<String, dynamic> listing) {
    final gamefowl = _nested(listing, 'gamefowl');
    final farm = _nested(listing, 'farm');
    final images = _images(listing);
    final bloodline = _value(_nested(gamefowl, 'bloodline')['name']);
    final age = _value(_nested(gamefowl, 'age_type')['name']);
    final sex = _value(gamefowl['sex']);
    final traits = [bloodline, age, sex].whereType<String>().join(' | ');
    final unit = _value(listing['selling_unit']);
    final description = _value(gamefowl['description']);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildGallery(images),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_price(listing['price']),
                      style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF262626))),
                  if (unit != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child:
                          Text(' /$unit', style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(_value(listing['name']) ?? 'Gamefowl',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202020))),
              if (traits.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(traits,
                    style: const TextStyle(fontSize: 12, color: _blue)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        'Hatch Date: ${_value(gamefowl['hatch_date']) ?? '—'}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  Expanded(
                    child: Text(
                        'Class: ${_value(_nested(gamefowl, 'class')['name']) ?? '—'}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Description',
                  style: TextStyle(fontSize: 12, color: Color(0xFF777777))),
              const SizedBox(height: 6),
              Text(description ?? 'No description provided.',
                  style: const TextStyle(fontSize: 12, height: 1.4)),
              const SizedBox(height: 24),
              _buildFarmPanel(farm),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isOpeningInquiry ? null : _openInquiry,
                  icon: _isOpeningInquiry
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : SvgPicture.asset(
                          'assets/icons/chat.svg',
                          width: 17,
                          height: 17,
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                        ),
                  label: const Text('Inquire'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF6578A8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGallery(List<String> images) {
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      children: [
        SizedBox(
          height: width.clamp(240.0, 390.0),
          child: Stack(
            children: [
              if (images.isEmpty)
                const ColoredBox(
                  color: Color(0xFFD4D4D4),
                  child: Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          size: 54, color: Colors.white)),
                )
              else
                PageView.builder(
                  itemCount: images.length,
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _imageIndex = index),
                  itemBuilder: (context, index) => Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFD4D4D4),
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 14,
                child: Material(
                  color: Colors.white.withOpacity(0.9),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                right: 14,
                child: Row(
                  children: [
                    _unavailableGalleryIcon(
                        Icons.shopping_bag_outlined, 'Crate unavailable'),
                    const SizedBox(width: 6),
                    _unavailableGalleryIcon(
                        Icons.share_outlined, 'Share unavailable'),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  images.length,
                  (index) => Container(
                        width: index == _imageIndex ? 30 : 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index == _imageIndex
                              ? _blue
                              : const Color(0xFFC1C5CE),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
            ),
          ),
      ],
    );
  }

  Widget _unavailableGalleryIcon(IconData icon, String label) => Semantics(
        button: true,
        enabled: false,
        label: label,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withOpacity(0.8),
          child: Icon(icon, size: 18, color: const Color(0xFFADB0B7)),
        ),
      );

  Widget _buildFarmPanel(Map<String, dynamic> farm) {
    final logo = _value(farm['logo_url']);
    final location = [_value(farm['city']), _value(farm['province'])]
        .whereType<String>()
        .join(', ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8E8E8)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: logo == null ? null : NetworkImage(logo),
            child: logo == null
                ? const Icon(Icons.agriculture, color: Color(0xFF9DA3AE))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_value(farm['name']) ?? 'Farm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (location.isNotEmpty)
                  Text(location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (_value(farm['contact_number']) != null)
                  Text(_value(farm['contact_number'])!,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFB2B2B2)),
        ],
      ),
    );
  }

  Widget _bottomAction(String label, {bool light = false}) => Expanded(
        child: Semantics(
          button: true,
          enabled: false,
          label: '$label unavailable',
          child: Container(
            height: 52,
            color: light ? const Color(0xFF657BBB) : const Color(0xFF566CA9),
            alignment: Alignment.center,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ),
      );
}
