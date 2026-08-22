import 'url.dart';

/// Resolves a raw media path or URL to an absolute URL suitable for [Image.network].
String? resolveMediaUrl(String? raw) {
  if (raw == null) return null;
  final path = raw.trim();
  if (path.isEmpty || path.toLowerCase() == 'null') return null;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  final baseUrl = Url.getUrl().replaceAll(RegExp(r'/+$'), '');
  final normalized = path.startsWith('/') ? path : '/$path';
  return '$baseUrl$normalized';
}

/// Resolves shop `logo_url` / `banner_url` (absolute URL or storage-relative path).
String? resolveShopMediaUrl(dynamic raw) {
  if (raw == null) return null;
  final path = raw.toString().trim();
  if (path.isEmpty || path.toLowerCase() == 'null') return null;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  var normalized = path.startsWith('/') ? path : '/$path';
  if (!normalized.startsWith('/storage/')) {
    normalized = '/storage$normalized';
  }
  return resolveMediaUrl(normalized);
}

/// Resolves [item_images] from API responses (string, list, or map entry).
String? resolveItemImageUrl(dynamic itemImages) {
  if (itemImages == null) return null;

  if (itemImages is String) {
    return resolveMediaUrl(itemImages);
  }

  if (itemImages is List && itemImages.isNotEmpty) {
    final first = itemImages.first;
    if (first is Map) {
      final raw = first['url']?.toString() ??
          first['image_url']?.toString() ??
          first['path']?.toString();
      return resolveMediaUrl(raw);
    }
    return resolveMediaUrl(first.toString());
  }

  return null;
}
