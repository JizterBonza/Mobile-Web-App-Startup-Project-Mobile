import 'url.dart';

/// API Endpoints for the application
class ApiEndpoints {
  // Base URL - loaded from .env file via Url class
  static String get baseUrl => Url.getUrl();

  // Authentication endpoints
  static String get register => '$baseUrl/api/register';
  static String get login => '$baseUrl/api/login';
  static String get logout => '$baseUrl/api/logout';
  static String get forgotPassword => '$baseUrl/api/forgot-password';
  static String get resetPassword => '$baseUrl/api/reset-password';
}
