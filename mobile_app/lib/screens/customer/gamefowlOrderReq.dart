import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../constants/constants.dart';
import '../../models/gamefowl_request_draft.dart';
import '../../widgets/custom_elevated_button.dart';
import 'gamefowlCheckoutScreen.dart';

class GamefowlOrderReq extends StatefulWidget {
  final Map<String, dynamic>? productData;
  final String? shopName;
  final dynamic shopId;

  const GamefowlOrderReq(
      {super.key, this.productData, this.shopName, this.shopId});

  @override
  State<GamefowlOrderReq> createState() => _GamefowlOrderReqState();
}

class _GamefowlOrderReqState extends State<GamefowlOrderReq> {
  final _chosenController = TextEditingController();
  final _wingbandController = TextEditingController();
  final _featherController = TextEditingController();
  final _feetController = TextEditingController();
  String? _featherColor;
  String? _feetColor;
  static const _featherColors = [
    'Black',
    'White',
    'Red',
    'Brown',
    'Gray',
    'Golden',
    'Mixed',
    'Other',
  ];
  static const _feetColors = [
    'Yellow',
    'White',
    'Black',
    'Gray',
    'Green',
    'Pink',
    'Other',
  ];
  PlatformFile? _selectedFile;
  bool _isPickingMedia = false;

  GamefowlProductSummary get _product =>
      GamefowlProductSummary.fromProduct(widget.productData);

