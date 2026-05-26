import 'package:flutter_dotenv/flutter_dotenv.dart';

class Url {
  static String getUrl() {
    return dotenv.env['WEB_LOCAL_URL']!;
  }
}
