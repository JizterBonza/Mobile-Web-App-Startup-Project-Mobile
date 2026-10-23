import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../utils/gamefowl_item.dart';
import '../services/api_service.dart';

class CartService extends ApiService {

  CartService({http.Client? httpClient})

      : _httpClient = httpClient;

  final http.Client? _httpClient;

  http.Client get _client => _httpClient ?? http.Client();

  dynamic _decodeResponse(String body) {

    try {

      return jsonDecode(body);

    } catch (_) {

      return <String, dynamic>{'message': body};

    }

  }

  Map<String, dynamic> _toMap(dynamic value) {

    if (value is Map<String, dynamic>) return value;

    if (value is Map) {

      return Map<String, dynamic>.from(value);

    }

    return <String, dynamic>{};

  }

  dynamic _normalizeId(dynamic value) {

    if (value == null) return null;

    if (value is int) {

      return value > 0 ? value : null;

    }

    if (value is num) {

      return value > 0 ? value.toInt() : null;

    }

    final parsed = int.tryParse(value.toString().trim());

    return parsed != null && parsed > 0 ? parsed : null;

  }

  /// Extracts only an explicitly identified parent cart ID.

  ///

  /// Never uses the cart line's `id` or the product's `item_id`

  /// as the parent cart ID.

  int? _extractParentCartId(Map<String, dynamic> data) {
    final cart = _toMap(data['cart']);
    final parentCart = _toMap(data['parent_cart']);
    final cartData = _toMap(data['cart_data']);

    final candidates = <dynamic>[
      data['cart_id'],
      data['cartId'],
      data['parent_cart_id'],
      data['parentCartId'],
      data['shopping_cart_id'],
      data['shoppingCartId'],
      cart['id'],
      cart['cart_id'],
      cart['cartId'],
      cart['parent_cart_id'],
      cart['parentCartId'],
      parentCart['id'],
      parentCart['cart_id'],
      parentCart['cartId'],
      cartData['id'],
      cartData['cart_id'],
      cartData['cartId'],
    ];

    for (final candidate in candidates) {
      final id = _normalizeId(candidate);
      if (id != null) return id;
    }

    return null;
  }

  String _errorMessage(dynamic data, String fallback) {

    if (data is Map) {

      final errors = data['errors'];

      if (errors is Map && errors.isNotEmpty) {

        final messages = <String>[];

        errors.forEach((field, value) {

          if (value is List) {

            messages.add('$field: ${value.join(', ')}');

          } else {

            messages.add('$field: $value');

          }

        });

        if (messages.isNotEmpty) {

          return messages.join('\n');

        }

      }

      final message = data['message'];

      if (message != null && message.toString().trim().isNotEmpty) {

        return message.toString();

      }

    }

    return fallback;

  }

  /// Supports common API formats:

  /// { success: true, data: [...] }

  /// { success: true, data: { items: [...] } }

  /// { success: true, data: { cart_items: [...] } }

