import 'package:flutter_test/flutter_test.dart';
import 'package:parking_app/network/parking_api.dart';
import 'package:parking_app/network/route_api.dart' show RouteResult;
import 'package:parking_app/network/smart_navigation_service.dart';
import 'package:parking_app/network/toll_service.dart' show TollEstimate;

void main() {
  group('Smart navigation vacancy prediction integration', () {
    Carpark buildCarpark({required String id, required int? currentVacancy}) {
      return Carpark(
        id: id,
        nameEn: 'Sample',
        nameTc: 'Sample TC',
        nameSc: 'Sample SC',
        addressEn: '1 Test Street',
        addressTc: '1 Test Street TC',
        addressSc: '1 Test Street SC',
        latitude: 22.3,
        longitude: 114.1,
        operatorName: 'test',
        vacancyInfo: VacancyInfo.fromBuckets([
          VacancyBucket(
            key: 'privateCar',
            vehicleTypeKey: 'privateCar',
            available: currentVacancy,
            categoryLabel: 'GENERAL',
            lastUpdated: '2026-04-15T12:00:00',
            source: VacancySource.government,
          ),
        ]),
      );
    }

    SmartNavigationOption buildOption({
      required String id,
      required int? currentVacancy,
      required int? predictedVacancy,
      required double vacancyProbability,
    }) {
      return SmartNavigationOption(
        carpark: buildCarpark(id: id, currentVacancy: currentVacancy),
        route: RouteResult.empty,
        toll: const TollEstimate(totalHkd: 0, charges: []),
        parkingCostEstimateHkd: 20,
        parkingCostEstimate: const ParkingCostEstimate(
          amountHkd: 20,
          summary: 'HK\$20',
          rateType: 'hourly',
        ),
        walkingDistanceMeters: 120,
        travelMinutes: 8,
        predictedVacancy: predictedVacancy,
        vacancyProbability: vacancyProbability,
        score: 10,
        tdasInsight: null,
      );
    }

    test('predicted vacancy overrides a zero current vacancy', () {
      expect(
        VacancyProbabilityEstimator.effectiveVacancy(
          currentVacancy: 0,
          predictedVacancy: 7,
        ),
        7,
      );
      expect(
        VacancyProbabilityEstimator.availabilitySignal(
          currentVacancy: 0,
          predictedVacancy: 7,
        ),
        greaterThan(0.5),
      );
    });

    test(
      'arrival prediction improves vacancy probability for full carparks',
      () {
        final carpark = buildCarpark(id: 'park-1', currentVacancy: 0);

        final withoutPrediction = VacancyProbabilityEstimator.estimate(
          carpark: carpark,
          travelMinutes: 8,
        );
        final withPrediction = VacancyProbabilityEstimator.estimate(
          carpark: carpark,
          travelMinutes: 8,
          predictedVacancy: 9,
        );

        expect(withoutPrediction, lessThan(0.1));
        expect(withPrediction, greaterThan(0.4));
        expect(withPrediction, greaterThan(withoutPrediction));
      },
    );

    test('arrival prediction can downgrade a currently available carpark', () {
      final carpark = buildCarpark(id: 'park-2', currentVacancy: 12);

      final withoutPrediction = VacancyProbabilityEstimator.estimate(
        carpark: carpark,
        travelMinutes: 6,
      );
      final withPrediction = VacancyProbabilityEstimator.estimate(
        carpark: carpark,
        travelMinutes: 6,
        predictedVacancy: 0,
      );

      expect(withoutPrediction, greaterThan(0.4));
      expect(withPrediction, lessThan(0.1));
      expect(withPrediction, lessThan(withoutPrediction));
    });

    test('zero predicted vacancy is marked as a high-risk fallback', () {
      final option = buildOption(
        id: 'park-3',
        currentVacancy: 12,
        predictedVacancy: 0,
        vacancyProbability: 0.03,
      );

      expect(SmartNavigationService.isHighRiskOption(option), isTrue);
      expect(SmartNavigationService.isRecommendedOption(option), isFalse);
    });

    test('positive predicted vacancy remains recommendable', () {
      final option = buildOption(
        id: 'park-4',
        currentVacancy: 0,
        predictedVacancy: 6,
        vacancyProbability: 0.22,
      );

      expect(SmartNavigationService.isHighRiskOption(option), isFalse);
      expect(SmartNavigationService.isRecommendedOption(option), isTrue);
    });
  });
}
