import '../utils/manila_time.dart';
import 'farm_checkout.dart';

enum CustomerOrderKind { item, farm, unavailable }

enum FarmOrderDetailState { idle, loading, loaded, failed, unavailable }

/// A projection of shared orders, without converting farm items into shop items.
class CustomerOrderEntry {
  const CustomerOrderEntry(
      {required this.id,
      this.basic,
      this.farm,
      this.detailState = FarmOrderDetailState.idle,
      this.detailError});
  final String id;
  final Map<String, dynamic>? basic;
  final FarmOrder? farm;
  final FarmOrderDetailState detailState;
  final String? detailError;

  static String normalizedId(dynamic value) {
    final parsed = farmInt(value);
    return parsed > 0 ? parsed.toString() : value?.toString().trim() ?? '';
  }

  CustomerOrderKind get kind {
    if (farm != null ||
        basic?['farm_order'] is Map ||
        farmInt(basic?['farm_order_id']) > 0 ||
        farmInt(basic?['farm_id']) > 0 ||
        ['farm', 'gamefowl']
            .contains(basic?['order_type']?.toString().toLowerCase())) {
      return CustomerOrderKind.farm;
    }
    if (basic != null &&
        basic!.containsKey('order_detail_id') &&
        basic!['order_detail_id'] == null &&
        basic!['order_detail'] is! Map &&
        farmMaps(basic!['order_items']).isEmpty &&
        farmMaps(basic!['order_shops']).isEmpty) {
      return CustomerOrderKind.unavailable;
    }
    return CustomerOrderKind.item;
  }

  DateTime? get orderedAt =>
      ManilaTime.tryParseUtc(basic?['ordered_at']) ??
      ManilaTime.tryParseUtc(basic?['created_at']) ??
      ManilaTime.tryParseUtc(
          farm?.data['ordered_at'] ?? farm?.data['created_at']);
  String get code {
    final farmCode = farmText(farm?.data['order_code']);
    final basicCode = farmText(basic?['order_code']);
    return farmCode.isNotEmpty
        ? farmCode
        : basicCode.isNotEmpty
            ? basicCode
            : '#$id';
  }

  static List<CustomerOrderEntry> merge(
      List<Map<String, dynamic>> basicOrders, Iterable<FarmOrder> farms,
      {Map<int, FarmOrderDetailState> states = const {},
      Map<int, String> errors = const {}}) {
    final baseById = <String, Map<String, dynamic>>{};
    for (final order in basicOrders) {
      final id = normalizedId(order['id'] ?? order['order_id']);
      if (id.isNotEmpty) baseById[id] = order;
    }
    final farmById = {for (final order in farms) order.id.toString(): order};
    final ids = {...baseById.keys, ...farmById.keys}.toList();
    final entries = ids
        .map((id) => CustomerOrderEntry(
            id: id,
            basic: baseById[id],
            farm: farmById[id],
            detailState: states[farmInt(id)] ?? FarmOrderDetailState.idle,
            detailError: errors[farmInt(id)]))
        .toList();
    final positions = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    entries.sort((a, b) {
      final first = a.orderedAt;
      final second = b.orderedAt;
      if (first == null && second != null) return 1;
      if (first != null && second == null) return -1;
      final dateResult = first == null ? 0 : second!.compareTo(first);
      return dateResult != 0
          ? dateResult
          : positions[a.id]!.compareTo(positions[b.id]!);
    });
    return entries;
  }
}

String farmText(dynamic value) =>
    value is Map ? farmText(value['name']) : value?.toString().trim() ?? '';

class FarmOrderItemView {
  FarmOrderItemView(this.data);
  final Map<String, dynamic> data;
  Map<String, dynamic> get snapshot =>
      farmMap(data['listing_snapshot'] ?? data['listing']);
  Map<String, dynamic> get gamefowl =>
      farmMap(snapshot['gamefowl'] ?? data['gamefowl']);
  String get title {
    for (final value in [
      gamefowl['bloodline'],
      data['bloodline'],
      data['listing_name'],
      snapshot['name'],
      data['name'],
      data['item_name']
    ]) {
      if (farmText(value).isNotEmpty) return farmText(value);
    }
    final listingId = farmInt(data['listing_id']);
    return listingId > 0 ? 'Gamefowl listing #$listingId' : 'Gamefowl';
  }

  String get traits => [
        gamefowl['class'],
        gamefowl['age_type'] ?? gamefowl['age'],
        gamefowl['sex']
      ].map(farmText).where((text) => text.isNotEmpty).join(' | ');
  int get quantity => farmInt(data['quantity']);
  String get sellingUnit => farmText(data['selling_unit']);
  List<Map<String, dynamic>> get birds => farmMaps(data['birds']);
  int get headCount =>
      data['bird_count'] == null ? birds.length : farmInt(data['bird_count']);
  String? get image {
    String? imagePath(dynamic image) {
      final candidates = image is Map
          ? [image['url'], image['image_url'], image['path'], image['image']]
          : [image];
      for (final candidate in candidates) {
        if (candidate is! String) continue;
        final path = candidate.trim();
        if (path.isNotEmpty && path.toLowerCase() != 'null') return path;
      }
      return null;
    }

    final catalog = data['catalog'];
    final entries = catalog is List ? farmMaps(catalog) : [farmMap(catalog)];
    for (final entry in entries) {
      final images = entry['images'];
      for (final image in images is List ? images : [images]) {
        final path = imagePath(image);
        if (path != null) return path;
      }
    }
    for (final value in [
      data['image_url'],
      data['image'],
      snapshot['image_url'],
      snapshot['image']
    ]) {
      final path = imagePath(value);
      if (path != null) return path;
    }
    return null;
  }
}

class FarmOrderView {
  FarmOrderView(this.order);
  final FarmOrder order;
  Map<String, dynamic> get data => order.data;
  List<FarmOrderItemView> get items =>
      farmMaps(data['items']).map(FarmOrderItemView.new).toList();
  String get farmName =>
      farmText(data['farm_name'] ?? farmMap(data['farm'])['name']);
  String get status => farmText(data['status']);
  String get fulfillment => farmText(data['fulfillment_method']);
  String get paymentLabel => order.depositPaid
      ? (data['payment_status'] == 'paid' ? 'Paid' : 'Deposit paid')
      : order.closed
          ? 'Order closed'
          : 'Deposit pending';
  String get totalLabel =>
      data['final_total'] == null ? 'Estimated total' : 'Total';
  String get total => data['final_total'] != null
      ? farmMoney(data['final_total'])
      : data['estimated_total_min'] != null &&
              data['estimated_total_max'] != null
          ? '${farmMoney(data['estimated_total_min'])} - ${farmMoney(data['estimated_total_max'])}'
          : 'Not confirmed';
}
