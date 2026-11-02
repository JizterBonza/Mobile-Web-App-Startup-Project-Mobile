import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/farm_checkout.dart';
import '../utils/api_endpoints.dart';
import 'api_service.dart';

/// Farm endpoints deliberately do not use the shop order or cart APIs.
class FarmCheckoutService {
  FarmCheckoutService(
      {http.Client? httpClient,
      String? baseUrl,
      Future<String?> Function()? tokenLoader,
      Future<String?> Function()? userLoader})
      : _client = httpClient,
        _baseUrl = baseUrl,
        _tokenLoader = tokenLoader ?? ApiService.getToken,
        _userLoader = userLoader ?? ApiService.getUserId;

  final http.Client? _client;
  final String? _baseUrl;
  final Future<String?> Function() _tokenLoader;
  final Future<String?> Function() _userLoader;
  String? _customer;

  Future<String> customerId() async {
    final id = await _userLoader();
    final token = await _tokenLoader();
    if (id == null || id.isEmpty || token == null || token.isEmpty) {
      throw const FarmApiException('Please log in as a customer to checkout.',
          statusCode: 401);
    }
    if (_customer != null && _customer != id) {
      throw const FarmApiException('Your account changed. Reopen checkout.',
          statusCode: 401);
    }
    _customer = id;
    return id;
  }

