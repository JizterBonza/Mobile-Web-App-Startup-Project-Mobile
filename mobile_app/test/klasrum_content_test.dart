import 'dart:convert';

import 'package:agriconnect/models/klasrum_content.dart';
import 'package:agriconnect/services/klasrum_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'TEST_URL=https://example.test');
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
  });

  test('fetches the single article detail by ID', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://example.test/api/klasrum/25');
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 25,
              'title': 'Airwolf Dom',
              'media': [
                {'url': 'https://example.test/first.jpg', 'type': 'image'},
                {'url': 'https://example.test/second.jpg', 'type': 'image'},
              ],
            },
          }),
          200);
    });
    addTearDown(client.close);

    final detail = await KlasrumService(httpClient: client).fetchArticle(25);
    expect(detail['id'], 25);
    expect(klasrumMediaItems(detail), hasLength(2));
  });

  test('maps every media item from the article detail in API order', () {
    final article = mapKlasrumContent({
      'id': 25,
      'title': 'Airwolf Dom',
      'media': [
        {
          'url': 'https://example.test/storage/first.jpg',
          'type': 'image',
          'is_video': false,
        },
        {
          'path': 'klasrum/media/second.jpg',
          'type': 'image',
          'is_video': false,
        },
      ],
      'media_url': 'https://example.test/storage/first.jpg',
      'media_type': 'image',
    });

    final media = klasrumMediaItems(article);
    expect(media.map((item) => item.url), [
      'https://example.test/storage/first.jpg',
      'https://example.test/storage/klasrum/media/second.jpg',
    ]);
    expect(media.every((item) => item.isImage), isTrue);
  });

  test('retains mixed image and video order', () {
    final media = klasrumMediaItems({
      'media': [
        {'url': 'https://example.test/one.jpg', 'type': 'image'},
        {'url': 'https://example.test/two.mp4', 'is_video': true},
        {'url': 'https://example.test/three.jpg', 'type': 'image'},
      ],
    });
    expect(media.map((item) => item.isVideo), [false, true, false]);
  });

  test('uses legacy media only when the array has no usable items', () {
    expect(klasrumMediaItems({'media': []}), isEmpty);
    final media = klasrumMediaItems({
      'media': [
        {'url': null}
      ],
      'media_url': 'https://example.test/old.mp4',
      'media_type': 'video',
    });
    expect(media, hasLength(1));
    expect(media.single.url, 'https://example.test/old.mp4');
    expect(media.single.isVideo, isTrue);
  });
}
