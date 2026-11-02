import 'package:flutter/material.dart';

import '../../constants/constants.dart';
import '../../models/farm_checkout.dart';
import '../../models/gamefowl_request_draft.dart';
import '../../services/farms_service.dart';
import '../../widgets/gamefowl_icon.dart';

/// Selects a listing locally; opening this picker never changes the farm cart.
class FarmBirdRequestPicker extends StatefulWidget {
  const FarmBirdRequestPicker({
    super.key,
    required this.farmId,
    required this.excludedIds,
    required this.service,
  });

  final int farmId;
  final Set<int> excludedIds;
  final FarmsService service;

  @override
  State<FarmBirdRequestPicker> createState() => _FarmBirdRequestPickerState();
}

class _FarmBirdRequestPickerState extends State<FarmBirdRequestPicker> {
  List<Map<String, dynamic>> _listings = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final farm = await widget.service.fetchFarmWithListings(widget.farmId);
      if ((farm['id'] != null && farmInt(farm['id']) != widget.farmId) ||
          farm['listings'] is! List) {
        throw const FormatException('Unable to load listings for this farm.');
      }
      final ids = <int>{};
      final listings = farmMaps(farm['listings'])
          .where((entry) {
            final id = farmInt(entry['listing_id'] ?? entry['id']);
            final farmId = farmInt(entry['farm_id'] ??
                farmMap(entry['farm'])['id'] ??
                widget.farmId);
            final stock = num.tryParse(entry['stock']?.toString() ?? '') ?? 0;
            return farmId == widget.farmId &&
                id > 0 &&
                !widget.excludedIds.contains(id) &&
                ids.add(id) &&
                entry['status']?.toString().trim().toLowerCase() == 'active' &&
                entry['available'] != false &&
                stock > 0;
          })
          .map((entry) => <String, dynamic>{...entry, 'farm_id': widget.farmId})
          .toList();
      if (!mounted) return;
      setState(() {
        _listings = listings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load birds. Please try again.';
        _loading = false;
      });
    }
  }

  Widget _thumbnail(GamefowlProductSummary product, String id) {
    Widget placeholder() => ColoredBox(
          key: ValueKey('bird-image-placeholder-$id'),
          color: AppColors.surfaceLight,
          child: const Center(
            child: GamefowlIcon(size: 28, color: AppColors.brandPrimary),
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: product.imageUrl == null
            ? placeholder()
            : Image.network(
                product.imageUrl!,
                key: ValueKey('bird-image-$id'),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                frameBuilder: (_, child, frame, synchronouslyLoaded) =>
                    synchronouslyLoaded || frame != null
                        ? child
                        : placeholder(),
                errorBuilder: (_, __, ___) => placeholder(),
              ),
      ),
    );
  }

  Widget _listingCard(Map<String, dynamic> entry) {
    final product = GamefowlProductSummary.fromProduct(entry);
    final id = (entry['listing_id'] ?? entry['id']).toString();
    final unit = entry['selling_unit']?.toString().trim() ?? '';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('pick-listing-$id'),
        onTap: () => Navigator.pop(context, entry),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _thumbnail(product, id),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.productName ?? product.bloodline ?? product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                if (product.traits.isNotEmpty || unit.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                      [product.traits, unit]
                          .where((value) => value.isNotEmpty)
                          .join(' | '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                        product.price == null
                            ? 'Price unavailable'
                            : product.formattedPrice,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandPrimary)),
                  ),
                ),
              ],
            )),
            const SizedBox(width: 10),
            IconButton(
              tooltip:
                  'Add ${product.productName ?? product.bloodline ?? product.title}',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, entry),
              icon: const Icon(Icons.add, size: 20),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String message, {Widget? action}) => Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 36, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          if (action != null) ...[const SizedBox(height: 8), action],
        ]),
      ));

  @override
  Widget build(BuildContext context) {
    final visible = _listings.where((entry) {
      final product = GamefowlProductSummary.fromProduct(entry);
      return [product.productName, product.title, product.traits]
          .whereType<String>()
          .join(' ')
          .toLowerCase()
          .contains(_query);
    }).toList();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Material(
            color: AppColors.surfaceMuted,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!keyboardOpen) ...[
                          Center(
                              child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                      color: AppColors.borderDefault,
                                      borderRadius: BorderRadius.circular(2)))),
                          const SizedBox(height: 12),
                        ],
                        Row(children: [
                          const Expanded(
                              child: Text('Add another bird',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold))),
                          IconButton(
                              tooltip: 'Close bird picker',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close)),
                        ]),
                        if (!keyboardOpen) ...[
                          const SizedBox(height: 2),
                          const Text('Available birds from this farm',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          key: const ValueKey('bird-picker-search'),
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          decoration: InputDecoration(
                              hintText: 'Search birds or bloodline',
                              hintStyle: const TextStyle(
                                  fontSize: 14, color: AppColors.textSecondary),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              prefixIcon: const Icon(Icons.search,
                                  color: AppColors.brandPrimary),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                    ),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: AppColors.borderDefault)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: AppColors.brandPrimary,
                                      width: 1.5)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          onChanged: (value) => setState(
                              () => _query = value.trim().toLowerCase()),
                        ),
                        const SizedBox(height: 12),
                        if (!_loading && _error == null) ...[
                          Text(
                              '${visible.length} ${visible.length == 1 ? 'listing' : 'listings'} available',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                        ],
                        Expanded(
                            child: _loading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.brandPrimary))
                                : _error != null
                                    ? _emptyState(
                                        Icons.cloud_off_outlined, _error!,
                                        action: TextButton(
                                            onPressed: _load,
                                            child: const Text('Retry')))
                                    : visible.isEmpty
                                        ? _emptyState(
                                            Icons.search_off_rounded,
                                            _listings.isEmpty
                                                ? 'No other birds are available from this farm.'
                                                : 'No birds match your search.')
                                        : ListView.separated(
                                            keyboardDismissBehavior:
                                                ScrollViewKeyboardDismissBehavior
                                                    .onDrag,
                                            padding: const EdgeInsets.only(
                                                bottom: 20),
                                            itemCount: visible.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 12),
                                            itemBuilder: (_, index) =>
                                                _listingCard(visible[index]),
                                          )),
                      ]),
                ))),
      ),
    );
  }
}
