/// Formats a display amount with grouping and two decimal places only when needed.
/// Decimal strings are rounded as cents without converting server amounts to doubles.
String formatPriceNumber(dynamic value, {String fallback = '0'}) {
  if (value == null || (value is num && !value.isFinite)) return fallback;
  final raw = value.toString().trim().replaceAll(RegExp(r'[,₱\s]'), '');
  final match =
      RegExp(r'^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$').firstMatch(raw);
  if (match == null) return fallback;
  final whole = match.group(2)!;
  final fraction = match.group(3) ?? '';
  if (whole.isEmpty && fraction.isEmpty) return fallback;
  final exponent = int.tryParse(match.group(4) ?? '0');
  if (exponent == null || exponent.abs() > 1000) return fallback;
  final digits = BigInt.parse('$whole$fraction');
  final scale = fraction.length - exponent;
  BigInt cents;
  if (scale <= 2) {
    cents = digits * BigInt.from(10).pow(2 - scale);
  } else {
    final divisor = BigInt.from(10).pow(scale - 2);
    cents = digits ~/ divisor;
    if ((digits % divisor) * BigInt.two >= divisor) cents += BigInt.one;
  }
  final integer = (cents ~/ BigInt.from(100)).toString();
  final grouped =
      integer.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final remainder = (cents % BigInt.from(100)).toInt();
  final decimal =
      remainder == 0 ? '' : '.${remainder.toString().padLeft(2, '0')}';
  final sign = match.group(1) == '-' && cents != BigInt.zero ? '-' : '';
  return '$sign$grouped$decimal';
}

String formatPeso(dynamic value, {String fallback = '₱0'}) {
  final amount = formatPriceNumber(value, fallback: '');
  if (amount.isEmpty) return fallback;
  return amount.startsWith('-') ? '-₱${amount.substring(1)}' : '₱$amount';
}
