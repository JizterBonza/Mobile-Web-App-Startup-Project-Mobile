import 'dart:convert';

import 'package:agriconnect/services/farms_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    dotenv.testLoad(
        fileInput:
            'TEST_URL=https://example.test\nLIVE_URL=https://example.test');
    SharedPreferences.setMockInitialValues({});
  });

  test('fetches farms in API order and resolves image paths', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://example.test/api/farms');
      expect(request.headers['accept'], 'application/json');
      expect(request.headers.containsKey('authorization'), isFalse);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 7,
              'name': 'Hill Farm',
              'owner_name': 'Juan Dela Cruz',
              'address': 'Sample Road',
              'city': 'Quezon City',
              'province': 'Metro Manila',
              'cover_url': null,
              'banner_url': 'farms/hill/banner.jpg',
              'logo_url': null,
              'status': 'active',
            },
            {
              'id': 8,
              'name': 'Valley Farm',
              'cover_url': 'https://images.example.test/valley.jpg',
              'banner_url': null,
              'logo_url': null,
            },
          ],
          'count': 2,
        }),
        200,
      );
    });
    addTearDown(client.close);

    final farms = await FarmsService(httpClient: client).fetchFarms();

    expect(farms.map((farm) => farm['name']), ['Hill Farm', 'Valley Farm']);
    expect(farms.first['city'], 'Quezon City');
    expect(farms.first['banner_url'],
        'https://example.test/storage/farms/hill/banner.jpg');
    expect(farms.last['cover_url'], 'https://images.example.test/valley.jpg');
  });

  test('returns an empty list for an empty data array', () async {
    final client = MockClient((request) async =>
        http.Response('{"success":true,"data":[],"count":0}', 200));
    addTearDown(client.close);

    expect(await FarmsService(httpClient: client).fetchFarms(), isEmpty);
  });

  test('throws on HTTP errors and malformed responses', () async {
    for (final response in [
      http.Response('Server error', 500),
      http.Response('not-json', 200),
      http.Response('{"success":true,"data":{}}', 200),
      http.Response('{"success":false,"data":[]}', 200),
      http.Response('{"success":true,"data":[null]}', 200),
    ]) {
      final client = MockClient((request) async => response);
      await expectLater(
        FarmsService(httpClient: client).fetchFarms(),
        throwsException,
      );
      client.close();
    }
  });

  test('fetches a farm detail by ID and resolves its image paths', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'farm-token'});
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://example.test/api/farms/1');
      expect(request.headers['authorization'], 'Bearer farm-token');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 1,
            'name': 'Test Farm',
            'owner_name': 'Test Farmer',
            'description': null,
            'email': 'test@gmail.com',
            'cover_url': 'farms/covers/test.png',
            'banner_url': 'farms/banners/test.png',
            'logo_url': 'farms/logos/test.png',
            'status': 'active',
          },
        }),
        200,
      );
    });
    addTearDown(client.close);

    final farm = await FarmsService(httpClient: client).fetchFarmById(1);

    expect(farm['name'], 'Test Farm');
    expect(farm['description'], isNull);
    expect(farm['cover_url'],
        'https://example.test/storage/farms/covers/test.png');
    expect(farm['banner_url'],
        'https://example.test/storage/farms/banners/test.png');
    expect(
        farm['logo_url'], 'https://example.test/storage/farms/logos/test.png');
  });

  test('detail request rejects HTTP and malformed responses', () async {
    for (final response in [
      http.Response('Missing', 404),
      http.Response('not-json', 200),
      http.Response('{"success":true,"data":[]}', 200),
      http.Response('{"success":false,"data":{}}', 200),
    ]) {
      final client = MockClient((request) async => response);
      await expectLater(
        FarmsService(httpClient: client).fetchFarmById(1),
        throwsException,
      );
      client.close();
    }
  });

  test('fetches farm listings by ID and resolves farm and listing images',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
          request.url.toString(), 'https://example.test/api/farms/7/listings');
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 7,
              'name': 'Hill Farm',
              'cover_url': 'farms/covers/hill.jpg',
              'listings': [
                {
                  'id': 1,
                  'name': 'Sample Rooster',
                  'image': '/hero-rooster.jpg',
                  'images': ['/hero-rooster.jpg'],
                  'gamefowl': {
                    'images': ['/rooster-detail.jpg'],
                  },
                  'farm': {'id': 7, 'logo_url': 'farms/logos/hill.jpg'},
                },
                {'id': 2, 'name': 'Second Rooster', 'image': null},
              ],
            },
          }),
          200);
    });
    addTearDown(client.close);

    final farm =
        await FarmsService(httpClient: client).fetchFarmWithListings(7);
    final listings = farm['listings'] as List;
    expect(farm['cover_url'],
        'https://example.test/storage/farms/covers/hill.jpg');
    expect(listings.map((entry) => entry['name']),
        ['Sample Rooster', 'Second Rooster']);
    expect(listings.first['image'], 'https://example.test/hero-rooster.jpg');
    expect(listings.first['images'], ['https://example.test/hero-rooster.jpg']);
    expect(listings.first['gamefowl']['images'],
        ['https://example.test/rooster-detail.jpg']);
    expect(listings.first['farm']['logo_url'],
        'https://example.test/storage/farms/logos/hill.jpg');
    expect(listings.last['image'], isNull);
  });

  test('accepts an empty farm listings array', () async {
    final client = MockClient((request) async => http.Response(
        '{"success":true,"data":{"id":7,"name":"Hill Farm","listings":[]}}',
        200));
    addTearDown(client.close);

    final farm =
        await FarmsService(httpClient: client).fetchFarmWithListings(7);
    expect(farm['listings'], isEmpty);
  });

  test('farm listings reject HTTP errors and malformed responses', () async {
    for (final response in [
      http.Response('Missing', 404),
      http.Response('not-json', 200),
      http.Response('{"success":false,"data":{"listings":[]}}', 200),
      http.Response('{"success":true,"data":[]}', 200),
      http.Response('{"success":true,"data":{"id":7}}', 200),
      http.Response('{"success":true,"data":{"listings":{}}}', 200),
      http.Response('{"success":true,"data":{"listings":[null]}}', 200),
    ]) {
      final client = MockClient((request) async => response);
      await expectLater(
        FarmsService(httpClient: client).fetchFarmWithListings(7),
        throwsException,
      );
      client.close();
    }
  });

  test('fetches one gamefowl listing and resolves nested images', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(),
          'https://example.test/api/farm-gamefowl-listings/1');
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 1,
              'name': 'Sample Gamefowl Rooster',
              'image': '/hero-rooster.jpg',
              'images': ['/hero-rooster.jpg'],
              'gamefowl': {
                'images': ['/detail.jpg']
              },
              'farm': {'name': 'Test Farm', 'logo_url': 'farms/logos/test.png'},
            }
          }),
          200);
    });
    addTearDown(client.close);

    final listing =
        await FarmsService(httpClient: client).fetchFarmGamefowlListing(1);
    expect(listing['name'], 'Sample Gamefowl Rooster');
    expect(listing['image'], 'https://example.test/hero-rooster.jpg');
    expect(listing['images'], ['https://example.test/hero-rooster.jpg']);
    expect(listing['gamefowl']['images'], ['https://example.test/detail.jpg']);
    expect(listing['farm']['logo_url'],
        'https://example.test/storage/farms/logos/test.png');
  });

  test('gamefowl listing rejects unsuccessful or malformed responses',
      () async {
    for (final response in [
      http.Response('Missing', 404),
      http.Response('not-json', 200),
      http.Response('{"success":false,"data":{"id":1}}', 200),
      http.Response('{"success":true,"data":[]}', 200),
      http.Response('{"success":true,"data":{}}', 200),
    ]) {
      final client = MockClient((request) async => response);
      await expectLater(
        FarmsService(httpClient: client).fetchFarmGamefowlListing(1),
        throwsException,
      );
      client.close();
    }
  });
}
