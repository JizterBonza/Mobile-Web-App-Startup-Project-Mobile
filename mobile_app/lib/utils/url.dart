import 'package:flutter_dotenv/flutter_dotenv.dart';

class Url {
  static String getUrl() {
    return dotenv.env['TEST_URL']!;
    //return dotenv.env['DEV_URL']!;
  }
}
