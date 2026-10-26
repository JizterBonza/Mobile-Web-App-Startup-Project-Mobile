import 'package:flutter_dotenv/flutter_dotenv.dart';

class Url {
  static String getUrl() {
    final stagingUrl = dotenv.env['STAGING_URL'];
    if (stagingUrl != null && stagingUrl.isNotEmpty) return stagingUrl;
    return dotenv.env['TEST_URL']!;
  }
}
