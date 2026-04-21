import 'package:flutter_test/flutter_test.dart';
import 'package:parking_app/network/parking_api.dart';

void main() {
  group('ParkingApi vacancy parsing', () {
    test('parses multiple gov feed categories into typed vacancy buckets', () {
      final info = ParkingApi.parseGovVacancyFeedEntryForTesting({
        'park_id': 'park-1',
        'vehicle_type': [
          {
            'type': 'P',
            'service_category': [
              {
                'vacancy': 4,
                'vacancy_type': 'GENERAL',
                'lastupdate': '2026-04-14T10:00:00',
              },
              {
                'vacancy': 1,
                'vacancy_type': 'EV',
                'lastupdate': '2026-04-14T10:00:00',
              },
            ],
          },
          {
            'type': 'MC',
            'service_category': [
              {
                'vacancy': 2,
                'vacancy_type': 'STANDARD',
                'lastupdate': '2026-04-14T10:00:00',
              },
            ],
          },
        ],
      });

      expect(info.isEmpty, isFalse);
      expect(info.privateCarVacancy, 5);
      expect(info.totalVacancyForVehicle('motorcycle'), 2);

      final privateCarKeys = info.entries
          .where((entry) => entry.value.vehicleTypeKey == 'privateCar')
          .map((entry) => entry.key)
          .toList(growable: false);

      expect(privateCarKeys, containsAll(['privateCar:general', 'privateCar:ev']));
      expect(info['privateCar:general']?.available, 4);
      expect(info['privateCar:ev']?.categoryLabel, 'EV');
      expect(info['motorcycle']?.available, 2);
    });

    test('merge prefers live feed by vehicle type and keeps gov fallback for others', () {
      final liveVacancy = VacancyInfo.fromBuckets([
        const VacancyBucket(
          key: 'privateCar:general',
          vehicleTypeKey: 'privateCar',
          available: 4,
          categoryLabel: 'GENERAL',
          lastUpdated: '2026-04-14T10:00:00',
          source: VacancySource.government,
        ),
        const VacancyBucket(
          key: 'privateCar:ev',
          vehicleTypeKey: 'privateCar',
          available: 1,
          categoryLabel: 'EV',
          lastUpdated: '2026-04-14T10:00:00',
          source: VacancySource.government,
        ),
      ]);

      final merged = ParkingApi.mergeCarparkDataForTesting(
        ryanMetadata: {
          'park-1': {
            'sourceId': 'park-1',
            'name': 'Sample Plaza',
            'displayAddress': '1 Test Street',
            'latitude': 22.3,
            'longitude': 114.1,
            'operator': 'other',
          },
        },
        govRows: [
          {
            'park_Id': 'park-1',
            'name': 'Sample Plaza',
            'displayAddress': '1 Test Street',
            'latitude': 22.3,
            'longitude': 114.1,
            'opening_status': 'OPEN',
            'privateCar': {
              'space': 12,
              'spaceDIS': 1,
            },
            'motorCycle': {
              'space': 3,
            },
          },
        ],
        govVacancies: {'park-1': liveVacancy},
      );

      expect(merged, hasLength(1));
      final carpark = merged.single;
      expect(carpark.currentVacancy, 5);
      expect(carpark.vacancyInfo['privateCar'], isNull);
      expect(carpark.vacancyInfo['privateCar:general']?.available, 4);
      expect(carpark.vacancyInfo.totalVacancyForVehicle('motorcycle'), 3);
      expect(carpark.openingStatus, 'OPEN');
    });
  });
}
