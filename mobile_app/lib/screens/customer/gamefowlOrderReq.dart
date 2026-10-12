
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'checkOutScreen.dart';

class GamefowlOrderReq extends StatefulWidget {
  final Map<String, dynamic>? productData;
  final String? shopName;
  final dynamic shopId;

  const GamefowlOrderReq({
    super.key,
    this.productData,
    this.shopName,
    this.shopId,
  });

  @override
  State<GamefowlOrderReq> createState() => _GamefowlOrderReqState();
}

class _GamefowlOrderReqState extends State<GamefowlOrderReq> {
  final List<_GamefowlRequestEntry> _gamefowls = [
    _GamefowlRequestEntry(),
  ];

  PlatformFile? _selectedFile;
  bool _isProceeding = false;

  static const Color primaryBlue = Color(0xFF263F91);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color textColor = Color(0xFF242735);
  static const Color mutedColor = Color(0xFF92949C);
  static const Color borderColor = Color(0xFFE5E6EA);

  @override
  void initState() {
    super.initState();

    final productName = _getProductName();
    _gamefowls.first.chosenController.text =
        productName == 'Gamefowl' ? '' : productName;
  }

  String _getProductName() {
    final product = widget.productData;
    final value = product?['item_name'] ??
        product?['product_name'] ??
        product?['name'] ??
        product?['title'];

    final name = value?.toString().trim() ?? '';
    return name.isEmpty ? 'Gamefowl' : name;
  }

  String _getGamefowlType() {
    final product = widget.productData;
    final value = product?['gamefowl_type'] ??
        product?['fowl_type'] ??
        product?['breed_type'] ??
        product?['type'] ??
        product?['category_name'];

    final type = value?.toString().trim() ?? '';
    return type.isEmpty ? 'One way / Pure' : type;
  }

  String _getAge() {
    final product = widget.productData;
    final value = product?['age'] ??
        product?['gamefowl_age'] ??
        product?['fowl_age'];

    final age = value?.toString().trim() ?? '';
    return age.isEmpty ? '6 weeks' : age;
  }

  String _getGender() {
    final product = widget.productData;
    final value = product?['gender'] ??
        product?['sex'] ??
        product?['gamefowl_gender'];

    final gender = value?.toString().trim() ?? '';
    return gender.isEmpty ? 'Male' : gender;
  }

