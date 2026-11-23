import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/media_url.dart';
import '../models/catalog_search.dart';
import '../utils/price_format.dart';

class SearchSuggestion {
  const SearchSuggestion({
    required this.id,
    required this.title,
    required this.data,
    this.imageUrl,
    this.price,
    this.type = SearchResultType.product,
    this.isBundle = false,
  });

  final String id;
  final String title;
  final Map<String, dynamic> data;
  final String? imageUrl;
  final num? price;
  final SearchResultType type;
  final bool isBundle;

  factory SearchSuggestion.fromHit(CatalogSearchHit hit) => SearchSuggestion(
        id: hit.id,
        title: hit.name,
        data: hit.data,
        imageUrl: hit.imageUrl,
        price: hit.price,
        type: hit.type,
        isBundle: hit.isBundle,
      );

  factory SearchSuggestion.fromItem(Map<String, dynamic> item) {
    final gamefowl = item['gamefowl'];
    final images = item['images'];
    final primary = item['primary_image_index'];
    final primaryImage = images is List && images.isNotEmpty
        ? images[primary is int && primary >= 0 && primary < images.length
            ? primary
            : 0]
        : null;
    return SearchSuggestion(
      id: (item['id'] ?? item['item_id']).toString(),
      title: (item['item_name'] ??
              item['product_name'] ??
              item['name'] ??
              'Product')
          .toString(),
      data: item,
      imageUrl: resolveItemImageUrl(item['item_images'] ??
          item['image'] ??
          primaryImage ??
          item['image_url'] ??
          (gamefowl is Map ? gamefowl['images'] : null)),
      price: num.tryParse((item['effective_price'] ??
              item['item_price'] ??
              item['price'] ??
              item['selling_price'] ??
              '')
          .toString()),
    );
  }
}

/// Anchors suggestions outside the search header's clipping and layout bounds.
class SearchSuggestions extends StatefulWidget {
  const SearchSuggestions({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.onSelected,
    required this.child,
    this.minimumLength = 1,
    this.isLoading = false,
    this.error,
    this.onDismissed,
    this.grouped = false,
    this.emptyText = 'No matching products',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<SearchSuggestion> suggestions;
  final ValueChanged<SearchSuggestion> onSelected;
  final Widget child;
  final int minimumLength;
  final bool isLoading;
  final String? error;
  final VoidCallback? onDismissed;
  final bool grouped;
  final String emptyText;

  @override
  State<SearchSuggestions> createState() => _SearchSuggestionsState();
}

class _SearchSuggestionsState extends State<SearchSuggestions>
    with WidgetsBindingObserver {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _anchorKey = GlobalKey();
  final _tapGroup = Object();
  final _suggestionsScrollController =
      ScrollController(keepScrollOffset: false);
  ScrollPosition? _scrollPosition;
  String? _lastQuery;
  bool _syncScheduled = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focusNode.addListener(_focusChanged);
    widget.controller.addListener(_queryChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_changed);
      _scrollPosition = position;
      _scrollPosition?.addListener(_changed);
    }
  }

  @override
  void didUpdateWidget(covariant SearchSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_focusChanged);
      widget.focusNode.addListener(_focusChanged);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_queryChanged);
      widget.controller.addListener(_queryChanged);
    }
  }

  void _focusChanged() {
    if (!widget.focusNode.hasFocus) widget.onDismissed?.call();
    _changed();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _queryChanged() {
    final query = widget.controller.text.trim();
    if (query != _lastQuery) {
      _lastQuery = query;
      if (_suggestionsScrollController.hasClients) {
        _suggestionsScrollController.jumpTo(0);
      }
    }
    _changed();
  }

  @override
  void didChangeMetrics() => _changed();

  void _dismiss() {
    _portal.hide();
    widget.focusNode.unfocus();
  }

  void _scheduleVisibility() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      if (_visible) {
        _portal.show();
      } else {
        _portal.hide();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _visible = widget.focusNode.hasFocus &&
        widget.controller.text.trim().length >= widget.minimumLength &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    _scheduleVisibility();
    return TapRegion(
      groupId: _tapGroup,
      onTapOutside: (_) => _dismiss(),
      child: CompositedTransformTarget(
        key: _anchorKey,
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: _buildDropdown,
          child: widget.child,
        ),
      ),
    );
  }

  Widget _buildDropdown(BuildContext context) {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !_visible) {
      return const SizedBox.shrink();
    }
    final media = MediaQuery.of(context);
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final available = media.size.height -
        media.viewInsets.bottom -
        media.padding.bottom -
        bottom -
        6;
    if (available <= 0) return const SizedBox.shrink();
    final suggestions = widget.grouped
        ? [
            for (final type in SearchResultType.values)
              ...widget.suggestions.where((item) => item.type == type).take(6)
          ]
        : widget.suggestions.take(6).toList();
    return Positioned(
      width: box.size.width,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 6),
        child: TextFieldTapRegion(
          child: TapRegion(
            groupId: _tapGroup,
            child: Material(
              key: const ValueKey('search-suggestions-dropdown'),
              color: Colors.white,
              elevation: 5,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: math.min(280, available)),
                child: Scrollbar(
                  controller: _suggestionsScrollController,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _suggestionsScrollController,
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      if (widget.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Expanded(child: Text('Searching…')),
                          ]),
                        ),
                      for (var index = 0;
                          index < suggestions.length;
                          index++) ...[
                        if (widget.grouped &&
                            (index == 0 ||
                                suggestions[index - 1].type !=
                                    suggestions[index].type))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                                searchGroupLabel(suggestions[index].type),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ),
                        SearchSuggestionTile(
                          key: ValueKey(
                              'search-suggestion-${suggestions[index].type.name}-${suggestions[index].id}'),
                          suggestion: suggestions[index],
                          onTap: () {
                            _dismiss();
                            widget.onSelected(suggestions[index]);
                          },
                        ),
                      ],
                      if (widget.error != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(widget.error!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      if (!widget.isLoading &&
                          widget.error == null &&
                          suggestions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(widget.emptyText),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChanged);
    widget.controller.removeListener(_queryChanged);
    _scrollPosition?.removeListener(_changed);
    _suggestionsScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

String searchGroupLabel(SearchResultType type) => switch (type) {
      SearchResultType.product => 'Products',
      SearchResultType.shop => 'Shops',
      SearchResultType.farm => 'Partner Gamefarms',
      SearchResultType.gamefowl => 'Gamefowl',
    };

IconData searchGroupIcon(SearchResultType type) => switch (type) {
      SearchResultType.shop => Icons.storefront_outlined,
      SearchResultType.farm => Icons.agriculture_outlined,
      _ => Icons.image_outlined,
    };

class SearchSuggestionTile extends StatelessWidget {
  const SearchSuggestionTile(
      {super.key, required this.suggestion, required this.onTap});
  final SearchSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (suggestion.price != null) formatPeso(suggestion.price),
      if (suggestion.isBundle) 'Bundle',
    ].join(' \u00b7 ');
    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 40,
        height: 40,
        child: suggestion.imageUrl == null
            ? Icon(searchGroupIcon(suggestion.type))
            : Image.network(suggestion.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined)),
      ),
      title:
          Text(suggestion.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: details.isEmpty ? null : Text(details),
      onTap: onTap,
    );
  }
}
