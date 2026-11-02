import 'package:flutter/material.dart';
import '../../constants/constants.dart';
import '../../models/gamefowl_request_draft.dart';
import '../../widgets/custom_elevated_button.dart';
import '../../utils/auth_guard.dart';
import '../../models/farm_checkout.dart';
import '../../services/farm_checkout_service.dart';
import '../../services/farms_service.dart';
import 'farmBirdRequestPicker.dart';
import 'gamefowlCheckoutScreen.dart';

class GamefowlOrderReq extends StatefulWidget {
  final Map<String, dynamic>? productData;
  final String? shopName;
  final dynamic shopId;
  final FarmCheckoutService? checkoutService;
  final FarmsService? farmsService;

  const GamefowlOrderReq(
      {super.key,
      this.productData,
      this.shopName,
      this.shopId,
      this.checkoutService,
      this.farmsService});

  @override
  State<GamefowlOrderReq> createState() => _GamefowlOrderReqState();
}

class _GamefowlOrderReqState extends State<GamefowlOrderReq> {
  late final FarmCheckoutService _service;
  late final int _farmId;
  final List<
          ({Map<String, dynamic> source, GlobalKey<_RequestItemFormState> key})>
      _selections = [];
  Map<String, String> _errors = {};
  bool _openingCheckout = false;

  @override
  void initState() {
    super.initState();
    _service = widget.checkoutService ?? FarmCheckoutService();
    final source = widget.productData ?? <String, dynamic>{};
    _farmId = farmInt(source['farm_id'] ?? farmMap(source['farm'])['id']);
    _selections.add((source: source, key: GlobalKey<_RequestItemFormState>()));
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _addBird() async {
    if (_openingCheckout) return;
    if (_farmId <= 0) {
      _notice('Reopen this gamefowl from its farm to load a valid listing.');
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FarmBirdRequestPicker(
        farmId: _farmId,
        excludedIds: _selections
            .map((entry) => entry.key.currentState!.draft.listingId)
            .toSet(),
        service: widget.farmsService ?? FarmsService(),
      ),
    );
    if (!mounted || selected == null) return;
    final selectedFarm =
        farmInt(selected['farm_id'] ?? farmMap(selected['farm'])['id']);
    final id = farmInt(selected['listing_id'] ?? selected['id']);
    if (selectedFarm != _farmId ||
        id <= 0 ||
        _selections.any(
            (entry) => entry.key.currentState!.draft.listingId == id)) return;
    setState(() {
      _selections
          .add((source: selected, key: GlobalKey<_RequestItemFormState>()));
      _errors = {};
    });
  }

  Future<void> _remove(int index) async {
    if (_openingCheckout || _selections.length <= 1) return;
    FocusScope.of(context).unfocus();
    final entry = _selections[index];
    if (entry.key.currentState!.draft.birds.any((bird) => !bird.isEmpty) &&
        !await _confirmDiscard(
            context, 'Removing this listing will discard its bird details.')) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _selections.remove(entry);
      _errors = {};
    });
  }

  Future<void> _openCheckout() async {
    if (_openingCheckout) return;
    setState(() => _openingCheckout = true);
    try {
      if (widget.checkoutService == null && !await requireAuth(context)) return;
      if (!mounted) return;
      if (_farmId <= 0 ||
          _selections
              .any((entry) => entry.key.currentState!.draft.listingId <= 0)) {
        _notice('Reopen this gamefowl from its farm to load a valid listing.');
        return;
      }
      final recovery = await _service.loadRecovery();
      if (!mounted) return;
      var changed = false;
      if (recovery == null) {
        for (final entry in _selections) {
          final result =
              await entry.key.currentState!.synchronize(_service, _farmId);
          if (!mounted) return;
          if (result == null) return;
          changed = changed || result;
        }
        setState(() => _errors = FarmBirdDetails.validateItems(_selections
            .map((entry) => entry.key.currentState!.draft.birds)
            .toList()));
        if (_errors.isNotEmpty || changed) {
          _notice(changed
              ? 'The cart quantity changed. Review the details for each bird before continuing.'
              : 'Complete the specific details for each bird before continuing.');
          return;
        }
      }
      final request = GamefowlRequestDraft(
        farmId: _farmId,
        items: List.unmodifiable(
            _selections.map((entry) => entry.key.currentState!.draft)),
      );
      FocusScope.of(context).unfocus();
      final errors = await Navigator.push<Map<String, String>>(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  GamefowlCheckoutScreen(request: request, service: _service)));
      if (mounted && errors != null) setState(() => _errors = errors);
    } catch (error) {
      if (mounted) _notice(error.toString());
    } finally {
      if (mounted) setState(() => _openingCheckout = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                  color: AppColors.textPrimary)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < _selections.length; i++)
              _RequestItemForm(
                key: _selections[i].key,
                source: _selections[i].source,
                itemIndex: i,
                busy: _openingCheckout,
                errors: _errors,
                onEdited: () {
                  if (_errors.isNotEmpty) setState(() => _errors = {});
                },
                onRemove: _selections.length > 1 ? () => _remove(i) : null,
              ),
            OutlinedButton.icon(
                onPressed: _openingCheckout ? null : _addBird,
                icon: const Icon(Icons.add),
                label: const Text('Add another bird')),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: CustomElevatedButton(
                text: 'Proceed to Checkout',
                width: double.infinity,
                onPressed: _openingCheckout ? null : _openCheckout),
          ),
        ),
      );
}

