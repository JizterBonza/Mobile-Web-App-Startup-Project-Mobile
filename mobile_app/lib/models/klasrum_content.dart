import '../utils/media_url.dart';

class KlasrumMediaItem {
  const KlasrumMediaItem({required this.url, required this.type});

  final String url;
  final String type;

  bool get isVideo => type == 'video';
  bool get isImage => type == 'image';
}

List<KlasrumMediaItem> klasrumMediaItems(Map<String, dynamic> article) {
  final rawMedia = article['media'];
  final items = <KlasrumMediaItem>[];
  if (rawMedia is List) {
    for (final raw in rawMedia) {
      if (raw is KlasrumMediaItem) {
        items.add(raw);
        continue;
      }
      if (raw is! Map) continue;
      final entry = Map<String, dynamic>.from(raw);
      final url = resolveMediaUrl(entry['url']?.toString()) ??
          resolveShopMediaUrl(entry['path']);
      if (url == null) continue;
      final type = entry['type']?.toString().toLowerCase() ?? '';
      items.add(KlasrumMediaItem(
        url: url,
        type: type.isNotEmpty
            ? type
            : entry['is_video'] == true
                ? 'video'
                : 'image',
      ));
    }
  }
  if (items.isNotEmpty) return items;

  final legacyUrl = resolveMediaUrl(article['media_url']?.toString());
  if (legacyUrl == null) return items;
  return [
    KlasrumMediaItem(
      url: legacyUrl,
      type: article['media_type']?.toString().toLowerCase() ?? '',
    ),
  ];
}

Map<String, dynamic> mapKlasrumContent(dynamic raw) {
  final item = Map<String, dynamic>.from(raw as Map);
  final category = item['category'];
  String categoryName = '';
  dynamic categoryId = item['category_id'];
  if (category is Map) {
    categoryName = category['name']?.toString() ?? '';
    categoryId ??= category['id'];
  }

  final heading = item['heading'];
  final caption = item['caption'];
  return {
    ...item,
    'id': item['id'],
    'title': item['title']?.toString() ?? '',
    'description': item['description']?.toString() ?? '',
    'heading': heading == null || heading.toString() == 'null'
        ? ''
        : heading.toString(),
    'category_id': categoryId,
    'category_name': categoryName,
    'cover_url': resolveMediaUrl(item['cover_url']?.toString()),
    'published_at': item['published_at']?.toString(),
    'body': item['body']?.toString(),
    'caption': caption == null || caption.toString() == 'null'
        ? ''
        : caption.toString(),
    'media': klasrumMediaItems(item),
    'media_url': resolveMediaUrl(item['media_url']?.toString()),
    'media_type': item['media_type']?.toString(),
  };
}
