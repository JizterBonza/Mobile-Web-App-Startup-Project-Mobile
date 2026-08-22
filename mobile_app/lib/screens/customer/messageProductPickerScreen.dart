import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../constants/constants.dart';
import '../../models/messageModel.dart';
import '../../provider/message_provider.dart';
import '../../services/message_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/skeletons/app_skeletons.dart';

class MessageProductPickerScreen extends StatefulWidget {
  final dynamic shopId;
  final dynamic conversationId;
  final String? shopName;

  const MessageProductPickerScreen({
    super.key,
    required this.shopId,
    this.conversationId,
    this.shopName,
  });

  @override
  State<MessageProductPickerScreen> createState() =>
      _MessageProductPickerScreenState();
}

class _MessageProductPickerScreenState
    extends State<MessageProductPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MessageService _service = MessageService();
  Timer? _debounce;

  List<MessageProductSnapshot> _products = [];
  final Map<String, MessageProductVariation> _selectedVariation = {};
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  dynamic _sendingItemKey;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _productKey(MessageProductSnapshot product) =>
      product.id?.toString() ?? product.name;

  Future<void> _fetchProducts({String? search}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.fetchShopMessageProducts(
      shopId: widget.shopId,
      search: search,
    );

    if (!mounted) return;
    if (result['success'] == true && result['data'] is List) {
      setState(() {
        _products = List<MessageProductSnapshot>.from(result['data'] as List);
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _products = [];
      _isLoading = false;
      _error = result['message']?.toString() ?? 'Failed to load products';
    });
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchProducts(search: value.trim());
    });
  }

  Future<void> _sendProduct(MessageProductSnapshot product) async {
    if (_sendingItemKey != null) return;

    dynamic itemId = product.id;
    if (product.variations.isNotEmpty) {
      final selected = _selectedVariation[_productKey(product)];
      if (selected == null) {
        SnackbarHelper.showWarning(context, 'Select a variation first');
        return;
      }
      itemId = selected.id ?? product.id;
    }

    if (itemId == null) {
      SnackbarHelper.showError(context, 'This product cannot be sent');
      return;
    }

    setState(() => _sendingItemKey = _productKey(product));
    final provider = Provider.of<MessageProvider>(context, listen: false);
    final success = await provider.sendProductMessage(
      shopId: widget.shopId,
      conversationId: widget.conversationId ??
          provider.activeThread?.conversation.id,
      itemId: itemId,
    );

    if (!mounted) return;
    setState(() => _sendingItemKey = null);
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    SnackbarHelper.showError(
      context,
      provider.error ?? 'Failed to send product',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          toolbarHeight: 64,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          title: _buildHeader(),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF3F4F6),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.chevron_left,
                  size: 26,
                  color: Color(0xFF4B5563),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildSearchField()),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        cursorColor: AppColors.primaryGreen,
        decoration: InputDecoration(
          hintText: 'Search Product',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[400]),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: AppColors.primaryGreen),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _products.isEmpty) {
      return const ListRowsSkeleton(count: 8);
    }

    if (_error != null && _products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Failed to load products',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _fetchProducts(search: _searchQuery),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.shopping_bag_outlined,
        message: _searchQuery.trim().isEmpty
            ? 'No products to share'
            : 'No products found',
        subtitle: _searchQuery.trim().isEmpty
            ? 'This shop has no active items'
            : 'Try a different search',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchProducts(search: _searchQuery),
      color: AppColors.primaryGreen,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildProductCard(_products[index]),
      ),
    );
  }

  Widget _buildProductCard(MessageProductSnapshot product) {
    final key = _productKey(product);
    final selected = _selectedVariation[key];
    final isSending = _sendingItemKey == key;
    final busy = _sendingItemKey != null;
    final price = selected?.priceLabel ?? product.priceLabel;
    final original = selected?.originalPriceLabel ?? product.originalPriceLabel;
    final imageUrl = selected?.imageUrl ?? product.imageUrl;

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
              child: imageUrl == null || imageUrl.isEmpty
                  ? Container(
                      color: Colors.white,
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white,
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.primaryGreen,
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
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                if (product.variations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildVariationPicker(product, selected),
                ],
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          if (price != null && price.isNotEmpty)
                            Text(
                              price,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          if (original != null && original.isNotEmpty)
                            Text(
                              original,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : () => _sendProduct(product),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: const BorderSide(color: AppColors.primaryGreen),
                        minimumSize: const Size(64, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isSending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Send',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariationPicker(
    MessageProductSnapshot product,
    MessageProductVariation? selected,
  ) {
    return PopupMenuButton<MessageProductVariation>(
      onSelected: (variation) {
        setState(() => _selectedVariation[_productKey(product)] = variation);
      },
      itemBuilder: (context) {
        return product.variations
            .map(
              (variation) => PopupMenuItem(
                value: variation,
                child: Text(variation.name),
              ),
            )
            .toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected?.name ?? 'Select Variation',
              style: TextStyle(
                fontSize: 12,
                color: selected == null ? Colors.grey[500] : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}