Future<bool> _confirmDiscard(BuildContext context, String message) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Remove bird details?'),
              content: Text(message),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep details')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove')),
              ],
            )) ==
    true;

class _RequestItemForm extends StatefulWidget {
  const _RequestItemForm(
      {super.key,
      required this.source,
      required this.itemIndex,
      required this.busy,
      required this.errors,
      required this.onEdited,
      this.onRemove});
  final Map<String, dynamic> source;
  final int itemIndex;
  final bool busy;
  final Map<String, String> errors;
  final VoidCallback onEdited;
  final VoidCallback? onRemove;
  @override
  State<_RequestItemForm> createState() => _RequestItemFormState();
}

class _RequestItemFormState extends State<_RequestItemForm> {
  final _chosenController = TextEditingController();
  bool get _openingCheckout => widget.busy;
  Map<String, String> get _errors => widget.errors;
  List<FarmBirdDetails> _birds = [];
  int _quantity = 1;
  bool _quantityEdited = false;
  int? _serverBirdsPerUnit;
  final Map<String, String> _colorSelections = {};
  final Map<String, String> _customColors = {};
  static const _featherColors = [
    'Black',
    'White',
    'Red',
    'Brown',
    'Gray',
    'Golden',
    'Mixed',
    'Other'
  ];
  static const _feetColors = [
    'Yellow',
    'White',
    'Black',
    'Gray',
    'Green',
    'Pink',
    'Other'
  ];

  int get _birdsPerUnit {
    if (_serverBirdsPerUnit != null) return _serverBirdsPerUnit!;
    final source = widget.source;
    final explicit = farmInt(source['birds_per_unit'] ?? source['bird_count']);
    if (explicit > 0) return explicit;
    final unit = source['selling_unit']?.toString().toLowerCase().trim();
    return const {
          'per head': 1,
          'per pair': 2,
          'per trio': 3,
          'per quadruplet': 4,
          'per dozen': 12
        }[unit] ??
        1;
  }

