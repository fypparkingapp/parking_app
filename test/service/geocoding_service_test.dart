import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_app/network/geocoding_service.dart';
import 'package:parking_app/network/local_landmarks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Matches local landmark aliases for HKU before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local landmark aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('香港大學');

      expect(results, isNotEmpty);
      expect(results.first.displayName, '香港大學 HKU');
      expect(results.first.latitude, closeTo(22.28302, 0.00001));
      expect(results.first.longitude, closeTo(114.13714, 0.00001));
    },
  );

  test('Exposes POI schema metadata and bilingual aliases', () async {
    final localLandmarks = await loadBundledLocalLandmarks();
    final hku = localLandmarks.first;
    final ifc = localLandmarks.firstWhere(
      (landmark) => landmark.displayName == 'ifc mall',
    );

    expect(hku.category, LocalPoiCategory.education);
    expect(hku.subcategory, LocalPoiSubcategory.campus);
    expect(hku.resolvedNameZh, '香港大學');
    expect(hku.resolvedNameEn, 'the university of hong kong');
    expect(hku.aliasesZh, contains('港大'));
    expect(hku.aliasesEn, contains('university of hong kong'));

    expect(ifc.category, LocalPoiCategory.shoppingRetail);
    expect(ifc.subcategory, LocalPoiSubcategory.mall);
    expect(ifc.aliasesZh, contains('國際金融中心'));
    expect(ifc.aliasesEn, contains('international finance center'));
  });

  test(
    'Matches local landmark aliases for malls before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local mall aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('festival walk');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Festival Walk');
      expect(results.first.latitude, closeTo(22.33744, 0.00001));
      expect(results.first.longitude, closeTo(114.17479, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for residential estates before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local estate aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('黃埔花園');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Whampoa Garden');
      expect(results.first.latitude, closeTo(22.30472, 0.00001));
      expect(results.first.longitude, closeTo(114.18807, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for hospitals before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local hospital aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('瑪麗醫院');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Queen Mary Hospital');
      expect(results.first.latitude, closeTo(22.27076, 0.00001));
      expect(results.first.longitude, closeTo(114.13184, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for government buildings before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local government aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('政府總部');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Central Government Complex');
      expect(results.first.latitude, closeTo(22.27947, 0.00001));
      expect(results.first.longitude, closeTo(114.16106, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for MTR malls before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local MTR mall aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('圍方');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'The Wai');
      expect(results.first.latitude, closeTo(22.38192, 0.00001));
      expect(results.first.longitude, closeTo(114.18806, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for schools before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local school aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('dbs');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Diocesan Boys\' School');
      expect(results.first.latitude, closeTo(22.31232, 0.00001));
      expect(results.first.longitude, closeTo(114.17056, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for hotels before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local hotel aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('半島酒店');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'The Peninsula Hong Kong');
      expect(results.first.latitude, closeTo(22.29509, 0.00001));
      expect(results.first.longitude, closeTo(114.17193, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for theme parks before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local theme park aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('海洋公園');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Ocean Park Hong Kong');
      expect(results.first.latitude, closeTo(22.24666, 0.00001));
      expect(results.first.longitude, closeTo(114.17503, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for arts venues before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local venue aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('紅館');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Hong Kong Coliseum');
      expect(results.first.latitude, closeTo(22.30179, 0.00001));
      expect(results.first.longitude, closeTo(114.18167, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for grade A office abbreviations before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local office aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('oie');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'One Island East');
      expect(results.first.latitude, closeTo(22.28416, 0.00001));
      expect(results.first.longitude, closeTo(114.21678, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for industrial areas before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local industrial aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('觀塘工業區');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Kwun Tong Industrial Area');
      expect(results.first.latitude, closeTo(22.30951, 0.00001));
      expect(results.first.longitude, closeTo(114.22068, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for estate phases before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local phase aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('黃埔花園2期');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Whampoa Garden');
      expect(results.first.latitude, closeTo(22.30472, 0.00001));
      expect(results.first.longitude, closeTo(114.18807, 0.00001));
    },
  );

  test(
    'Matches local landmark aliases for common abbreviations before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for local abbreviation aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('cgc');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Central Government Complex');
      expect(results.first.latitude, closeTo(22.27947, 0.00001));
      expect(results.first.longitude, closeTo(114.16106, 0.00001));
    },
  );

  test('Matches colloquial office aliases before network lookup', () async {
    final client = MockClient((request) async {
      fail('network should not be called for colloquial office aliases');
    });

    final service = GeocodingService(
      client: client,
      baseUri: Uri.parse('https://photon.test/'),
      fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
    );
    addTearDown(service.dispose);

    final results = await service.geocodeMany('中銀');

    expect(results, isNotEmpty);
    expect(results.first.displayName, 'Bank of China Tower');
    expect(results.first.latitude, closeTo(22.27937, 0.00001));
    expect(results.first.longitude, closeTo(114.16179, 0.00001));
  });

  test(
    'Matches colloquial estate podium aliases before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for colloquial podium aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('黃埔平台');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Whampoa Garden');
      expect(results.first.latitude, closeTo(22.30472, 0.00001));
      expect(results.first.longitude, closeTo(114.18807, 0.00001));
    },
  );

  test(
    'Matches colloquial new territories mall aliases before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for colloquial mall aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('yoho');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'YOHO Mall');
      expect(results.first.latitude, closeTo(22.44501, 0.00001));
      expect(results.first.longitude, closeTo(114.03451, 0.00001));
    },
  );

  test(
    'Matches mixed hospital abbreviation aliases before network lookup',
    () async {
      final client = MockClient((request) async {
        fail('network should not be called for mixed hospital aliases');
      });

      final service = GeocodingService(
        client: client,
        baseUri: Uri.parse('https://photon.test/'),
        fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      );
      addTearDown(service.dispose);

      final results = await service.geocodeMany('pow hospital');

      expect(results, isNotEmpty);
      expect(results.first.displayName, 'Prince of Wales Hospital');
      expect(results.first.latitude, closeTo(22.38054, 0.00001));
      expect(results.first.longitude, closeTo(114.20083, 0.00001));
    },
  );

  test('Falls back to Nominatim when Photon returns no matches', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'photon.test' && request.url.path == '/api') {
        expect(request.url.queryParameters['q'], 'sample place');
        expect(
          request.url.queryParameters['bbox'],
          '113.8332,22.1500,114.4425,22.5619',
        );
        return http.Response('{"features":[]}', 200);
      }
      if (request.url.host == 'nominatim.test' &&
          request.url.path == '/search') {
        expect(request.url.queryParameters['q'], 'sample place');
        expect(request.url.queryParameters['bounded'], '1');
        expect(request.url.queryParameters['viewbox']?.split(','), [
          '113.8332',
          '22.5619',
          '114.4425',
          '22.15',
        ]);
        return http.Response.bytes(
          utf8.encode('''
[
  {
    "name": "香港大學 HKU",
    "display_name": "香港大學 HKU, Pok Fu Lam Road, Hong Kong",
    "lat": "22.2839758",
    "lon": "114.1355067"
  }
]
'''),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not found', 404);
    });

    final service = GeocodingService(
      client: client,
      baseUri: Uri.parse('https://photon.test/'),
      fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
    );
    addTearDown(service.dispose);

    final results = await service.geocodeMany('sample place');

    expect(results, hasLength(1));
    expect(results.first.displayName, '香港大學 HKU');
    expect(results.first.latitude, closeTo(22.2839758, 0.000001));
    expect(results.first.longitude, closeTo(114.1355067, 0.000001));
  });

  test('Falls back to platform geocoder when Nominatim is denied', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'photon.test' && request.url.path == '/api') {
        return http.Response('{"features":[]}', 200);
      }
      if (request.url.host == 'nominatim.test' &&
          request.url.path == '/search') {
        return http.Response('Access denied', 403);
      }
      return http.Response('not found', 404);
    });

    final service = GeocodingService(
      client: client,
      baseUri: Uri.parse('https://photon.test/'),
      fallbackBaseUri: Uri.parse('https://nominatim.test/search'),
      platformLookup: (query, {required limit}) async => const [
        GeocodingResult(
          displayName: 'sample place',
          latitude: 22.2839758,
          longitude: 114.1355067,
        ),
      ],
    );
    addTearDown(service.dispose);

    final results = await service.geocodeMany('sample place');

    expect(results, hasLength(1));
    expect(results.first.displayName, 'sample place');
    expect(results.first.latitude, closeTo(22.2839758, 0.000001));
    expect(results.first.longitude, closeTo(114.1355067, 0.000001));
  });
}
