/// Identifies Gamefowl products across item, shop, search, and cart responses.
/// Category IDs are resolved against the categories returned by the API.
Map<String, dynamic> gamefowlFieldsFromItem(Map item) => {
      for (final key in const [
        'category_id',
        'category_name',
        'categoryName',
        'item_category',
        'product_category',
        'is_gamefowl',
        'gamefowl_type',
        'gamefowl_age',
        'gamefowl_gender',
        'gamefowl_sex',
        'fowl_type',
        'fowl_age',
        'fowl_sex',
        'breed_type',
      ])
        if (item.containsKey(key)) key: item[key],
    };

bool isGamefowlItem(
  Map<String, dynamic> item, {
  Iterable<Map<String, dynamic>> categories = const [],
}) {
  if (item['is_gamefowl'] == true ||
      item['is_direct_gamefowl_order'] == true ||
      item['gamefowl_request'] != null) {
    return true;
  }

  const gamefowlFields = [
    'gamefowl_type',
    'gamefowl_age',
    'gamefowl_gender',
    'gamefowl_sex',
    'fowl_type',
    'fowl_age',
    'fowl_sex',
    'breed_type',
  ];
  if (gamefowlFields.any((key) => _hasValue(item[key]))) return true;

  final categoryValues = [
    item['category'],
    item['category_id'],
    item['category_name'],
    item['categoryName'],
    item['item_category'],
    item['product_category'],
  ];
  for (final value in categoryValues) {
    if (_isGamefowlCategory(value, categories)) return true;
  }

  // Older API responses sometimes omit category metadata entirely.
  if (categoryValues.any(_hasValue)) return false;
  final name = item['item_name'] ?? item['product_name'] ?? item['name'];
  return _hasGamefowlLabel(name);
}

bool itemMatchesCategory(
  Map<String, dynamic> item,
  Map<String, dynamic> category,
) {
  final id = category['id']?.toString().trim();
  final name = category['name']?.toString().trim().toLowerCase();
  if ((id == null || id.isEmpty) && (name == null || name.isEmpty)) {
    return false;
  }

  for (final value in [
    item['category'],
    item['category_id'],
    item['category_name'],
    item['categoryName'],
    item['item_category'],
    item['product_category'],
  ]) {
    final raw = value is Map
        ? (value['id'] ?? value['name'] ?? value['category_name'])
        : value;
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) continue;
    if (text == id || text.toLowerCase() == name) return true;
  }
  return false;
}

bool _isGamefowlCategory(
  dynamic value,
  Iterable<Map<String, dynamic>> categories,
) {
  if (value == null) return false;
  if (value is Map) {
    if (_isGamefowlCategoryName(value['name'] ?? value['category_name'])) {
      return true;
    }
    value = value['id'];
  }
  if (_isGamefowlCategoryName(value)) return true;
  final id = value?.toString().trim();
  if (id == null || id.isEmpty) return false;
  return categories.any((category) =>
      category['id']?.toString() == id &&
      _isGamefowlCategoryName(category['name']));
}

bool _isGamefowlCategoryName(dynamic value) {
  final text = value?.toString().toLowerCase().trim() ?? '';
  return text == 'gamefowl' || text == 'game fowl';
}

bool _hasGamefowlLabel(dynamic value) {
  final text = value?.toString().toLowerCase().trim() ?? '';
  return text.contains('gamefowl') || text.contains('game fowl');
}

bool _hasValue(dynamic value) =>
    value != null && value.toString().trim().isNotEmpty;
