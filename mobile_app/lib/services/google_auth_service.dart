import 'package:google_sign_in/google_sign_in.dart';

import '../constants/constants.dart';
import 'api_service.dart';

/// Native Google Sign-In, then exchanges id_token with the Agrify API.
class GoogleAuthService {
  GoogleAuthService._();

  static GoogleSignIn? _googleSignIn;

  static GoogleSignIn get instance {
    _googleSignIn ??= GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: AppConfig.googleWebClientId,
      clientId: AppConfig.googleIosClientId,
    );
    return _googleSignIn!;
  }

  /// Returns ApiService-shaped result: success, message, data, optional cancelled.
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final account = await instance.signIn();
      if (account == null) {
        return {
          'success': false,
          'cancelled': true,
          'message': 'Sign-in cancelled',
          'data': null,
        };
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        return {
          'success': false,
          'message':
              'No ID token from Google. Set GOOGLE_WEB_CLIENT_ID to your Web OAuth client (same as Laravel GOOGLE_CLIENT_ID).',
          'data': null,
        };
      }

      return ApiService.signInWithGoogleIdToken(idToken);
    } catch (e) {
      return {
        'success': false,
        'message': 'Google sign-in failed: ${e.toString()}',
        'data': null,
      };
    }
  }

  static Future<void> signOutFromGoogle() async {
    try {
      await instance.signOut();
    } catch (e) {
      print('Google sign-out error: $e');
    }
  }
}