  Future<({Map<String, dynamic> body, int status})> _request(
      String method, String path,
      {Map<String, dynamic>? body, String? idempotencyKey}) async {
    await customerId();
    final token = await _tokenLoader();
    final origin =
        (_baseUrl ?? ApiEndpoints.baseUrl).replaceFirst(RegExp(r'/+$'), '');
    final api = origin.endsWith('/api') ? origin : '$origin/api';
    final request = http.Request(method, Uri.parse('$api/$path'))
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey
      });
    if (body != null) request.body = jsonEncode(body);
    final client = _client ?? http.Client();
    try {
      final response = await (() async =>
              http.Response.fromStream(await client.send(request)))()
          .timeout(const Duration(seconds: 20));
      Map<String, dynamic> decoded;
      try {
        decoded = farmMap(jsonDecode(response.body));
      } on FormatException {
        throw FarmApiException('The server returned an unreadable response.',
            statusCode: response.statusCode);
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] == false) {
        throw FarmApiException(
            decoded['message']?.toString() ?? 'Unable to complete the request.',
            statusCode: response.statusCode,
            errors: farmMap(decoded['errors']),
            data: farmMap(decoded['data'] ?? decoded),
            retryAfter: response.headers['retry-after']);
      }
      return (body: decoded, status: response.statusCode);
    } on TimeoutException {
      throw const FarmApiException(
          'The connection timed out. Your request may have reached the server.');
    } on http.ClientException {
      throw const FarmApiException(
          'Connection interrupted. Please retry safely.');
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<List<FarmCartItem>> cart() async {
    final result = await _request('GET', 'farm-cart');
    if (result.body['data'] is! List) {
      throw const FormatException(
          'Invalid farm cart response. Please refresh.');
    }
    for (final group in result.body['data'] as List) {
      if (group is! Map ||
          group['items'] is! List ||
          (group['items'] as List).any((item) => item is! Map)) {
        throw const FormatException('Invalid farm cart group. Please refresh.');
      }
    }
    return farmMaps(result.body['data'])
        .expand((group) => farmMaps(group['items'])
            .map((item) => FarmCartItem(item, farmInt(group['farm_id']))))
        .toList();
  }

  Future<FarmCartItem> prepareCart(int listingId, int farmId) async {
    var entries = await cart();
    var matches =
        entries.where((e) => e.listingId == listingId && e.farmId == farmId);
    if (matches.isEmpty) {
      await _request('POST', 'farm-cart/items',
          body: {'listing_id': listingId, 'quantity': 1});
      // GET is authoritative and also supplies the selling-unit bird count.
      entries = await cart();
      matches =
          entries.where((e) => e.listingId == listingId && e.farmId == farmId);
    }
    if (matches.length != 1) {
      throw const FarmApiException(
          'Refresh this farm listing before checkout.');
    }
    return matches.single;
  }

  Future<FarmCartItem> setQuantity(FarmCartItem item, int quantity) async {
    await _request('PATCH', 'farm-cart/items/${item.id}',
        body: {'quantity': quantity});
    final entries = await cart();
    final matches =
        entries.where((e) => e.id == item.id && e.farmId == item.farmId);
    if (matches.length != 1) {
      throw const FarmApiException('This cart entry is no longer available.');
    }
    return matches.single;
  }

  Future<FarmQuote> quote(
      List<FarmCartItem> items, String fulfillment, int? addressId) async {
    if (items.isEmpty ||
        items.any((item) => item.farmId != items.first.farmId) ||
        items.map((item) => item.listingId).toSet().length != items.length ||
        items.map((item) => item.id).toSet().length != items.length) {
      throw const FarmApiException(
          'Select distinct listings from the same farm.');
    }
    final requestedAt = DateTime.now();
    final result = await _request('POST', 'farm-checkout/quote', body: {
      'farm_id': items.first.farmId,
      'cart_item_ids': items.map((item) => item.id).toList(),
      'fulfillment_method': fulfillment,
      if (fulfillment == 'delivery') 'shipping_address_id': addressId,
    });
    return FarmQuote(farmMap(result.body['data']), requestedAt);
  }

  Future<FarmOrder> createOrder(
      String key, Map<String, dynamic> payload) async {
    final result = await _request('POST', 'farm-orders',
        body: payload, idempotencyKey: key);
    return FarmOrder(farmMap(result.body['data']));
  }

  Future<FarmOrder> order(int id) async {
    final order = FarmOrder(
        farmMap((await _request('GET', 'farm-orders/$id')).body['data']));
    if (order.id != id) {
      throw const FormatException(
          'Order response ID did not match the requested order.');
    }
    return order;
  }

  Future<List<FarmOrder>> fetchOrders() async {
    final orders = <FarmOrder>[];
    var page = 1;
    while (true) {
      final data = farmMap(
          (await _request('GET', 'farm-orders?page=$page')).body['data']);
      if (data['data'] is! List || farmInt(data['last_page']) < 1) {
        throw const FormatException(
            'Invalid farm orders response. Please refresh.');
      }
      orders.addAll(farmMaps(data['data']).map(FarmOrder.new));
      if (page >= farmInt(data['last_page'])) break;
      page++;
    }
    return orders;
  }

  Future<List<FarmOrder>> pendingOrders() async => (await fetchOrders())
      .where((order) => !order.depositPaid && !order.closed)
      .toList();

  Future<FarmPaymentSession> depositSession(int orderId) async {
    final result = await _request(
        'POST', 'farm-orders/$orderId/payment-session',
        body: {'purpose': 'deposit'});
    return FarmPaymentSession(farmMap(result.body['data']), result.status);
  }

  Future<FarmPaymentSession> balanceSession(int orderId) async {
    final result = await _request(
        'POST', 'farm-orders/$orderId/payment-session',
        body: {'purpose': 'balance'});
    return FarmPaymentSession(farmMap(result.body['data']), result.status);
  }

  Future<Map<String, dynamic>> reconcile(int orderId) async =>
      (await _request('GET', 'payment/status/$orderId')).body;

  Future<Map<String, dynamic>?> loadRecovery() async {
    final customer = await customerId();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('farm_checkout.$customer');
    if (raw == null) return null;
    try {
      return farmMap(jsonDecode(raw));
    } on FormatException {
      throw const FarmApiException(
          'Saved checkout could not be read. Do not resubmit; check your orders first.');
    }
  }

  Future<void> saveRecovery(Map<String, dynamic> data) async {
    final customer = await customerId();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('farm_checkout.$customer', jsonEncode(data))) {
      throw const FarmApiException(
          'Unable to save checkout recovery. Please try again.');
    }
  }

  Future<void> clearRecovery() async {
    final customer = await customerId();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove('farm_checkout.$customer')) {
      throw const FarmApiException(
          'Unable to update saved checkout. Please try again.');
    }
  }

  String newKey() {
    final random = Random.secure();
    return List.generate(
            24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
