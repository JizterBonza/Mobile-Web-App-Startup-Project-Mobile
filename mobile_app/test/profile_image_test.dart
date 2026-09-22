import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agriconnect/services/api_service.dart';
import 'package:agriconnect/widgets/user_profile_avatar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('profile image validation', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory =
          await Directory.systemTemp.createTemp('profile-image-test-');
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('accepts each supported image extension', () async {
      for (final extension in ['jpg', 'jpeg', 'png', 'webp']) {
        final file = File('${temporaryDirectory.path}/avatar.$extension');
        await file.writeAsBytes([1, 2, 3]);
        final image = XFile(file.path);

        expect(await ApiService.validateProfileImage(image), isNull);
      }
    });

    test('accepts exactly 5 MB and rejects larger images', () async {
      final maximumSize = Uint8List(5 * 1024 * 1024);
      final allowedFile = File('${temporaryDirectory.path}/allowed.jpg');
      final oversizedFile = File('${temporaryDirectory.path}/oversized.jpg');
      await allowedFile.writeAsBytes(maximumSize);
      await oversizedFile.writeAsBytes(Uint8List(maximumSize.length + 1));
      final allowed = XFile(allowedFile.path);
      final oversized = XFile(oversizedFile.path);

      expect(await ApiService.validateProfileImage(allowed), isNull);
      expect(
        await ApiService.validateProfileImage(oversized),
        'Profile image must be 5 MB or smaller.',
      );
    });

    test('rejects empty, unsupported, and unreadable images', () async {
      final emptyFile = File('${temporaryDirectory.path}/empty.png');
      final unsupportedFile = File('${temporaryDirectory.path}/avatar.gif');
      await emptyFile.writeAsBytes([]);
      await unsupportedFile.writeAsBytes([1]);
      final empty = XFile(emptyFile.path);
      final unsupported = XFile(unsupportedFile.path);
      final missing = XFile('${temporaryDirectory.path}/missing.jpg');

      expect(
        await ApiService.validateProfileImage(empty),
        'The selected image is empty.',
      );
      expect(
        await ApiService.validateProfileImage(unsupported),
        'Please select a JPEG, PNG, JPG, or WebP image.',
      );
      expect(
        await ApiService.validateProfileImage(missing),
        'The selected image could not be read.',
      );
    });
  });

  testWidgets('local image preview takes precedence over network URL',
      (tester) async {
    final imageBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserProfileAvatar(
            size: 80,
            imageUrl: 'https://example.test/old-avatar.jpg',
            imageBytes: imageBytes,
            backgroundColor: Colors.green,
            iconColor: Colors.white,
            iconSize: 40,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<MemoryImage>());
  });

  group('profile update transport', () {
    late Directory temporaryDirectory;

    setUp(() async {
      dotenv.testLoad(fileInput: 'TEST_URL=https://example.test');
      SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
      temporaryDirectory =
          await Directory.systemTemp.createTemp('profile-upload-test-');
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('uses JSON PUT when no profile image is selected', () async {
      late http.BaseRequest capturedRequest;
      final result = await ApiService.updateProfile(
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        username: 'juan_dc',
        email: 'juan@example.test',
        requestSender: (request) async {
          capturedRequest = request;
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'message': 'Updated'}))),
            HttpStatus.ok,
          );
        },
      );

      final request = capturedRequest as http.Request;
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/profile/update');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['Content-Type'], 'application/json');
      expect(
        jsonDecode(request.body),
        {
          'first_name': 'Juan',
          'last_name': 'Dela Cruz',
          'username': 'juan_dc',
          'email': 'juan@example.test',
        },
      );
      expect(result['success'], isTrue);
    });

    test('uses multipart POST and caches the returned profile URL', () async {
      final imageFile = File('${temporaryDirectory.path}/avatar.jpg');
      await imageFile.writeAsBytes([1, 2, 3, 4]);
      const imageUrl = 'https://example.test/storage/profile-images/avatar.jpg';

      late http.BaseRequest capturedRequest;
      final result = await ApiService.updateProfile(
        firstName: 'Juan',
        middleName: 'Santos',
        lastName: 'Dela Cruz',
        username: 'juan_dc',
        email: 'juan@example.test',
        mobileNumber: '09171234567',
        shippingAddress: 'Davao City',
        profileImage: XFile(imageFile.path),
        requestSender: (request) async {
          capturedRequest = request;
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'message': 'Updated',
                  'user': {
                    'user_detail': {'profile_image_url': imageUrl},
                  },
                }),
              ),
            ),
            HttpStatus.ok,
          );
        },
      );

      final request = capturedRequest as http.MultipartRequest;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/profile/update');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['Accept'], 'application/json');
      expect(request.fields['first_name'], 'Juan');
      expect(request.fields['middle_name'], 'Santos');
      expect(request.fields['shipping_address'], 'Davao City');
      expect(request.files, hasLength(1));
      expect(request.files.single.field, 'profile_image');
      expect(request.files.single.filename, 'avatar.jpg');
      expect(request.files.single.contentType.toString(), 'image/jpeg');
      expect(result['success'], isTrue);
      expect(result['profile_image_url'], imageUrl);
      expect(await ApiService.getProfileImageUrl(), imageUrl);
    });
  });
}
