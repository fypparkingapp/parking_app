import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parking_app/network/route_api.dart' as routing;
import 'package:parking_app/l10n/app_localizations.dart';

class _FakeSuccessApi extends routing.OsrmRouteApi {
  _FakeSuccessApi() : super(baseUrl: 'http://fake');

  @override
  Future<routing.RouteResult> routeGeoJson({
    required LatLng origin,
    required LatLng destination,
  }) async {
    return const routing.RouteResult(
      points: [LatLng(1, 1), LatLng(2, 2)],
      distanceMeters: 1234,
      durationSeconds: 420,
    );
  }
}

class _FakeErrorApi extends routing.OsrmRouteApi {
  _FakeErrorApi() : super(baseUrl: 'https://osrm.ryanpumpkin.com/');

  @override
  Future<routing.RouteResult> routeGeoJson({
    required LatLng origin,
    required LatLng destination,
  }) async {
    throw Exception('boom');
  }
}

Widget _buildSheet({
  required routing.OsrmRouteApi api,
  required Future<LatLng> Function() getLocation,
  required void Function(routing.RouteResult) onRoute,
  VoidCallback? onClear,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: routing.CarparkRouteSheet(
        carpark: const routing.Carpark(
          id: '1',
          name: 'Test Park',
          lat: 22.3,
          lng: 114.16,
          freeSpaces: 5,
        ),
        api: api,
        getCurrentLocation: getLocation,
        onRoute: onRoute,
        onClear: onClear,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CarparkRouteSheet routes and displays summary', (tester) async {
    var locationCalls = 0;
    routing.RouteResult? delivered;

    await tester.pumpWidget(
      _buildSheet(
        api: _FakeSuccessApi(),
        getLocation: () async {
          locationCalls++;
          return const LatLng(22.32, 114.17);
        },
        onRoute: (result) => delivered = result,
        onClear: () {},
      ),
    );

    expect(find.text('Route'), findsOneWidget);

    await tester.tap(find.text('Route'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(locationCalls, 1);
    expect(delivered, isNotNull);
    expect(delivered!.distanceMeters, 1234);
    expect(find.textContaining('ETA'), findsOneWidget);
    expect(find.textContaining('Distance'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('CarparkRouteSheet surfaces routing errors', (tester) async {
    routing.RouteResult? delivered;

    await tester.pumpWidget(
      _buildSheet(
        api: _FakeErrorApi(),
        getLocation: () async => const LatLng(22.32, 114.17),
        onRoute: (result) => delivered = result,
      ),
    );

    await tester.tap(find.text('Route'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(delivered, isNull);
    expect(find.textContaining('Exception: boom'), findsOneWidget);
  });
}