  List<dynamic> _extractRawItems(dynamic responseData) {
    if (responseData is! Map) return [];

    final root = _toMap(responseData);
    final dataValue = root['data'];
    if (dataValue is List) return dataValue;

    final data = _toMap(dataValue);
    const itemKeys = ['items', 'cart_items', 'cartItems', 'products'];

    for (final key in itemKeys) {
      final value = data[key] ?? root[key];
      if (value is List) return value;
    }

    for (final wrapperKey in ['result', 'payload']) {
      final wrapper = _toMap(root[wrapperKey]);
      final nestedDataValue = wrapper['data'];
      if (nestedDataValue is List) return nestedDataValue;

      final nestedData = _toMap(nestedDataValue);
      for (final key in itemKeys) {
        final value = wrapper[key] ?? nestedData[key];
        if (value is List) return value;
      }
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchCartItemsFromAPI(

    String userId,

  ) async {

    final token = await ApiService.getToken();

    final uri = Uri.parse(

      ApiEndpoints.getCart.replaceAll(

        '{id}',

        Uri.encodeComponent(userId),

      ),

    );

    final response = await _client

        .get(

          uri,

          headers: {

            'Accept': 'application/json',

            'Content-Type': 'application/json',

            if (token != null && token.isNotEmpty)

              'Authorization': 'Bearer $token',

          },

        )

        .timeout(

          const Duration(seconds: 10),

          onTimeout: () {

            throw TimeoutException(

              'Request timed out after 10 seconds',

            );

          },

        );

    final responseData = _decodeResponse(response.body);

    // Temporary diagnostics. Remove after confirming the API response.

    debugPrint('========== CART API DEBUG ==========');

    debugPrint('STATUS CODE: ${response.statusCode}');

    debugPrint(

      'RESPONSE BODY: '

      '${const JsonEncoder.withIndent('  ').convert(responseData)}',

    );

    debugPrint('====================================');

    if (response.statusCode < 200 ||

        response.statusCode >= 300) {

      throw Exception(

        _errorMessage(responseData, 'Failed to load cart items'),

      );

    }

    if (responseData is! Map ||

        responseData['success'] != true) {

      throw Exception(

        _errorMessage(responseData, 'Failed to load cart items'),

      );

    }

    final rawItems = _extractRawItems(responseData);
    final cartItems = <Map<String, dynamic>>[];

    // Some APIs include parent cart metadata once in the response envelope
    // rather than repeating cart_id on each cart line. Only explicit cart
    // fields are accepted; line IDs and product IDs are never used as cart IDs.
    final responseMap = _toMap(responseData);
    final responseDataMap = _toMap(responseMap['data']);
    // Some cart endpoints return the parent cart as `data: { id, items: [...] }`
    // instead of naming the field `cart_id`. Treat `data.id` as the parent ID
    // only when this object also contains the cart's item collection, so a
    // cart-line ID is never mistaken for the parent cart ID.
    final dataHasCartItems = const [
      'items',
      'cart_items',
      'cartItems',
      'products',
    ].any((key) => responseDataMap[key] is List);
    final dataObjectCartId = dataHasCartItems
        ? _normalizeId(responseDataMap['id'])
        : null;

    final envelopeCartId =
        _extractParentCartId(responseMap) ??
        _extractParentCartId(responseDataMap) ??
        dataObjectCartId ??
        _extractParentCartId(_toMap(responseDataMap['data'])) ??
        _extractParentCartId(_toMap(responseMap['result'])) ??
        _extractParentCartId(_toMap(responseMap['payload']));

    debugPrint('CART ENVELOPE ID: $envelopeCartId');
    debugPrint('CART ITEMS FOUND: ${rawItems.length}');

    for (final rawData in rawItems) {

      final data = _toMap(rawData);

      // Some APIs wrap the actual cart line in `cart_item`.

      final line = data['cart_item'] is Map

          ? _toMap(data['cart_item'])

          : data;

      final item = _toMap(

        line['item'] ?? data['item'],

      );

      final parentCartId = _extractParentCartId(data) ??
          _extractParentCartId(line) ??
          _extractParentCartId(item) ??
          envelopeCartId;

      final cartLineId = line['id'] ?? data['id'];

      final merged = <String, dynamic>{

        ...data,

        ...line,

        // Keep the cart line ID separate from the parent cart ID.
        if (cartLineId != null) 'id': cartLineId,
        if (parentCartId != null) 'cart_id': parentCartId,
        if (parentCartId != null) 'cartId': parentCartId,
        if (parentCartId != null) 'parent_cart_id': parentCartId,
        'item_id': line['item_id'] ?? data['item_id'] ?? item['id'],

        // Shop/product information used by CartScreen.
        'shop_id': item['shop_id'] ?? data['shop_id'],
        'shop_name': item['shop_name'] ?? data['shop_name'],
        'item_name': item['item_name'] ?? data['item_name'],
        'category': item['category'] ?? data['category'],
        ...gamefowlFieldsFromItem(data),
        ...gamefowlFieldsFromItem(item),
        'item_price': item['item_price'] ?? data['item_price'],
        'item_quantity':
            item['item_quantity'] ?? data['item_quantity'],

      };

      cartItems.add(merged);

    }

    return cartItems;

  }

  Future<List<Map<String, dynamic>>> fetchCartItemsFromAPI(

    String userId,

  ) {

    return _fetchCartItemsFromAPI(userId);

  }

  Future<Map<String, dynamic>> addToCart({

    required String userId,

    required String itemId,

    required double price,

    required int quantity,

  }) async {

    try {

      final token = await ApiService.getToken();

      if (token == null || token.isEmpty) {

        return {

          'success': false,

          'message': 'Authentication required. Please login.',

          'data': null,

        };

      }

      final body = {

        'user_id': _normalizeId(userId),

        'item_id': _normalizeId(itemId),

        'price': price,

        'quantity': quantity,

      };

      final response = await _client

          .post(

            Uri.parse(ApiEndpoints.addToCart),

            headers: {

              'Content-Type': 'application/json',

              'Accept': 'application/json',

              'Authorization': 'Bearer $token',

            },

            body: jsonEncode(body),

          )

          .timeout(const Duration(seconds: 10));

      final responseData = _decodeResponse(response.body);

      if (response.statusCode >= 200 &&

          response.statusCode < 300 &&

          !(responseData is Map &&

              responseData['success'] == false)) {

        return {

          'success': true,

          'message': responseData is Map

              ? responseData['message'] ?? 'Item added to cart'

              : 'Item added to cart',

          'data': responseData is Map

              ? responseData['data'] ?? responseData

              : responseData,

        };

      }

      return {

        'success': false,

        'message': _errorMessage(

          responseData,

          'Failed to add item to cart',

        ),

        'data': responseData,

      };

    } on TimeoutException {

      return {

        'success': false,

        'message': 'Request timed out',

        'data': null,

      };

    } catch (e) {

      return {

        'success': false,

        'message': 'Network error: $e',

        'data': null,

      };

    }

  }

  Future<Map<String, dynamic>> updateCart({

    required dynamic cartItemId,

    required int quantity,

  }) async {

    try {

      final token = await ApiService.getToken();

      if (token == null || token.isEmpty) {

        return {

          'success': false,

          'message': 'Authentication required. Please login.',

          'data': null,

        };

      }

      if (_normalizeId(cartItemId) == null) {

        return {

          'success': false,

          'message': 'Cart item ID is missing or invalid.',

          'data': null,

        };

      }

      final uri = Uri.parse(

        ApiEndpoints.updateCart.replaceAll(

          '{id}',

          Uri.encodeComponent(cartItemId.toString()),

        ),

      );

      final response = await _client

          .put(

            uri,

            headers: {

              'Content-Type': 'application/json',

              'Accept': 'application/json',

              'Authorization': 'Bearer $token',

            },

            body: jsonEncode({'quantity': quantity}),

          )

          .timeout(const Duration(seconds: 10));

      final responseData = _decodeResponse(response.body);

      if (response.statusCode >= 200 &&

          response.statusCode < 300) {

        return {

          'success': true,

          'message': responseData is Map

              ? responseData['message'] ?? 'Cart updated'

              : 'Cart updated',

          'data': responseData is Map

              ? responseData['data'] ?? responseData

              : responseData,

        };

      }

      return {

        'success': false,

        'message': _errorMessage(

          responseData,

          'Failed to update cart',

        ),

        'data': responseData,

      };

    } on TimeoutException {

      return {

        'success': false,

        'message': 'Request timed out',

        'data': null,

      };

    } catch (e) {

      return {

        'success': false,

        'message': 'Network error: $e',

        'data': null,

      };

    }

  }

  Future<Map<String, dynamic>> removeCartItem(

    String cartItemId,

  ) async {

    try {

      final token = await ApiService.getToken();

      if (token == null || token.isEmpty) {

        return {

          'success': false,

          'message': 'Authentication required. Please login.',

          'data': null,

        };

      }

      final uri = Uri.parse(

        ApiEndpoints.deleteCart.replaceAll(

          '{id}',

          Uri.encodeComponent(cartItemId),

        ),

      );

      final response = await _client

          .delete(

            uri,

            headers: {

              'Content-Type': 'application/json',

              'Accept': 'application/json',

              'Authorization': 'Bearer $token',

            },

          )

          .timeout(const Duration(seconds: 10));

      final responseData = _decodeResponse(response.body);

      if (response.statusCode >= 200 &&

          response.statusCode < 300) {

        return {

          'success': true,

          'message': responseData is Map

              ? responseData['message'] ?? 'Item removed from cart'

              : 'Item removed from cart',

          'data': responseData is Map

              ? responseData['data'] ?? responseData

              : responseData,

        };

      }

      return {

        'success': false,

        'message': _errorMessage(

          responseData,

          'Failed to remove item from cart',

        ),

        'data': responseData,

      };

    } on TimeoutException {

      return {

        'success': false,

        'message': 'Request timed out',

        'data': null,

      };

    } catch (e) {

      return {

        'success': false,

        'message': 'Network error: $e',

        'data': null,

      };

    }

  }

  Future<Map<String, dynamic>> clearAllCartItems(

    List<String> cartItemIds,

  ) async {

    try {

      final token = await ApiService.getToken();

      if (token == null || token.isEmpty) {

        return {

          'success': false,

          'message': 'Authentication required. Please login.',

          'data': null,

        };

      }

      if (cartItemIds.isEmpty) {

        return {

          'success': true,

          'message': 'Cart is already empty',

          'data': null,

        };

      }

      int successCount = 0;

      int failCount = 0;

      final errors = <String>[];

      for (final cartItemId in cartItemIds) {

        try {

          final uri = Uri.parse(

            ApiEndpoints.deleteCart.replaceAll(

              '{id}',

              Uri.encodeComponent(cartItemId),

            ),

          );

          final response = await _client

              .delete(

                uri,

                headers: {

                  'Content-Type': 'application/json',

                  'Accept': 'application/json',

                  'Authorization': 'Bearer $token',

                },

              )

              .timeout(const Duration(seconds: 10));

          if (response.statusCode >= 200 &&

              response.statusCode < 300) {

            successCount++;

          } else {

            failCount++;

            errors.add(

              _errorMessage(

                _decodeResponse(response.body),

                'Failed to delete cart item $cartItemId',

              ),

            );

          }

        } catch (e) {

          failCount++;

          errors.add('Failed to delete item $cartItemId: $e');

        }

      }

      if (failCount == 0) {

        return {

          'success': true,

          'message': 'All items removed from cart',

          'data': {'deleted_count': successCount},

        };

      }

      if (successCount > 0) {

        return {

          'success': true,

          'message':

              '$successCount item(s) removed, '

              '$failCount item(s) failed',

          'data': {

            'deleted_count': successCount,

            'failed_count': failCount,

            'errors': errors,

          },

        };

      }

      return {

        'success': false,

        'message': 'Failed to remove items from cart',

        'data': {

          'deleted_count': 0,

          'failed_count': failCount,

          'errors': errors,

        },

      };

    } catch (e) {

      return {

        'success': false,

        'message': 'Network error: $e',

        'data': null,

      };

    }

  }

  Future<List<Map<String, dynamic>>> fetchCartItemsForV2(

    String userId,

  ) async {

    final items = await _fetchCartItemsFromAPI(userId);

    return items;

  }

}
