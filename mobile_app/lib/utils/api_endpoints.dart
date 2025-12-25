import 'url.dart';

/// API Endpoints
class ApiEndpoints {
  // Base URL - loaded from .env file via Url class
  static String get baseUrl => Url.getUrl();

  // Authentication endpoints
  static String get register => '$baseUrl/api/register';
  static String get login => '$baseUrl/api/login';
  static String get logout => '$baseUrl/api/logout';
  static String get forgotPassword => '$baseUrl/api/forgot-password';
  static String get resetPassword => '$baseUrl/api/reset-password';
  static String get updateProfile => '$baseUrl/api/profile/update';
  static String get changePassword => '$baseUrl/api/profile/change-password';

  // Customer endpoints
  static String get getCategories => '$baseUrl/api/categories';
  static String get getProducts => '$baseUrl/api/products';
  static String get getProductDetails => '$baseUrl/api/products/{id}';
  static String get addToCart => '$baseUrl/api/carts/add';
  static String get getCart => '$baseUrl/api/carts/user/{id}';
  static String get updateCart => '$baseUrl/api/carts/update';
  static String get deleteCart => '$baseUrl/api/carts/delete/{id}';
  static String get getItems => '$baseUrl/api/items';
  static String get getItemsRandom => '$baseUrl/api/items/random';
  static String get getItemReviews => '$baseUrl/api/items/{id}/reviews';
  static String get getSearchItem => '$baseUrl/api/items/search';
  static String get getItemsByCategory => '$baseUrl/api/items';

  // Order endpoints
  static String get createOrder => '$baseUrl/api/orders/create';
  static String get getOrders => '$baseUrl/api/orders';
  static String get getOrderById => '$baseUrl/api/orders/{id}';
  static String get getOrdersByUserId => '$baseUrl/api/orders/user/{user_id}';
  static String get updateOrderStatus => '$baseUrl/api/orders/{id}/status';
  static String get cancelOrder => '$baseUrl/api/orders/{id}';
  static String get getOrderHistory => '$baseUrl/api/orders/history';

  // Favorite endpoints
  static String get getFavorites => '$baseUrl/api/favorites';
  static String get getFavoritesByUserId => '$baseUrl/api/favorites/user/{id}';
  static String get addToFavorites => '$baseUrl/api/favorites/add';
  static String get removeFromFavorites => '$baseUrl/api/favorites/delete/{id}';

  // Address endpoints
  static String get getAddresses => '$baseUrl/api/addresses';
  static String get getAddressesByUserId => '$baseUrl/api/addresses/user/{id}';
  static String get addAddress => '$baseUrl/api/addresses';
  static String get updateAddress => '$baseUrl/api/addresses/{id}';
  static String get deleteAddress => '$baseUrl/api/addresses/{id}';
  static String get setDefaultAddress =>
      '$baseUrl/api/addresses/{id}/set-default';

  // Shop endpoints
  static String get getShops => '$baseUrl/api/shops';
  static String get getShopById => '$baseUrl/api/shops/{id}';
  static String get getShopItems => '$baseUrl/api/shops/{id}/items';
  static String get getShopReviews => '$baseUrl/api/shops/{id}/reviews';

  // Notification endpoints
  static String get getNotifications => '$baseUrl/api/notifications';
  static String get getNotificationsByCategory =>
      '$baseUrl/api/notifications/by-category';
  static String get getUnreadNotificationCount =>
      '$baseUrl/api/notifications/unread-count';
  static String get markNotificationAsRead =>
      '$baseUrl/api/notifications/{id}/read';
  static String get markAllNotificationsAsRead =>
      '$baseUrl/api/notifications/read-all';
  static String get deleteNotification => '$baseUrl/api/notifications/{id}';
  static String get clearReadNotifications =>
      '$baseUrl/api/notifications/clear-read';
}
