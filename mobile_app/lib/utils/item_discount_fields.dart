/// Discount-related keys from an API item payload for product cards.
Map<String, dynamic> discountFieldsFromItem(Map<String, dynamic> item) => {
      'discount_percent': item['discount_percent'],
      'discount_type': item['discount_type'],
      'discount_expires_at': item['discount_expires_at'],
      'effective_price': item['effective_price'],
      'active_discount_percent': item['active_discount_percent'],
    };
