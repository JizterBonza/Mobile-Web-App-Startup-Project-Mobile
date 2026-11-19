import 'package:agriconnect/models/farm_checkout.dart';
import 'package:agriconnect/models/gamefowl_request_draft.dart';
import 'package:agriconnect/utils/cart_item_pricing.dart';
import 'package:agriconnect/utils/price_format.dart';
import 'package:agriconnect/widgets/order/order_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups whole prices and keeps nonzero cents to two places', () {
    final cases = <dynamic, String>{
      0: '₱0',
      100: '₱100',
      '100.00': '₱100',
      1000: '₱1,000',
      '1000.00': '₱1,000',
      1000.1: '₱1,000.10',
      '1000.10': '₱1,000.10',
      '1000.01': '₱1,000.01',
      '1000.50': '₱1,000.50',
      '1,000.10': '₱1,000.10',
      '₱1,000.00': '₱1,000',
      '-1000.10': '-₱1,000.10',
      '.10': '₱0.10',
      '1e3': '₱1,000',
      '12345678901234567890.50': '₱12,345,678,901,234,567,890.50',
    };
    cases.forEach((input, expected) {
      expect(formatPeso(input), expected, reason: '$input');
    });
  });

  test('rounds cents before omitting zero decimals and grouping', () {
    expect(formatPeso('999.999'), '₱1,000');
    expect(formatPeso('1000.105'), '₱1,000.11');
    expect(formatPeso('1000.104'), '₱1,000.10');
    expect(formatPeso('-0.001'), '₱0');
  });

  test('retains explicit unavailable states', () {
    for (final input in [
      null,
      '',
      'not a price',
      double.nan,
      double.infinity
    ]) {
      expect(formatPeso(input), '₱0');
      expect(formatPeso(input, fallback: 'Price unavailable'),
          'Price unavailable');
    }
    expect(farmMoney(null), 'Not confirmed');
    expect(farmMoney('unknown'), 'Not confirmed');
  });

  test('cart, order and gamefowl displays use the same price format', () {
    expect(CartItemPricing.formatPrice(1000), '₱1,000');
    expect(OrderHelpers.formatPrice('1000.10'), '₱1,000.10');
    expect(farmMoney('10000.50'), '₱10,000.50');
    expect(farmMoney('0.00'), '₱0');
    expect(const GamefowlProductSummary(price: 1000).formattedPrice, '₱1,000');
    expect(const GamefowlProductSummary(price: 1000.1).formattedPrice,
        '₱1,000.10');
  });
}