  double _getNumericPrice() {
    final product = widget.productData;
    final value = product?['item_price'] ??
        product?['price'] ??
        product?['selling_price'] ??
        product?['product_price'] ??
        product?['amount'];

    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _getPrice() {
    final price = _getNumericPrice();
    return price == price.roundToDouble()
        ? '₱${price.toStringAsFixed(0)}'
        : '₱${price.toStringAsFixed(2)}';
  }

  @override
  void dispose() {
    for (final entry in _gamefowls) {
      entry.dispose();
    }
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'mp4',
          'mov',
          'pdf',
        ],
        allowMultiple: false,
      );

      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      setState(() {
        _selectedFile = result.files.single;
      });
    } catch (e) {
      _showMessage('Unable to choose file: $e');
    }
  }

  void _addGamefowl() {
    setState(() {
      _gamefowls.add(_GamefowlRequestEntry());
    });
  }

  void _removeGamefowl(int index) {
    if (_gamefowls.length == 1) return;

    setState(() {
      final removedEntry = _gamefowls.removeAt(index);
      removedEntry.dispose();
    });
  }

  int? _readPositiveInt(dynamic value) {
    if (value is int && value > 0) return value;

    if (value is num && value > 0 && value == value.toInt()) {
      return value.toInt();
    }

    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed > 0) return parsed;
    }

    return null;
  }

  Future<void> _proceedToCheckout() async {
    if (_isProceeding) return;

    for (var i = 0; i < _gamefowls.length; i++) {
      if (_gamefowls[i].chosenController.text.trim().isEmpty) {
        _showMessage(
          'Please enter the chosen gamefowl for entry ${i + 1}.',
        );
        return;
      }
    }

    final product = widget.productData;

    if (product == null || product.isEmpty) {
      _showMessage('Product information is missing.');
      return;
    }

    final price = _getNumericPrice();

    if (price <= 0) {
      _showMessage(
        'The product price is missing or invalid. Please check the product information.',
      );
      return;
    }

    // This is the product/item ID, NOT a cart-row ID.
    final itemId = _readPositiveInt(product['item_id']) ??
        _readPositiveInt(product['product_id']) ??
        _readPositiveInt(product['id']);

    final resolvedShopId =
        widget.shopId ?? product['shop_id'];

    final parsedShopId = _readPositiveInt(resolvedShopId);

    if (itemId == null) {
      _showMessage('The product item ID is missing or invalid.');
      return;
    }

    if (parsedShopId == null) {
      _showMessage('The shop ID is missing or invalid.');
      return;
    }

    setState(() {
      _isProceeding = true;
    });

    try {
      final first = _gamefowls.first;

      final requestData = <String, dynamic>{
        'product_id': product['product_id'] ?? product['id'],
        'item_id': itemId,
        'shop_id': parsedShopId,
        'shop_name': widget.shopName ??
            product['shop_name']?.toString() ??
            'Gamefarm',
        'gamefowl_name': first.chosenController.text.trim(),
        'wingband_no': first.wingbandController.text.trim(),
        'feather_color': first.featherController.text.trim(),
        'feet_color': first.feetController.text.trim(),
        'gamefowls': _gamefowls
            .map((entry) => entry.toMap())
            .toList(),
        // Local file information only. This does not upload the file.
        'media_path': _selectedFile?.path,
        'media_name': _selectedFile?.name,
        'media_extension': _selectedFile?.extension,
        'media_size': _selectedFile?.size,
        'product_data': product,
      };

      final checkoutItem = <String, dynamic>{
        ...product,

        // Product ID only. Never invent a cart-row ID.
        'id': itemId,
        'item_id': itemId,
        'shop_id': parsedShopId,
        'shop_name': widget.shopName ??
            product['shop_name']?.toString() ??
            'Gamefarm',
        'item_name': product['item_name'] ??
            product['product_name'] ??
            product['name'] ??
            product['title'] ??
            'Gamefowl',
        'quantity': 1,
        'price_at_purchase': price,
        'is_direct_gamefowl_order': true,
        'gamefowl_request': requestData,
      };

      if (!mounted) return;

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => CheckOutScreen(
            selectedCartItems: [checkoutItem],
          ),
        ),
      );
    } catch (e) {
      _showMessage('Unable to proceed to checkout: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProceeding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: false,
        leadingWidth: 48,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF62656D),
          ),
        ),
        title: const Text(
          'Order Request',
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Order Requested',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: borderColor),
                    const SizedBox(height: 14),
                    _buildProductSummary(),
                    const SizedBox(height: 16),
                    ...List.generate(_gamefowls.length, (index) {
                      final entry = _gamefowls[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _gamefowls.length > 1
                                        ? 'Chosen Gamefowl ${index + 1}'
                                        : 'Chosen Gamefowl',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                if (_gamefowls.length > 1)
                                  IconButton(
                                    onPressed: () =>
                                        _removeGamefowl(index),
                                    tooltip: 'Remove gamefowl',
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildInputField(
                              controller: entry.chosenController,
                              hint: 'Enter chosen gamefowl',
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Gamefowl Specific Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFF0F0F2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildDetailInput(
                                    label: 'Wingband No.',
                                    controller: entry.wingbandController,
                                    hint: 'Enter wingband number',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailInput(
                                    label: 'Feather Color:',
                                    controller: entry.featherController,
                                    hint: 'Enter feather color',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailInput(
                                    label: 'Feet Color:',
                                    controller: entry.feetController,
                                    hint: 'Enter feet color',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 2),
                    const Text(
                      'Add Media',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickMedia,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: primaryBlue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Choose a file',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedFile?.name ?? 'No file chosen',
                                style: const TextStyle(
                                  color: mutedColor,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedFile != null)
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedFile = null;
                                  });
                                },
                                tooltip: 'Remove file',
                                icon: const Icon(Icons.close_rounded),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _addGamefowl,
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          'ADD MORE GAMEFOWL',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryBlue,
                          side: const BorderSide(color: primaryBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            color: backgroundColor,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed:
                      _isProceeding ? null : _proceedToCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    disabledBackgroundColor:
                        primaryBlue.withOpacity(0.6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isProceeding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Proceed to Checkout',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSummary() {
    final product = widget.productData;
    final rawImage = product?['item_images'] ??
        product?['image_url'] ??
        product?['image'] ??
        product?['product_image'] ??
        product?['item_image'];

    String imageUrl = '';

    if (rawImage is List && rawImage.isNotEmpty) {
      final first = rawImage.first;
      imageUrl = first is Map
          ? (first['image_url'] ?? first['url'] ?? first['path'])
                  ?.toString() ??
              ''
          : first.toString();
    } else if (rawImage is Map) {
      imageUrl =
          (rawImage['image_url'] ?? rawImage['url'] ?? rawImage['path'])
                  ?.toString() ??
              '';
    } else {
      imageUrl = rawImage?.toString() ?? '';
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Container(
              width: 68,
              height: 68,
              color: const Color(0xFFD0D1D3),
              child: imageUrl.startsWith('http')
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGamefowlType(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.shopName ?? 'Golden Boy Sweater'} | '
                  '${_getAge()} | ${_getGender()}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF287C43),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getPrice(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 15,
          color: textColor,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 14,
            color: mutedColor,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(
              color: primaryBlue,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailInput({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: mutedColor,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 14,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB8BAC0),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GamefowlRequestEntry {
  final TextEditingController chosenController =
      TextEditingController();

  final TextEditingController wingbandController =
      TextEditingController();

  final TextEditingController featherController =
      TextEditingController();

  final TextEditingController feetController =
      TextEditingController();

  Map<String, dynamic> toMap() {
    return {
      'gamefowl_name': chosenController.text.trim(),
      'wingband_no': wingbandController.text.trim(),
      'feather_color': featherController.text.trim(),
      'feet_color': feetController.text.trim(),
    };
  }

  void dispose() {
    chosenController.dispose();
    wingbandController.dispose();
    featherController.dispose();
    feetController.dispose();
  }
}