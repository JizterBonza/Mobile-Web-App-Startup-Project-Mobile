import 'package:flutter_dotenv/flutter_dotenv.dart';

class Url {
  static String getUrl() {
    // return dotenv.env['TEST_URL']!;
    //return dotenv.env['DEV_URL']!;
    // return dotenv.env['MOBILE_LOCAL_URL']!;
    // return dotenv.env['WEB_LOCAL_URL']!;
    return dotenv.env['STAGING_URL']!;
  }
}
