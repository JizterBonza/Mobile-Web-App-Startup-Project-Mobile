import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_endpoints.dart';
import '../services/api_service.dart';

/// Service for voucher validation at checkout.
class VoucherService extends ApiService {
  /// Validate a voucher code via POST /api/vouchers/validate.
  ///
  /// Body: `{ voucher_code, subtotal, shipping_fee, total_amount }`
  /// (`user_id` optional; omitted so Sanctum user is used).
  Future<Map<String, dynamic>> validateCode({
    required String code,
    required double subtotal,
    required double shippingFee,
    required double totalAmount,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
        };
      }

      final trimmed = code.trim();
      if (trimmed.isEmpty) {
        return {
          'success': false,
          'message': 'Please enter a voucher code.',
        };
      }

      final response = await http
          .post(
            Uri.parse(ApiEndpoints.validateVoucher),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'voucher_code': trimmed,
              'subtotal': subtotal,
              'shipping_fee': shippingFee,
              'total_amount': totalAmount,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Request timed out after 15 seconds');
            },
          );

      final responseData = jsonDecode(response.body);
      if (responseData is! Map) {
        return {
          'success': false,
          'message': 'Unexpected voucher response.',
        };
      }

      final map = Map<String, dynamic>.from(responseData);
      final data = map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : <String, dynamic>{};
      final voucher = data['voucher'] is Map
          ? Map<String, dynamic>.from(data['voucher'] as Map)
          : null;

      double toDouble(dynamic value) {
        if (value is num) return value.toDouble();
        return double.tryParse(value?.toString() ?? '') ?? 0.0;
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          map['success'] == true) {
        final discount = toDouble(data['voucher_discount_amount']);
        final resolvedCode = (data['voucher_code'] ??
                voucher?['code'] ??
                trimmed)
            .toString()
            .trim();
        final name = voucher?['name']?.toString();

        return {
          'success': true,
          'message': map['message']?.toString() ?? 'Voucher is valid',
          'voucher_id': data['voucher_id'],
          'voucher_code':
              resolvedCode.isNotEmpty ? resolvedCode : trimmed,
          'voucher_discount_amount': discount,
          'shipping_fee': toDouble(data['shipping_fee']),
          'total_amount': toDouble(data['total_amount']),
          'name': name,
          'voucher': voucher,
          'data': data,
        };
      }

      String errorMessage = 'Invalid voucher code.';
      if (map['message'] != null) {
        errorMessage = map['message'].toString();
      } else if (map['errors'] is Map) {
        final errors = map['errors'] as Map;
        if (errors.isNotEmpty) {
          errorMessage = errors.values.first.toString();
        }
      }

      return {
        'success': false,
        'message': errorMessage,
        'data': map,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
