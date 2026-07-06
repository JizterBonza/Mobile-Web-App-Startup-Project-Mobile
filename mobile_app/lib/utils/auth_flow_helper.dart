import '../services/api_service.dart';



/// Shared post-authentication helpers for email and Google login.

class AuthFlowHelper {

  AuthFlowHelper._();



  static const validUserTypes = ['customer', 'rider'];



  static String dashboardRouteFor(String userType) {

    switch (userType.toLowerCase()) {

      case 'vendor':

        return '/vendorDashboard';

      case 'rider':

        return '/riderDashboard';

      case 'customer':

      default:

        return '/customerDashboard';

    }

  }



  static Future<String?> resolveUserType(Map data) async {

    var userType = (data['user'] is Map

            ? data['user']['user_type']?.toString()

            : null) ??

        data['user_type']?.toString() ??

        (data['data'] is Map ? data['data']['user_type']?.toString() : null) ??

        (data['data'] is Map && data['data']['user'] is Map

            ? data['data']['user']['user_type']?.toString()

            : null);



    if (userType == null || userType.isEmpty) {

      userType = await ApiService.getUserType();

    }

    if (userType != null && userType.isNotEmpty) {

      return userType.toLowerCase();

    }

    return null;

  }



  static bool? _parseBool(dynamic value) {

    if (value == true || value == 1 || value == '1' || value == 'true') {

      return true;

    }

    if (value == false || value == 0 || value == '0' || value == 'false') {

      return false;

    }

    return null;

  }



  static bool? _readFlag(Map data, String key) {

    final top = _parseBool(data[key]);

    if (top != null) return top;



    if (data['user'] is Map) {

      final fromUser = _parseBool((data['user'] as Map)[key]);

      if (fromUser != null) return fromUser;

    }



    if (data['data'] is Map) {

      final nested = data['data'] as Map;

      final fromData = _parseBool(nested[key]);

      if (fromData != null) return fromData;



      if (nested['user'] is Map) {

        final fromNestedUser = _parseBool((nested['user'] as Map)[key]);

        if (fromNestedUser != null) return fromNestedUser;

      }

    }



    return null;

  }



  static bool needsProfileCompletion(Map data) {

    final isNewUser = _readFlag(data, 'is_new_user') ?? false;

    final profileComplete = _readFlag(data, 'profile_complete');



    if (isNewUser) {

      return profileComplete != true;

    }

    if (profileComplete == false) {

      return true;

    }

    return false;

  }

}

