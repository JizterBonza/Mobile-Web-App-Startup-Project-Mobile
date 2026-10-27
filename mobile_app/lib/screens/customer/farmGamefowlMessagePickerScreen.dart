import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../constants/constants.dart';
import '../../provider/message_provider.dart';
import '../../services/farms_service.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gamefowl_icon.dart';
import '../../widgets/skeletons/app_skeletons.dart';

class FarmGamefowlMessagePickerScreen extends StatefulWidget {
  const FarmGamefowlMessagePickerScreen({
    super.key,
    required this.farmId,
    required this.conversationId,
    this.farmsService,
  });

  final dynamic farmId;
  final dynamic conversationId;
  final FarmsService? farmsService;

  @override
  State<FarmGamefowlMessagePickerScreen> createState() =>
      _FarmGamefowlMessagePickerScreenState();
}

class _FarmGamefowlMessagePickerScreenState
    extends State<FarmGamefowlMessagePickerScreen> {
  late final FarmsService _farmsService;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _listings = [];
  bool _loading = true;
  String? _loadError;
  String? _sendError;
  String _query = '';
  dynamic _sendingId;

  @override
  void initState() {
    super.initState();
    _farmsService = widget.farmsService ?? FarmsService();
    _loadListings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  String _text(dynamic value) => value?.toString().trim() ?? '';

  num? _number(dynamic value) =>
      value is num ? value : num.tryParse(_text(value).replaceAll(',', ''));

  List<Map<String, dynamic>> get _visibleListings {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _listings;
    return _listings.where((listing) {
      final gamefowl = _map(listing['gamefowl']);
      final bloodline = _map(gamefowl['bloodline']);
      return _text(listing['name']).toLowerCase().contains(query) ||
          _text(bloodline['name']).toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _loadListings() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final farm = await _farmsService.fetchFarmWithListings(widget.farmId);
      final raw = farm['listings'];
      if (raw is! List) throw const FormatException('Invalid farm listings');
      final listings = raw.whereType<Map>().map(_map).where((listing) {
        final stock = _number(listing['stock']);
        return listing['id'] != null &&
            _text(listing['status']).toLowerCase() == 'active' &&
            stock != null &&
            stock > 0;
      }).toList();
      if (!mounted) return;
      setState(() {
        _listings = listings;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _listings = [];
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _sendListing(Map<String, dynamic> listing) async {
    if (_sendingId != null) return;
    final id = listing['id'];
    if (id == null) return;
    setState(() {
      _sendingId = id;
      _sendError = null;
    });
    final provider = context.read<MessageProvider>();
    final sent = await provider.sendMessage(
      conversationId: widget.conversationId,
      itemId: id,
    );
    if (!mounted) return;
    if (sent) {
      await provider.refreshActiveThread();
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sendingId = null;
      _sendError = provider.error ?? 'Failed to send gamefowl';
    });
  }

  String? _image(Map<String, dynamic> listing) {
    final direct = _text(listing['image']);
    if (direct.isNotEmpty) return direct;
    for (final source in [
      listing['images'],
      _map(listing['gamefowl'])['images']
    ]) {
      if (source is List && source.isNotEmpty) {
        final first = _text(source.first);
        if (first.isNotEmpty) return first;
      }
    }
    return null;
  }

  Widget _listingCard(Map<String, dynamic> listing) {
    final gamefowl = _map(listing['gamefowl']);
    final traits = [
      _text(_map(gamefowl['class'])['name']),
      _text(_map(gamefowl['age_type'])['name']),
      _text(gamefowl['sex']),
    ].where((value) => value.isNotEmpty).join(' | ');
    final price = _number(listing['price']);
    final stock = _number(listing['stock'])!;
    final image = _image(listing);
    final sending = _sendingId?.toString() == listing['id'].toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: image == null
                  ? const ColoredBox(
                      color: Colors.white,
                      child: Center(
                        child: GamefowlIcon(
                            size: 36, color: AppColors.brandPrimary),
                      ),
                    )
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Colors.white,
                        child: Center(
                          child: GamefowlIcon(
                              size: 36, color: AppColors.brandPrimary),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(listing['name']).isEmpty
                      ? 'Gamefowl listing'
                      : _text(listing['name']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (traits.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(traits,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF757575))),
                ],
                const SizedBox(height: 8),
                Text(
                  price == null
                      ? 'Price unavailable'
                      : '\u20B1${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text('${stock.toString()} in stock',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF757575))),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed:
                        _sendingId != null ? null : () => _sendListing(listing),
                    child: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleListings;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Share gamefowl'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search gamefowl or bloodline',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
            if (_sendError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(_sendError!,
                    style: const TextStyle(color: AppColors.error)),
              ),
            Expanded(
              child: _loading
                  ? const ListRowsSkeleton(count: 8)
                  : _loadError != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Failed to load gamefowl listings'),
                              const SizedBox(height: 8),
                              Text(_loadError!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadListings,
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        )
                      : visible.isEmpty
                          ? EmptyStateWidget(
                              iconWidget: GamefowlIcon(
                                  size: 64, color: Colors.grey[400]),
                              message: _query.trim().isEmpty
                                  ? 'No in-stock gamefowl to share'
                                  : 'No gamefowl found',
                              subtitle: _query.trim().isEmpty
                                  ? 'This farm has no active listings in stock'
                                  : 'Try a different search',
                            )
                          : RefreshIndicator(
                              onRefresh: _loadListings,
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, index) =>
                                    _listingCard(visible[index]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