  void _openCheckout() {
    final request = GamefowlRequestDraft(
      product: _product,
      chosenGamefowl: _chosenController.text.trim(),
      wingbandNo: _wingbandController.text.trim(),
      featherColor: _featherColor == 'Other'
          ? _featherController.text.trim()
          : _featherColor ?? '',
      feetColor: _feetColor == 'Other'
          ? _feetController.text.trim()
          : _feetColor ?? '',
      mediaName: _selectedFile?.name,
    );
    FocusScope.of(context).unfocus();
    Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GamefowlCheckoutScreen(request: request),
        ));
  }

  @override
  void initState() {
    super.initState();
    _chosenController.text = _product.productName ?? '';
  }

  @override
  void dispose() {
    _chosenController.dispose();
    _wingbandController.dispose();
    _featherController.dispose();
    _feetController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    if (_isPickingMedia) return;
    setState(() => _isPickingMedia = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'pdf'],
        allowMultiple: false,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      setState(() => _selectedFile = result.files.single);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to choose file. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isPickingMedia = false);
    }
  }

  BoxDecoration _borderedBox() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDefault),
      );

  Widget _label(String text) => Text(text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back,
              size: 24, color: AppColors.textSecondary),
        ),
        title: const Text('Order Request',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            )),
      ),
      body: Column(children: [
        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: _borderedBox(),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label('Order Requested'),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.borderDefault),
                  const SizedBox(height: 12),
                  _buildProductSummary(),
                  const SizedBox(height: 12),
                  _buildRequestFields(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.add_circle_outline, size: 24),
                    label: const Text('ADD MORE GAMEFOWL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.surfaceMuted,
                      side: const BorderSide(color: AppColors.borderDefault),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ]),
          ),
        )),
        SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: CustomElevatedButton(
                text: 'Proceed to Checkout',
                width: double.infinity,
                onPressed: _openCheckout,
              ),
            )),
      ]),
    );
  }

  Widget _buildProductSummary() {
    final product = _product;
    final imageUrl = product.imageUrl;
    final traits = product.traits;
    const placeholder = Center(
        child: Icon(Icons.image_outlined,
            size: 24, color: AppColors.textSecondary));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 64,
            height: 64,
            color: AppColors.borderDefault,
            child: imageUrl == null
                ? placeholder
                : Image.network(imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => placeholder),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(product.title),
          if (traits.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(traits,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.brandPrimary)),
          ],
          const SizedBox(height: 8),
          Text(
              product.price == null
                  ? 'Price unavailable'
                  : product.formattedPrice,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
        ])),
      ]),
    );
  }

  Widget _buildRequestFields() => Container(
        padding: const EdgeInsets.all(12),
        decoration: _borderedBox(),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _label('Chosen Gamefowl'),
          const SizedBox(height: 8),
          TextField(
            controller: _chosenController,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter chosen gamefowl',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.borderDefault)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.borderDefault)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.brandPrimary)),
            ),
          ),
          const SizedBox(height: 16),
          _label('Gamefowl Specific Details'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: _borderedBox(),
            child: Column(children: [
              _buildDetailInput('Wingband No.', _wingbandController),
              _buildColorInput(
                label: 'Feather Color',
                id: 'feather-color',
                colors: _featherColors,
                value: _featherColor,
                controller: _featherController,
                onChanged: (value) => setState(() => _featherColor = value),
              ),
              _buildColorInput(
                label: 'Feet Color',
                id: 'feet-color',
                colors: _feetColors,
                value: _feetColor,
                controller: _feetController,
                onChanged: (value) => setState(() => _feetColor = value),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _label('Add Media'),
          const SizedBox(height: 8),
          _buildMediaPicker(),
        ]),
      );

  Widget _buildDetailInput(String label, TextEditingController controller) =>
      _buildDetailRow(
          label,
          Semantics(
            label: label,
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: '—',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
              ),
            ),
          ));

  Widget _buildColorInput({
    required String label,
    required String id,
    required List<String> colors,
    required String? value,
    required TextEditingController controller,
    required ValueChanged<String?> onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDetailRow(
              label,
              Semantics(
                label: label,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(id),
                  value: value,
                  isExpanded: true,
                  menuMaxHeight: 300,
                  hint: const Text('Select color'),
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      size: 24, color: AppColors.textSecondary),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                  ),
                  items: colors
                      .map((color) => DropdownMenuItem(
                            value: color,
                            child: Text(color, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: onChanged,
                ),
              )),
          if (value == 'Other')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: ValueKey('custom-$id'),
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: label == 'Feather Color'
                      ? 'Custom feather color'
                      : 'Custom feet color',
                  labelStyle: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: AppColors.borderDefault)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: AppColors.borderDefault)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: AppColors.brandPrimary)),
                ),
              ),
            ),
        ],
      );

  Widget _buildDetailRow(String label, Widget field) =>
      LayoutBuilder(builder: (context, constraints) {
        final caption = Text('$label:',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary));
        if (constraints.maxWidth < 220 ||
            MediaQuery.textScalerOf(context).scale(12) > 18) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [caption, field]);
        }
        return Row(children: [
          SizedBox(width: 104, child: caption),
          Expanded(child: field),
        ]);
      });

  Widget _buildMediaPicker() => Container(
        padding: const EdgeInsets.all(8),
        decoration: _borderedBox(),
        child: LayoutBuilder(builder: (context, constraints) {
          final chooseButton = ElevatedButton(
            onPressed: _isPickingMedia ? null : _pickMedia,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Choose a file', style: TextStyle(fontSize: 12)),
          );
          final filename = Text(_selectedFile?.name ?? 'No file chosen',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary));
          final removeButton = _selectedFile == null
              ? null
              : IconButton(
                  tooltip: 'Remove file',
                  onPressed: () => setState(() => _selectedFile = null),
                  icon: const Icon(Icons.close,
                      size: 24, color: AppColors.textSecondary),
                );
          if (constraints.maxWidth < 240 ||
              MediaQuery.textScalerOf(context).scale(12) > 18) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  chooseButton,
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: filename),
                    if (removeButton != null) removeButton
                  ]),
                ]);
          }
          return Row(children: [
            chooseButton,
            const SizedBox(width: 8),
            Expanded(child: filename),
            if (removeButton != null) removeButton
          ]);
        }),
      );
}
