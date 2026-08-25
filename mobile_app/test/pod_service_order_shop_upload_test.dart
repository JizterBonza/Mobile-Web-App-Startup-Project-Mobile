import 'dart:convert';
import 'dart:io';

import 'package:agriconnect/services/pod_services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temporaryDirectory;
  late List<String> imagePaths;

  setUp(() async {
    dotenv.testLoad(fileInput: 'TEST_URL=https://example.test');
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    temporaryDirectory = await Directory.systemTemp.createTemp('pod-test-');
    imagePaths = <String>[];
    for (var index = 0; index < 3; index++) {
      final file = File('${temporaryDirectory.path}/proof-$index.jpg');
      await file.writeAsBytes(<int>[1, 2, 3, index]);
      imagePaths.add(file.path);
    }
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('sends exact multi-image order-shop POD request', () async {
    late http.MultipartRequest capturedRequest;
    final service = PodService(
      requestSender: (request) async {
        capturedRequest = request as http.MultipartRequest;
        return http.StreamedResponse(
          Stream<List<int>>.value(
            utf8.encode(jsonEncode({'success': true, 'message': 'Uploaded'})),
          ),
          201,
        );
      },
    );

    final result = await service.uploadOrderShopPod(
      orderId: 100,
      orderShopId: 501,
      imagePaths: imagePaths,
      latitude: 7.4479,
      longitude: 125.8071,
      remarks: 'Delivered and received by the customer',
      status: 'delivered',
    );

    expect(result['success'], isTrue);
    expect(capturedRequest.method, 'POST');
    expect(
      capturedRequest.url.toString(),
      'https://example.test/api/pod/upload',
    );
    expect(capturedRequest.headers['Authorization'], 'Bearer test-token');
    expect(capturedRequest.fields, {
      'orderId': '100',
      'orderShopId': '501',
      'latitude': '7.4479',
      'longitude': '125.8071',
      'remarks': 'Delivered and received by the customer',
      'status': 'delivered',
    });
    expect(capturedRequest.files, hasLength(3));
    expect(
      capturedRequest.files.map((file) => file.field),
      everyElement('images[]'),
    );
    expect(
      capturedRequest.files.map((file) => file.filename),
      <String>['proof-0.jpg', 'proof-1.jpg', 'proof-2.jpg'],
    );
  });

  test('rejects invalid IDs and image counts before sending', () async {
    var sendCount = 0;
    final service = PodService(
      requestSender: (_) async {
        sendCount++;
        return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
      },
    );

    final invalidId = await service.uploadOrderShopPod(
      orderId: 0,
      orderShopId: 501,
      imagePaths: imagePaths,
      latitude: 7,
      longitude: 125,
      remarks: 'Delivered',
      status: 'delivered',
    );
    final noImages = await service.uploadOrderShopPod(
      orderId: 100,
      orderShopId: 501,
      imagePaths: const <String>[],
      latitude: 7,
      longitude: 125,
      remarks: 'Delivered',
      status: 'delivered',
    );
    final tooManyImages = await service.uploadOrderShopPod(
      orderId: 100,
      orderShopId: 501,
      imagePaths: List<String>.filled(6, imagePaths.first),
      latitude: 7,
      longitude: 125,
      remarks: 'Delivered',
      status: 'delivered',
    );

    expect(invalidId['success'], isFalse);
    expect(noImages['message'], contains('between 1 and 5'));
    expect(tooManyImages['message'], contains('between 1 and 5'));
    expect(sendCount, 0);
  });

  test('rejects missing files and invalid coordinates before sending',
      () async {
    var sendCount = 0;
    final service = PodService(
      requestSender: (_) async {
        sendCount++;
        return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
      },
    );

    final badCoordinates = await service.uploadOrderShopPod(
      orderId: 100,
      orderShopId: 501,
      imagePaths: imagePaths,
      latitude: 100,
      longitude: 125,
      remarks: 'Delivered',
      status: 'delivered',
    );
    final missingFile = await service.uploadOrderShopPod(
      orderId: 100,
      orderShopId: 501,
      imagePaths: <String>['${temporaryDirectory.path}/missing.jpg'],
      latitude: 7,
      longitude: 125,
      remarks: 'Delivered',
      status: 'delivered',
    );

    expect(badCoordinates['message'], contains('Latitude'));
    expect(missingFile['message'], 'Image file not found');
    expect(sendCount, 0);
  });

  test('rejects unsupported and oversized image files before sending',
      () async {
    var sendCount = 0;
    final service = PodService(
      requestSender: (_) async {
        sendCount++;
        return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
      },
    );
    final unsupported = File('${temporaryDirectory.path}/proof.txt');
    await unsupported.writeAsBytes(<int>[1, 2, 3]);
    final oversized = File('${temporaryDirectory.path}/oversized.jpg');
    await oversized.writeAsBytes(
      List<int>.filled((5 * 1024 * 1024) + 1, 0),
    );

    final badFormat = await service.uploadOrderShopPod(
      orderId: 100,
      orderShopId: 501,
      imagePaths: <String>[unsupported.path],
      latitude: 7,
      longitude: 125,
      remarks: 'Delivered',
      status: 'delivered',
    );
    final tooLarge = await service.uploadOrderShopPod(
      orderId: 100,
      orderShopId: 501,
      imagePaths: <String>[oversized.path],
      latitude: 7,
      longitude: 125,
      remarks: 'Delivered',
      status: 'delivered',
    );

    expect(badFormat['message'], contains('Invalid image format'));
    expect(tooLarge['message'], contains('exceeds 5MB'));
    expect(sendCount, 0);
  });

  test('returns the backend error without throwing', () async {
    final service = PodService(
      requestSender: (_) async => http.StreamedResponse(
        Stream<List<int>>.value(
          utf8.encode(
            jsonEncode({'success': false, 'message': 'POD already exists'}),
          ),
        ),
        422,
      ),
    );

    final result = await service.uploadOrderShopPod(
      orderId: 100,
      orderShopId: 501,
      imagePaths: imagePaths,
      latitude: 7,
      longitude: 125,
      remarks: 'Delivered',
      status: 'delivered',
    );

    expect(result['success'], isFalse);
    expect(result['message'], 'POD already exists');
  });
}