  Future<bool> _resizeBirds(int count) async {
    if (count < _birds.length && _birds.skip(count).any((b) => !b.isEmpty)) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Remove bird details?'),
                content: const Text(
                    'Reducing the quantity will discard details for the removed birds.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep details')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remove'))
                ],
              ));
      if (confirmed != true || !mounted) return false;
    }
    setState(() {
      _birds = List.generate(count,
          (i) => i < _birds.length ? _birds[i] : const FarmBirdDetails());
      widget.onEdited();
      bool removed(String key) => farmInt(key.split('.')[0]) >= count;
      _colorSelections.removeWhere((key, _) => removed(key));
      _customColors.removeWhere((key, _) => removed(key));
    });
    return true;
  }

  Future<void> _changeQuantity(int value) async {
    if (_openingCheckout || value < 1 || value > 100000) return;
    if (await _resizeBirds(value * _birdsPerUnit) && mounted) {
      setState(() {
        _quantity = value;
        _quantityEdited = true;
      });
    }
  }

  GamefowlProductSummary get _product =>
      GamefowlProductSummary.fromProduct(widget.source);

  GamefowlRequestItem get draft => GamefowlRequestItem(
        listingId: farmInt(widget.source['listing_id'] ??
            ((farmInt(widget.source['farm_id'] ??
                        farmMap(widget.source['farm'])['id']) >
                    0)
                ? widget.source['id']
                : null)),
        product: _product,
        quantity: _quantity,
        sellingUnit: widget.source['selling_unit']?.toString() ?? '',
        birds: List.unmodifiable(_birds),
      );

  // null means the user cancelled discarding entered details.
  Future<bool?> synchronize(FarmCheckoutService service, int farmId) async {
    var item = await service.prepareCart(draft.listingId, farmId);
    if (!mounted) return null;
    if (item.farmId != farmId || item.listingId != draft.listingId) {
      throw const FarmApiException('Select listings from the same farm.');
    }
    if (_quantityEdited && item.quantity != _quantity) {
      item = await service.setQuantity(item, _quantity);
      if (!mounted) return null;
    }
    if (item.farmId != farmId ||
        item.listingId != draft.listingId ||
        !item.available) {
      throw const FarmApiException('This listing is no longer available.');
    }
    final changed =
        item.birdCount != _birds.length || item.quantity != _quantity;
    if (!await _resizeBirds(item.birdCount) || !mounted) return null;
    setState(() {
      if (item.birdCount % item.quantity == 0) {
        _serverBirdsPerUnit = item.birdCount ~/ item.quantity;
      }
      _quantity = item.quantity;
      _quantityEdited = false;
    });
    return changed;
  }

  @override
  void initState() {
    super.initState();
    _chosenController.text = _product.productName ?? '';
    _birds = List.generate(_birdsPerUnit, (_) => const FarmBirdDetails());
  }

  @override
  void dispose() {
    _chosenController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: _borderedBox(),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: _label('Order Requested')),
            if (widget.onRemove != null)
              TextButton(
                  key: ValueKey('remove-listing-${draft.listingId}'),
                  onPressed: _openingCheckout ? null : widget.onRemove,
                  child: const Text('Remove')),
          ]),
          const SizedBox(height: 12),
          _buildProductSummary(),
          const SizedBox(height: 12),
          _buildRequestFields(),
          const SizedBox(height: 12),
          Text(
              'Selling unit: ${draft.sellingUnit.isEmpty ? 'per head' : draft.sellingUnit}'),
          Row(children: [
            IconButton(
                tooltip: 'Decrease quantity',
                onPressed: _openingCheckout || _quantity <= 1
                    ? null
                    : () => _changeQuantity(_quantity - 1),
                icon: const Icon(Icons.remove)),
            Expanded(
                child:
                    Text('Quantity: $_quantity', textAlign: TextAlign.center)),
            IconButton(
                tooltip: 'Increase quantity',
                onPressed: _openingCheckout || _quantity >= 100000
                    ? null
                    : () => _changeQuantity(_quantity + 1),
                icon: const Icon(Icons.add)),
          ]),
          Text('${_birds.length} ${_birds.length == 1 ? 'head' : 'heads'}'),
          if (_errors['items.${widget.itemIndex}'] != null)
            Text(_errors['items.${widget.itemIndex}']!,
                style: const TextStyle(color: Colors.red)),
          ...List.generate(_birds.length, _birdForm),
        ]),
      );

  Widget _buildProductSummary() {
    final product = _product;
    final imageUrl = product.imageUrl;
    final traits = product.bloodline == null
        ? product.traits
        : [product.title, product.age, product.sex]
            .whereType<String>()
            .join(' | ');
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
          _label((product.bloodline ?? product.title).toUpperCase()),
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
            key: ValueKey(widget.itemIndex == 0
                ? 'chosen-gamefowl'
                : 'chosen-gamefowl-${draft.listingId}'),
            controller: _chosenController,
            readOnly: true,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'No gamefowl selected',
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
        ]),
      );
  void _updateBird(int index, String field, String value) {
    final bird = _birds[index];
    _birds[index] = FarmBirdDetails(
      wingband: field == 'wingband_no' ? value : bird.wingband,
      feather: field == 'feather_color' ? value : bird.feather,
      feet: field == 'feet_color' ? value : bird.feet,
    );
    widget.onEdited();
  }

  InputDecoration _detailDecoration(String path, {String? hint}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        border: InputBorder.none,
        counterText: '',
        errorText: _errors[path],
        errorMaxLines: 3,
      );

  Widget _detailRow(String label, Widget field) =>
      LayoutBuilder(builder: (context, constraints) {
        final caption = Text('$label:',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary));
        if (constraints.maxWidth < 220 ||
            MediaQuery.textScalerOf(context).scale(12) > 18) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [caption, field]);
        }
        return Row(children: [
          SizedBox(width: 104, child: caption),
          Expanded(child: field)
        ]);
      });

  Widget _colorField(int index, String label, String field, List<String> colors,
      String value) {
    final path = 'items.${widget.itemIndex}.birds.$index.$field';
    final localKey = '$index.$field';
    final selected = _colorSelections[localKey] ??
        (value.isEmpty
            ? null
            : colors.contains(value)
                ? value
                : 'Other');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _detailRow(
          label,
          Semantics(
              label: 'Bird ${index + 1} $label',
              child: DropdownButtonFormField<String>(
                key: ValueKey(path),
                value: selected,
                isExpanded: true,
                menuMaxHeight: 300,
                hint: const Text('Select color'),
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 24, color: AppColors.textSecondary),
                decoration: _detailDecoration(path),
                items: colors
                    .map((color) => DropdownMenuItem(
                        value: color,
                        child: Text(color, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: _openingCheckout
                    ? null
                    : (selection) {
                        if (selection == null) return;
                        setState(() {
                          _colorSelections[localKey] = selection;
                          _updateBird(
                              index,
                              field,
                              selection == 'Other'
                                  ? _customColors[localKey] ?? ''
                                  : selection);
                        });
                      },
              ))),
      if (selected == 'Other')
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              key: ValueKey('custom-$path'),
              initialValue: _customColors[localKey] ?? value,
              readOnly: _openingCheckout,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                  labelText: 'Custom ${label.toLowerCase()}',
                  labelStyle: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  contentPadding: const EdgeInsets.all(10),
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                  errorText: _errors[path],
                  errorMaxLines: 3),
              onChanged: (text) => setState(() {
                _customColors[localKey] = text;
                _updateBird(index, field, text);
              }),
            )),
    ]);
  }

  Widget _birdForm(int index) {
    final bird = _birds[index];
    final prefix = 'items.${widget.itemIndex}.birds.$index';
    return Padding(
        padding: const EdgeInsets.only(top: 12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _label('Bird ${index + 1}: Specific Details'),
          const SizedBox(height: 8),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: _borderedBox(),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errors[prefix] != null)
                      Text(_errors[prefix]!,
                          style: const TextStyle(color: Colors.red)),
                    _detailRow(
                        'Wingband No.',
                        Semantics(
                            label: 'Bird ${index + 1} Wingband No.',
                            child: TextFormField(
                              key: ValueKey('$prefix.wingband_no'),
                              initialValue: bird.wingband,
                              readOnly: _openingCheckout,
                              maxLength: 100,
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.textPrimary),
                              decoration: _detailDecoration(
                                  '$prefix.wingband_no',
                                  hint: '\u2014'),
                              onChanged: (value) => setState(() =>
                                  _updateBird(index, 'wingband_no', value)),
                            ))),
                    _colorField(index, 'Feather Color', 'feather_color',
                        _featherColors, bird.feather),
                    _colorField(index, 'Feet Color', 'feet_color', _feetColors,
                        bird.feet),
                  ])),
        ]));
  }
}
