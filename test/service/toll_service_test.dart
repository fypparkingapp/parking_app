import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:parking_app/network/toll_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Detects Tai Lam Tunnel and prices it', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'www.hkemobility.gov.hk' &&
          request.url.path == '/api/drss/toll/rate') {
        expect(request.url.queryParameters['tunnel'], 'tlt');
        expect(request.url.queryParameters['vehicleType'], 'pc');
        return http.Response('{"pc": 30.0}', 200);
      }
      if (request.url.host == 'www.hkemobility.gov.hk' &&
          request.url.path == '/api/drss/toll/time') {
        return http.Response('"2025-12-18T15:05:16.1209699+08:00"', 200);
      }
      return http.Response('not found', 404);
    });

    final tollService = TollService(client: client);
    addTearDown(tollService.dispose);

    // Route points passing through the Tai Lam Tunnel corridor detection points.
    final route = <LatLng>[
      const LatLng(22.3700, 114.1040),
      const LatLng(22.4337560, 114.0616030),
      const LatLng(22.4209200, 114.0644197),
      const LatLng(22.4153790, 114.0630920),
      const LatLng(22.4443, 114.0222),
    ];

    final estimate = await tollService.estimateForRoute(
      route: route,
      origin: route.first,
      destination: route.last,
      dateTimeParam: '2025-12-18 15:05',
      vehicleType: HkVehicleType.privateCar,
      languageCode: 'en',
    );

    expect(estimate.totalHkd, 30.0);
    expect(estimate.charges.any((c) => c.facilityId == 'tlt'), isTrue);
  });
}
