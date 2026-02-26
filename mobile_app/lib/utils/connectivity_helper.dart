import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_endpoints.dart';

/// Utility class for checking internet connectivity
class ConnectivityHelper {
  /// Check if internet connection is available
  ///
  /// Returns true if a connection can be established, false otherwise
  static Future<bool> hasInternetConnection() async {
    try {
      // First, try DNS lookup to a reliable server (fastest check)
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 2));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        // DNS lookup failed, try HTTP request
      }

      // If DNS lookup fails, try a lightweight HTTP request to the API base URL
      final response = await http
          .head(
        Uri.parse(ApiEndpoints.baseUrl),
      )
          .timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      // If we get any response (even 404/405), internet is available
      return response.statusCode >= 200;
    } catch (e) {
      // All connection attempts failed
      print('Connectivity check failed: $e');
      return false;
    }
  }
}
