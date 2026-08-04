import 'package:agriconnect/services/api_service.dart';
import 'package:agriconnect/widgets/login_form_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('remember me preferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('stores username or email identifier and type', () async {
      await ApiService.applyRememberMePreference(
        rememberMe: true,
        loginIdentifier: 'farmer@gmail.com',
      );

      expect(await ApiService.isRememberMeEnabled(), isTrue);
      expect(await ApiService.getSavedLogin(), 'farmer@gmail.com');
      expect(
        await ApiService.getSavedLoginType(),
        ApiService.savedLoginTypeUsernameOrEmail,
      );
    });

    test('stores phone identifier and type', () async {
      await ApiService.applyRememberMePreference(
        rememberMe: true,
        loginIdentifier: '09171234567',
      );

      expect(await ApiService.getSavedLogin(), '09171234567');
      expect(
        await ApiService.getSavedLoginType(),
        ApiService.savedLoginTypePhone,
      );
    });

    test('infers type for a legacy saved identifier', () async {
      SharedPreferences.setMockInitialValues({
        'remember_me': true,
        'saved_login': '09171234567',
      });

      expect(
        await ApiService.getSavedLoginType(),
        ApiService.savedLoginTypePhone,
      );
    });

    test('unchecking clears remembered login and session metadata', () async {
      SharedPreferences.setMockInitialValues({
        'remember_me': true,
        'saved_login': 'old-user',
        'saved_login_type': ApiService.savedLoginTypeUsernameOrEmail,
        'refresh_token': 'refresh-token',
        'token_expires_at': '2099-01-01T00:00:00Z',
      });

      await ApiService.applyRememberMePreference(rememberMe: false);
      final prefs = await SharedPreferences.getInstance();

      expect(await ApiService.isRememberMeEnabled(), isFalse);
      expect(await ApiService.getSavedLogin(), isNull);
      expect(await ApiService.getSavedLoginType(), isNull);
      expect(prefs.getString('refresh_token'), isNull);
      expect(prefs.getString('token_expires_at'), isNull);
    });

    test('logout cleanup preserves remembered identifier and type', () async {
      SharedPreferences.setMockInitialValues({
        'remember_me': true,
        'saved_login': '09171234567',
        'saved_login_type': ApiService.savedLoginTypePhone,
        'auth_token': 'access-token',
        'refresh_token': 'refresh-token',
        'user_id': '1',
      });

      await ApiService.clearToken();
      final prefs = await SharedPreferences.getInstance();

      expect(await ApiService.isRememberMeEnabled(), isTrue);
      expect(await ApiService.getSavedLogin(), '09171234567');
      expect(
        await ApiService.getSavedLoginType(),
        ApiService.savedLoginTypePhone,
      );
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
      expect(prefs.getString('user_id'), isNull);
    });
  });

  group('remember me login form', () {
    Future<void> pumpLoginForm(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LoginFormContent(
                onLogin: (_, __, ___) async {},
                onForgotPassword: () {},
                onSignUp: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('prefills remembered email without a password', (tester) async {
      SharedPreferences.setMockInitialValues({
        'remember_me': true,
        'saved_login': 'farmer@gmail.com',
        'saved_login_type': ApiService.savedLoginTypeUsernameOrEmail,
      });

      await pumpLoginForm(tester);

      expect(find.text('USERNAME OR EMAIL'), findsOneWidget);
      expect(find.text('farmer@gmail.com'), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
      final fields =
          tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields[1].controller?.text, isEmpty);
    });

    testWidgets('remembered phone opens and prefills phone mode',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'remember_me': true,
        'saved_login': '09171234567',
        'saved_login_type': ApiService.savedLoginTypePhone,
      });

      await pumpLoginForm(tester);

      expect(find.text('PHONE NUMBER'), findsOneWidget);
      expect(find.text('09171234567'), findsOneWidget);
      expect(find.text('Remember me'), findsOneWidget);
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
      final fields =
          tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields[1].controller?.text, isEmpty);
    });

    testWidgets('checkbox stays synchronized when switching login modes',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpLoginForm(tester);

      await tester.tap(find.text('Remember me'));
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

      await tester.tap(find.text('Login with mobile phone'));
      await tester.pumpAndSettle();
      expect(find.text('PHONE NUMBER'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

      await tester.tap(find.text('Back to username or email login'));
      await tester.pumpAndSettle();
      expect(find.text('USERNAME OR EMAIL'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });
  });
}
