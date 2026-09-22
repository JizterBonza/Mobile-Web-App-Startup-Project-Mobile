/// Utilities for interpreting database timestamps as UTC and presenting them
/// in Philippine Standard Time (Asia/Manila, UTC+08:00).
///
/// Returned Manila values are display-only wall-clock values. Keep UTC values
/// from [tryParseUtc] for comparisons, persistence, and API payloads.
class ManilaTime {
  ManilaTime._();

  static const Duration utcOffset = Duration(hours: 8);

  /// Parses a database timestamp into its UTC instant.
  ///
  /// Database values without a timezone suffix are treated as UTC. Values with
  /// `Z` or an explicit offset are normalized to UTC before being returned.
  static DateTime? tryParseUtc(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    if (parsed.isUtc) {
      return parsed.toUtc();
    }

    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  static DateTime parseUtc(dynamic value) {
    final parsed = tryParseUtc(value);
    if (parsed == null) {
      throw FormatException('Invalid UTC timestamp', value);
    }
    return parsed;
  }

  /// Converts a UTC instant to Manila wall-clock components for display.
  static DateTime fromUtc(DateTime value) => value.toUtc().add(utcOffset);

  /// Parses a database UTC timestamp and converts it to Manila wall-clock time.
  static DateTime? tryParseToManila(dynamic value) {
    final utc = tryParseUtc(value);
    return utc == null ? null : fromUtc(utc);
  }

  /// Current Manila wall-clock time, independent of the device timezone.
  static DateTime now() => DateTime.now().toUtc().add(utcOffset);
}
