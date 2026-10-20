import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_endpoints.dart';
import '../utils/gamefowl_item.dart';
import '../services/api_service.dart';

class CartService extends ApiService {
  CartService({http.Client? httpClient})
      : _httpClient = httpClient;

  final http.Client? _httpClient;

  http.Client get _client => _httpClient ?? http.Client();

  // Safely decode API response.
  dynamic _decodeResponse(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return <String, dynamic>{'message': body};
    }
  }

  // Convert a value to a Map safely.
  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  // Normalize numeric IDs without changing non-numeric IDs.
  dynamic _normalizeId(dynamic id) {
    if (id == null) return null;
    return id is int ? id : int.tryParse(id.toString()) ?? id;
  }

  // Extract a readable API error message.
  String _errorMessage(
    dynamic responseData,
    String fallback,
  ) {
    if (responseData is Map) {
      final errors = responseData['errors'];

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

      final message = responseData['message'];
      if (message != null && message.toString().isNotEmpty) {
        return message.toString();
      }
    }

    return fallback;
  }

  // Fetch cart items from API using the user ID.
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

    final rawItems = responseData['data'];

    if (rawItems == null) {
      return [];
    }

    if (rawItems is! List) {
      throw Exception('Invalid cart response: data is not a list.');
    }

    final List<Map<String, dynamic>> cartItems = [];

    for (final rawData in rawItems) {
      final data = _toMap(rawData);
      final item = _toMap(data['item']);
      final cart = _toMap(data['cart']);

      // Keep cart ID separate from cart-item ID.
      // Do not assume data['id'] is the cart ID.
      final dynamic cartId =
          data['cart_id'] ?? cart['id'];

      cartItems.add({
        // Preserve every field returned by the API.
        ...data,

        // IDs are kept separate.
        'id': data['id'],
        'cart_item_id': data['id'],
        'cart_id': cartId,
        'user_id': data['user_id'],
        'item_id': data['item_id'],

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

        // Cart line information.
        'quantity': data['quantity'],
        'price_snapshot': data['price_snapshot'],
        'discounted_price': data['discounted_price'],
        'discount_status': data['discount_status'],
        'discount_details': data['discount_details'],
        'status': data['status'],
        'added_at': data['created_at'],
      });
    }

    return cartItems;
  }

  Future<List<Map<String, dynamic>>> fetchCartItemsFromAPI(
    String userId,
  ) async {
    return _fetchCartItemsFromAPI(userId);
  }

  // Add item to cart via API.
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
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Request timed out after 10 seconds',
              );
            },
          );

      final responseData = _decodeResponse(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        if (responseData is Map &&
            responseData['success'] == false) {
          return {
            'success': false,
            'message': _errorMessage(
              responseData,
              'The server did not add this item to the cart.',
            ),
            'data': responseData,
          };
        }

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
    } on TimeoutException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Request timed out',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null,
      };
    }
  }

  // Set an existing cart line to an absolute quantity.
  // cartItemId is the ID of the cart line, not necessarily cart_id.
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

      if (cartItemId == null ||
          cartItemId.toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'Cart item ID is missing.',
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
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Request timed out after 10 seconds',
              );
            },
          );

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
    } on TimeoutException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Request timed out',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null,
      };
    }
  }

  // Remove one cart item.
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
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Request timed out after 10 seconds',
              );
            },
          );

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
    } on TimeoutException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Request timed out',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'data': null,
      };
    }
  }

  // Remove all cart items (batch delete).
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
      final List<String> errors = [];

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
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw TimeoutException(
                    'Request timed out after 10 seconds',
                  );
                },
              );

          if (response.statusCode >= 200 &&
              response.statusCode < 300) {
            successCount++;
          } else {
            failCount++;
            final responseData = _decodeResponse(response.body);
            errors.add(
              _errorMessage(
                responseData,
                'Failed to delete cart item $cartItemId',
              ),
            );
          }
        } catch (e) {
          failCount++;
          errors.add(
            'Failed to delete item $cartItemId: ${e.toString()}',
          );
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
        'message': 'Network error: ${e.toString()}',
        'data': null,
      };
    }
  }

  // CartScreen V2: preserve full nested structure.
  Future<List<Map<String, dynamic>>> fetchCartItemsForV2(
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
            'Content-Type': 'application/json',
            'Accept': 'application/json',
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

    final rawItems = responseData['data'];

    if (rawItems == null) return [];

    if (rawItems is! List) {
      throw Exception('Invalid cart response: data is not a list.');
    }

    return rawItems.map<Map<String, dynamic>>((rawItem) {
      final data = _toMap(rawItem);

      // Preserve nested data and expose a separate cart_id
      // only if the API actually provides it.
      final cart = _toMap(data['cart']);

      return {
        ...data,
        'cart_id': data['cart_id'] ?? cart['id'],
      };
    }).toList();
  }
}

