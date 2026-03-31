import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:parking_app/network/parking_api.dart' as parking;
import 'package:parking_app/network/route_api.dart' as routing;
import 'package:parking_app/network/smart_navigation_ai_model.dart';
import 'package:parking_app/network/tdas_service.dart';
import 'package:parking_app/network/toll_service.dart';
import 'package:parking_app/network/smart_navigation_types.dart';

export 'package:parking_app/network/smart_navigation_types.dart';

class SmartNavigationResult {
  const SmartNavigationResult({
    required this.selectedCarpark,
    required this.selectedRoute,
    required this.selectedToll,
    required this.parkingCostEstimateHkd,
    required this.walkingDistanceMeters,
    required this.travelMinutes,
    required this.vacancyProbability,
    required this.score,
    required this.preference,
    required this.alternatives,
    required this.aiPersonalized,
    required this.aiLearningSamples,
  });

  final parking.Carpark selectedCarpark;
  final routing.RouteResult selectedRoute;
  final TollEstimate selectedToll;
  final double? parkingCostEstimateHkd;
  final double walkingDistanceMeters;
  final int travelMinutes;
  final double vacancyProbability;
  final double score;
  final SmartNavigationPreference preference;
  final List<SmartNavigationOption> alternatives;
  final bool aiPersonalized;
  final int aiLearningSamples;
}

class ParkingCostEstimate {
  const ParkingCostEstimate({
    required this.amountHkd,
    required this.summary,
    required this.rateType,
  });

  final double amountHkd;
  final String summary;
  final String rateType;
}

class SmartNavigationOption {
  const SmartNavigationOption({
    required this.carpark,
    required this.route,
    required this.toll,
    required this.parkingCostEstimateHkd,
    required this.parkingCostEstimate,
    required this.walkingDistanceMeters,
    required this.travelMinutes,
    required this.vacancyProbability,
    required this.score,
    required this.tdasInsight,
    this.aiScore = 0,
    this.aiConfidence = 0,
    this.aiReasons = const [],
    this.aiPersonalized = false,
    this.preferenceScores = const <SmartNavigationPreference, double>{},
  });

  final parking.Carpark carpark;
  final routing.RouteResult route;
  final TollEstimate toll;
  final double? parkingCostEstimateHkd;
  final ParkingCostEstimate? parkingCostEstimate;
  final double walkingDistanceMeters;
  final int travelMinutes;
  final double vacancyProbability;
  final double score;
  final TdasRouteInsight? tdasInsight;
  final double aiScore;
  final double aiConfidence;
  final List<String> aiReasons;
  final bool aiPersonalized;
  final Map<SmartNavigationPreference, double> preferenceScores;

  SmartNavigationOption copyWith({
    routing.RouteResult? route,
    TollEstimate? toll,
    double? parkingCostEstimateHkd,
    ParkingCostEstimate? parkingCostEstimate,
    double? walkingDistanceMeters,
    int? travelMinutes,
    double? vacancyProbability,
    double? score,
    TdasRouteInsight? tdasInsight,
    double? aiScore,
    double? aiConfidence,
    List<String>? aiReasons,
    bool? aiPersonalized,
    Map<SmartNavigationPreference, double>? preferenceScores,
  }) {
    return SmartNavigationOption(
      carpark: carpark,
      route: route ?? this.route,
      toll: toll ?? this.toll,
      parkingCostEstimateHkd:
          parkingCostEstimateHkd ?? this.parkingCostEstimateHkd,
      parkingCostEstimate: parkingCostEstimate ?? this.parkingCostEstimate,
      walkingDistanceMeters:
          walkingDistanceMeters ?? this.walkingDistanceMeters,
      travelMinutes: travelMinutes ?? this.travelMinutes,
      vacancyProbability: vacancyProbability ?? this.vacancyProbability,
      score: score ?? this.score,
      tdasInsight: tdasInsight ?? this.tdasInsight,
      aiScore: aiScore ?? this.aiScore,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      aiReasons: aiReasons ?? this.aiReasons,
      aiPersonalized: aiPersonalized ?? this.aiPersonalized,
      preferenceScores: preferenceScores ?? this.preferenceScores,
    );
  }
}

class SmartNavigationService {
  SmartNavigationService({
    required String osrmBaseUrl,
    this.languageCode = 'en',
    routing.OsrmRouteApi? routeApi,
    TollService? tollService,
    TdasService? tdasService,
    SmartNavigationAiModel? aiModel,
  }) : _routeApi =
           routeApi ??
           routing.OsrmRouteApi(baseUrl: osrmBaseUrl, profile: 'driving'),
       _tollService = tollService ?? TollService(),
       _tdasService = tdasService ?? const TdasService(),
       _aiModel = aiModel ?? SmartNavigationAiModel();

  final String languageCode;
  final routing.OsrmRouteApi _routeApi;
  final TollService _tollService;
  final TdasService _tdasService;
  final SmartNavigationAiModel _aiModel;
  late final Future<void> _aiModelReady = _aiModel.ensureLoaded();

  void dispose() => _tollService.dispose();

  Future<SmartNavigationResult?> planToDestination({
    required LatLng origin,
    required LatLng destination,
    required List<parking.Carpark> carparks,
    HkVehicleType vehicleType = HkVehicleType.privateCar,
    SmartNavigationPreference preference = SmartNavigationPreference.cheapest,
    String? languageCode,
    double searchRadiusMeters = 1200,
    int maxCandidates = 6,
    int estimatedParkingHours = 3,
  }) async {
    final effectiveLanguageCode = languageCode ?? this.languageCode;
    final now = DateTime.now();
    await _aiModelReady;
    final candidates = _candidateCarparks(
      destination: destination,
      carparks: carparks,
      searchRadiusMeters: searchRadiusMeters,
      maxCandidates: maxCandidates,
    );
    if (candidates.isEmpty) return null;

    final hkNowParam = await _tollService.fetchHkNowParam();
    final options = await Future.wait(
      candidates.map(
        (carpark) => _evaluateCarpark(
          origin: origin,
          destination: destination,
          carpark: carpark,
          vehicleType: vehicleType,
          languageCode: effectiveLanguageCode,
          now: now,
          hkNowParam: hkNowParam,
          estimatedParkingHours: estimatedParkingHours,
        ),
      ),
    );

    final valid = options.whereType<SmartNavigationOption>().toList(
      growable: false,
    );
    if (valid.isEmpty) return null;

    final enriched = _applyAiPersonalization(
      valid,
      preference: preference,
      languageCode: effectiveLanguageCode,
    );
    final sorted = rankOptions(enriched, preference);
    final best = sorted.first;
    return SmartNavigationResult(
      selectedCarpark: best.carpark,
      selectedRoute: best.route,
      selectedToll: best.toll,
      parkingCostEstimateHkd: best.parkingCostEstimateHkd,
      walkingDistanceMeters: best.walkingDistanceMeters,
      travelMinutes: best.travelMinutes,
      vacancyProbability: best.vacancyProbability,
      score: best.score,
      preference: preference,
      alternatives: sorted,
      aiPersonalized: _aiModel.isPersonalized,
      aiLearningSamples: _aiModel.sampleCount,
    );
  }

  static List<SmartNavigationOption> rankOptions(
    Iterable<SmartNavigationOption> options,
    SmartNavigationPreference preference,
  ) {
    final ranked = [...options];
    if (ranked.every(
      (option) => option.preferenceScores.containsKey(preference),
    )) {
      ranked.sort((a, b) {
        final scoreCmp = a.preferenceScores[preference]!.compareTo(
          b.preferenceScores[preference]!,
        );
        if (scoreCmp != 0) return scoreCmp;
        final aiCmp = b.aiScore.compareTo(a.aiScore);
        if (aiCmp != 0) return aiCmp;
        return _compareOptionsByPreference(a, b, preference);
      });
      return ranked;
    }
    ranked.sort((a, b) => _compareOptionsByPreference(a, b, preference));
    return ranked;
  }

  Future<void> recordSelection({
    required SmartNavigationOption selectedOption,
    required List<SmartNavigationOption> presentedOptions,
    required SmartNavigationPreference preference,
  }) async {
    if (presentedOptions.length < 2) return;
    await _aiModelReady;

    final featureSpace = _SmartNavigationAiFeatureSpace(presentedOptions);
    final selectedFeatures = featureSpace.vectorFor(selectedOption);
    final otherFeatures = presentedOptions
        .where((option) => !_sameSmartOption(option, selectedOption))
        .map(featureSpace.vectorFor)
        .toList(growable: false);
    if (otherFeatures.isEmpty) return;

    await _aiModel.learnPreferred(
      selectedFeatures: selectedFeatures,
      otherFeatures: otherFeatures,
      preference: preference,
    );
  }

  static int _compareOptionsByPreference(
    SmartNavigationOption a,
    SmartNavigationOption b,
    SmartNavigationPreference preference,
  ) {
    switch (preference) {
      case SmartNavigationPreference.cheapest:
        final totalA = _totalEstimatedCost(a);
        final totalB = _totalEstimatedCost(b);
        final totalCmp = totalA.compareTo(totalB);
        if (totalCmp != 0) return totalCmp;
        final tollCmp = a.toll.totalHkd.compareTo(b.toll.totalHkd);
        if (tollCmp != 0) return tollCmp;
        final parkA = a.parkingCostEstimateHkd ?? double.infinity;
        final parkB = b.parkingCostEstimateHkd ?? double.infinity;
        final parkCmp = parkA.compareTo(parkB);
        if (parkCmp != 0) return parkCmp;
        return a.travelMinutes.compareTo(b.travelMinutes);
      case SmartNavigationPreference.fastest:
        final timeCmp = a.travelMinutes.compareTo(b.travelMinutes);
        if (timeCmp != 0) return timeCmp;
        final walkCmp = a.walkingDistanceMeters.compareTo(
          b.walkingDistanceMeters,
        );
        if (walkCmp != 0) return walkCmp;
        return _totalEstimatedCost(a).compareTo(_totalEstimatedCost(b));
      case SmartNavigationPreference.availability:
        final vacancyCmp = b.vacancyProbability.compareTo(a.vacancyProbability);
        if (vacancyCmp != 0) return vacancyCmp;
        final walkCmp = a.walkingDistanceMeters.compareTo(
          b.walkingDistanceMeters,
        );
        if (walkCmp != 0) return walkCmp;
        return a.travelMinutes.compareTo(b.travelMinutes);
      case SmartNavigationPreference.shortestWalk:
        final walkCmp = a.walkingDistanceMeters.compareTo(
          b.walkingDistanceMeters,
        );
        if (walkCmp != 0) return walkCmp;
        final vacancyCmp = b.vacancyProbability.compareTo(a.vacancyProbability);
        if (vacancyCmp != 0) return vacancyCmp;
        return a.travelMinutes.compareTo(b.travelMinutes);
    }
  }

  static double _totalEstimatedCost(SmartNavigationOption option) {
    return option.toll.totalHkd +
        (option.parkingCostEstimateHkd ?? double.infinity);
  }

  List<SmartNavigationOption> _applyAiPersonalization(
    List<SmartNavigationOption> options, {
    required SmartNavigationPreference preference,
    required String languageCode,
  }) {
    if (options.isEmpty) return options;

    final featureSpace = _SmartNavigationAiFeatureSpace(options);
    final personalized = _aiModel.isPersonalized;
    final aiScores = <double>[];
    final scored =
        <
          (
            SmartNavigationOption option,
            Map<String, double> features,
            double aiScore,
            Map<SmartNavigationPreference, double> preferenceScores,
          )
        >[];

    for (final option in options) {
      final features = featureSpace.vectorFor(option);
      final aiScore = _aiModel.score(features, preference: preference);
      aiScores.add(aiScore);
      final preferenceScores = <SmartNavigationPreference, double>{
        for (final item in SmartNavigationPreference.values)
          item:
              _basePreferenceScore(features, item) -
              (_aiBlendWeight(personalized) *
                  _aiModel.score(features, preference: item)),
      };
      scored.add((option, features, aiScore, preferenceScores));
    }

    final confidences = _softmax(aiScores);
    return [
      for (var i = 0; i < scored.length; i++)
        scored[i].$1.copyWith(
          score: scored[i].$4[preference] ?? scored[i].$1.score,
          aiScore: scored[i].$3,
          aiConfidence: confidences[i],
          aiReasons: _localizedAiReasons(
            scored[i].$2,
            preference: preference,
            languageCode: languageCode,
            personalized: personalized,
          ),
          aiPersonalized: personalized,
          preferenceScores: scored[i].$4,
        ),
    ];
  }

  List<parking.Carpark> _candidateCarparks({
    required LatLng destination,
    required List<parking.Carpark> carparks,
    required double searchRadiusMeters,
    required int maxCandidates,
  }) {
    final dist = const Distance();
    final withDistance = carparks
        .where((carpark) => carpark.latitude != 0 || carpark.longitude != 0)
        .map(
          (carpark) => (
            carpark: carpark,
            walking: dist(
              destination,
              LatLng(carpark.latitude, carpark.longitude),
            ),
          ),
        )
        .toList(growable: false);
    withDistance.sort((a, b) {
      final walking = a.walking.compareTo(b.walking);
      if (walking != 0) return walking;
      final aVacancy = a.carpark.vacancy ?? -1;
      final bVacancy = b.carpark.vacancy ?? -1;
      return bVacancy.compareTo(aVacancy);
    });

    final inRadius = withDistance.where(
      (item) => item.walking <= searchRadiusMeters,
    );
    final picked = inRadius.isNotEmpty ? inRadius : withDistance;
    return picked
        .take(maxCandidates)
        .map((item) => item.carpark)
        .toList(growable: false);
  }

  Future<SmartNavigationOption?> _evaluateCarpark({
    required LatLng origin,
    required LatLng destination,
    required parking.Carpark carpark,
    required HkVehicleType vehicleType,
    required String languageCode,
    required DateTime now,
    required String hkNowParam,
    required int estimatedParkingHours,
  }) async {
    final carparkPoint = LatLng(carpark.latitude, carpark.longitude);
    final walkingDistanceMeters = const Distance()(destination, carparkPoint);

    List<routing.RouteResult> routes;
    try {
      routes = await _routeApi.routeGeoJsonAlternatives(
        origin: origin,
        destination: carparkPoint,
        alternatives: 2,
        steps: true,
      );
    } catch (_) {
      return null;
    }
    if (routes.isEmpty) return null;

    TdasRouteInsight? insight;
    try {
      insight = await _tdasService.fetchRoute(
        start: origin,
        end: carparkPoint,
        type: 'ST',
        lang: languageCode,
      );
    } catch (_) {
      insight = null;
    }

    SmartNavigationOption? best;
    for (final route in routes.where((item) => !item.hasFerry)) {
      final toll = await _tollService.estimateForRoute(
        route: route.points,
        origin: origin,
        destination: carparkPoint,
        dateTimeParam: hkNowParam,
        stepNames: route.stepNames,
        languageCode: languageCode,
        vehicleType: vehicleType,
      );
      final travelMinutes = _resolveTravelMinutes(route, insight);
      final parkingCostEstimate = ParkingCostEstimator.estimateDetailed(
        carpark,
        arrivalDateTime: now.add(Duration(minutes: travelMinutes)),
        stayDuration: Duration(hours: estimatedParkingHours),
        languageCode: languageCode,
      );
      final parkingCost = parkingCostEstimate?.amountHkd;
      final vacancyProbability = VacancyProbabilityEstimator.estimate(
        carpark: carpark,
        travelMinutes: travelMinutes,
      );
      final score = _scoreOption(
        route: route,
        toll: toll,
        parkingCostEstimateHkd: parkingCost,
        walkingDistanceMeters: walkingDistanceMeters,
        travelMinutes: travelMinutes,
        vacancyProbability: vacancyProbability,
        openingStatus: carpark.openingStatus,
        currentVacancy: carpark.vacancy,
        tdasInsight: insight,
      );
      final option = SmartNavigationOption(
        carpark: carpark,
        route: route,
        toll: toll,
        parkingCostEstimateHkd: parkingCost,
        parkingCostEstimate: parkingCostEstimate,
        walkingDistanceMeters: walkingDistanceMeters,
        travelMinutes: travelMinutes,
        vacancyProbability: vacancyProbability,
        score: score,
        tdasInsight: insight,
      );
      if (best == null || option.score < best.score) {
        best = option;
      }
    }
    return best;
  }

  double _scoreOption({
    required routing.RouteResult route,
    required TollEstimate toll,
    required double? parkingCostEstimateHkd,
    required double walkingDistanceMeters,
    required int travelMinutes,
    required double vacancyProbability,
    required String? openingStatus,
    required int? currentVacancy,
    required TdasRouteInsight? tdasInsight,
  }) {
    final tollCost = toll.hasUnknown
        ? math.max(toll.totalHkd, 12)
        : toll.totalHkd;
    final parkingCost = parkingCostEstimateHkd ?? 24;
    final walkingPenalty = walkingDistanceMeters / 140;
    final vacancyPenalty = (1 - vacancyProbability) * 45;
    final closedPenalty = _isClosed(openingStatus) ? 80.0 : 0.0;
    final emptyPenalty = currentVacancy != null && currentVacancy <= 0
        ? 100.0
        : 0.0;
    final unknownVacancyPenalty = currentVacancy == null ? 10.0 : 0.0;
    final majorRoadBonus = route.majorRoadDistanceMeters > 0 ? -2.5 : 0.0;

    return (travelMinutes * 1.8) +
        (tollCost * 1.2) +
        (parkingCost * 0.75) +
        walkingPenalty +
        vacancyPenalty +
        _tdasPenalty(tdasInsight, travelMinutes) +
        closedPenalty +
        emptyPenalty +
        unknownVacancyPenalty +
        majorRoadBonus;
  }

  double _tdasPenalty(TdasRouteInsight? insight, int travelMinutes) {
    if (insight == null) return 0;
    final lowerSpeed = insight.journeySpeed.toLowerCase();
    var penalty = 0.0;
    if (lowerSpeed.contains('slow') ||
        lowerSpeed.contains('jam') ||
        lowerSpeed.contains('擠塞') ||
        lowerSpeed.contains('拥堵')) {
      penalty += 10;
    } else if (lowerSpeed.contains('busy') ||
        lowerSpeed.contains('moderate') ||
        lowerSpeed.contains('繁忙')) {
      penalty += 4;
    }
    if (travelMinutes >= 35) penalty += 3;
    return penalty;
  }

  bool _isClosed(String? openingStatus) {
    return VacancyProbabilityEstimator.isClosed(openingStatus);
  }

  int _resolveTravelMinutes(
    routing.RouteResult route,
    TdasRouteInsight? insight,
  ) {
    final osrmMinutes = (route.durationSeconds / 60).round();
    final tdasMinutes = _parseEtaMinutes(insight?.etaHhMm);
    if (tdasMinutes == null) return osrmMinutes;
    return math.max(osrmMinutes, tdasMinutes);
  }

  int? _parseEtaMinutes(String? etaHhMm) {
    if (etaHhMm == null) return null;
    final parts = etaHhMm.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    var total = (hours * 60) + minutes;
    if (parts.length == 3) {
      final seconds = int.tryParse(parts[2]);
      if (seconds == null) return null;
      if (seconds >= 30) total += 1;
    }
    return total;
  }

  double _basePreferenceScore(
    Map<String, double> features,
    SmartNavigationPreference preference,
  ) {
    double penalty(String key) => 1 - (features[key] ?? 0);

    switch (preference) {
      case SmartNavigationPreference.cheapest:
        return (penalty(SmartNavigationAiModel.featureTotalCost) * 0.48) +
            (penalty(SmartNavigationAiModel.featureTollCost) * 0.15) +
            (penalty(SmartNavigationAiModel.featureParkingCost) * 0.15) +
            (penalty(SmartNavigationAiModel.featureTravelTime) * 0.10) +
            (penalty(SmartNavigationAiModel.featureVacancyChance) * 0.08) +
            (penalty(SmartNavigationAiModel.featureWalkDistance) * 0.04);
      case SmartNavigationPreference.fastest:
        return (penalty(SmartNavigationAiModel.featureTravelTime) * 0.48) +
            (penalty(SmartNavigationAiModel.featureTrafficFlow) * 0.18) +
            (penalty(SmartNavigationAiModel.featureWalkDistance) * 0.12) +
            (penalty(SmartNavigationAiModel.featureTotalCost) * 0.10) +
            (penalty(SmartNavigationAiModel.featureVacancyChance) * 0.08) +
            (penalty(SmartNavigationAiModel.featureMajorRoad) * 0.04);
      case SmartNavigationPreference.availability:
        return (penalty(SmartNavigationAiModel.featureVacancyChance) * 0.46) +
            (penalty(SmartNavigationAiModel.featureAvailabilityNow) * 0.18) +
            (penalty(SmartNavigationAiModel.featureWalkDistance) * 0.14) +
            (penalty(SmartNavigationAiModel.featureTravelTime) * 0.12) +
            (penalty(SmartNavigationAiModel.featureTotalCost) * 0.10);
      case SmartNavigationPreference.shortestWalk:
        return (penalty(SmartNavigationAiModel.featureWalkDistance) * 0.50) +
            (penalty(SmartNavigationAiModel.featureVacancyChance) * 0.18) +
            (penalty(SmartNavigationAiModel.featureTravelTime) * 0.16) +
            (penalty(SmartNavigationAiModel.featureTotalCost) * 0.10) +
            (penalty(SmartNavigationAiModel.featureAvailabilityNow) * 0.06);
    }
  }

  List<String> _localizedAiReasons(
    Map<String, double> features, {
    required SmartNavigationPreference preference,
    required String languageCode,
    required bool personalized,
  }) {
    final topFeatures = _aiModel.topFeatureKeys(
      features,
      preference: preference,
      limit: 3,
    );
    if (topFeatures.isEmpty) {
      return [_localizedAiFallback(languageCode, personalized)];
    }

    final reasons = <String>[];
    for (final feature in topFeatures) {
      final text = _localizedAiFeature(feature, languageCode);
      if (!reasons.contains(text)) {
        reasons.add(text);
      }
    }
    if (reasons.isEmpty) {
      reasons.add(_localizedAiFallback(languageCode, personalized));
    }
    return reasons.take(3).toList(growable: false);
  }

  String _localizedAiFeature(String feature, String languageCode) {
    switch (feature) {
      case SmartNavigationAiModel.featureTravelTime:
        return switch (languageCode.toLowerCase()) {
          'tc' => 'AI 判斷行車時間較短',
          'sc' => 'AI 判断行车时间较短',
          _ => 'AI expects a shorter drive',
        };
      case SmartNavigationAiModel.featureTotalCost:
        return switch (languageCode.toLowerCase()) {
          'tc' => 'AI 判斷總成本較低',
          'sc' => 'AI 判断总成本较低',
          _ => 'AI expects a lower total cost',
        };
      case SmartNavigationAiModel.featureWalkDistance:
        return switch (languageCode.toLowerCase()) {
          'tc' => 'AI 判斷步行距離較短',
          'sc' => 'AI 判断步行距离较短',
          _ => 'AI expects less walking',
        };
      case SmartNavigationAiModel.featureVacancyChance:
      case SmartNavigationAiModel.featureAvailabilityNow:
        return switch (languageCode.toLowerCase()) {
          'tc' => 'AI 估計較大機會有位',
          'sc' => 'AI 估计较大机会有位',
          _ => 'AI expects a better vacancy chance',
        };
      case SmartNavigationAiModel.featureTollCost:
        return switch (languageCode.toLowerCase()) {
          'tc' => 'AI 判斷過路費較低',
          'sc' => 'AI 判断过路费较低',
          _ => 'AI expects lower tolls',
        };
      case SmartNavigationAiModel.featureParkingCost:
        return switch (languageCode.toLowerCase()) {
          'tc' => 'AI 估計停車費較低',
          'sc' => 'AI 估计停车费较低',
          _ => 'AI expects lower parking fees',
        };
      case SmartNavigationAiModel.featureTrafficFlow:
        return switch (languageCode.toLowerCase()) {
          'tc' => 'AI 判斷沿途交通較順',
          'sc' => 'AI 判断沿途交通较顺',
          _ => 'AI expects smoother traffic',
        };
      case SmartNavigationAiModel.featureMajorRoad:
        return switch (languageCode.toLowerCase()) {
          'tc' => 'AI 偏向較直接的主幹道路線',
          'sc' => 'AI 偏向较直接的主干道路线',
          _ => 'AI favors a more direct main-road route',
        };
      case SmartNavigationAiModel.featureMetered:
        return switch (languageCode.toLowerCase()) {
          'tc' => 'AI 認為路邊錶位更合適',
          'sc' => 'AI 认为路边表位更合适',
          _ => 'AI sees metered parking as a good fit',
        };
    }
    return _localizedAiFallback(languageCode, false);
  }

  String _localizedAiFallback(String languageCode, bool personalized) {
    if (personalized) {
      return switch (languageCode.toLowerCase()) {
        'tc' => 'AI 綜合你的近期選擇後認為最合適',
        'sc' => 'AI 综合你的近期选择后认为最合适',
        _ => 'AI thinks this best matches your recent choices',
      };
    }
    return switch (languageCode.toLowerCase()) {
      'tc' => 'AI 依目前路況與成本綜合評估',
      'sc' => 'AI 依目前路况与成本综合评估',
      _ => 'AI balanced traffic, cost, and availability',
    };
  }

  static double _aiBlendWeight(bool personalized) => personalized ? 0.28 : 0.12;

  static List<double> _softmax(List<double> values) {
    if (values.isEmpty) return const <double>[];
    final safeValues = values
        .map((value) => value.isFinite ? value : 0.0)
        .toList(growable: false);
    final maxValue = safeValues.reduce(math.max);
    final exps = safeValues
        .map((value) => math.exp(value - maxValue))
        .toList(growable: false);
    final sum = exps.fold<double>(0, (total, value) => total + value);
    if (!sum.isFinite || sum <= 0) {
      return List<double>.filled(safeValues.length, 1 / safeValues.length);
    }
    return exps.map((value) => value / sum).toList(growable: false);
  }

  static bool _sameSmartOption(
    SmartNavigationOption a,
    SmartNavigationOption b,
  ) {
    return a.carpark.id == b.carpark.id &&
        a.route.distanceMeters.round() == b.route.distanceMeters.round() &&
        a.route.durationSeconds.round() == b.route.durationSeconds.round();
  }
}

class _SmartNavigationAiFeatureSpace {
  _SmartNavigationAiFeatureSpace(List<SmartNavigationOption> options) {
    _parkingFallback = _parkingFallbackFor(options);
    _totalCostMin = _minValue(
      options
          .map((option) => _comparableTotalCost(option, _parkingFallback))
          .toList(growable: false),
    );
    _totalCostMax = _maxValue(
      options
          .map((option) => _comparableTotalCost(option, _parkingFallback))
          .toList(growable: false),
    );
    _travelMin = _minValue(
      options
          .map((option) => option.travelMinutes.toDouble())
          .toList(growable: false),
    );
    _travelMax = _maxValue(
      options
          .map((option) => option.travelMinutes.toDouble())
          .toList(growable: false),
    );
    _walkMin = _minValue(
      options
          .map((option) => option.walkingDistanceMeters)
          .toList(growable: false),
    );
    _walkMax = _maxValue(
      options
          .map((option) => option.walkingDistanceMeters)
          .toList(growable: false),
    );
    _tollMin = _minValue(
      options.map((option) => option.toll.totalHkd).toList(growable: false),
    );
    _tollMax = _maxValue(
      options.map((option) => option.toll.totalHkd).toList(growable: false),
    );
    _parkingMin = _minValue(
      options
          .map((option) => option.parkingCostEstimateHkd ?? _parkingFallback)
          .toList(growable: false),
    );
    _parkingMax = _maxValue(
      options
          .map((option) => option.parkingCostEstimateHkd ?? _parkingFallback)
          .toList(growable: false),
    );
  }

  late final double _parkingFallback;
  late final double _totalCostMin;
  late final double _totalCostMax;
  late final double _travelMin;
  late final double _travelMax;
  late final double _walkMin;
  late final double _walkMax;
  late final double _tollMin;
  late final double _tollMax;
  late final double _parkingMin;
  late final double _parkingMax;

  Map<String, double> vectorFor(SmartNavigationOption option) {
    final totalCost = _comparableTotalCost(option, _parkingFallback);
    final parkingCost = option.parkingCostEstimateHkd ?? _parkingFallback;
    final trafficPenalty = _trafficPenalty(option.tdasInsight);
    final roadCoverage = option.route.distanceMeters <= 0
        ? 0.0
        : option.route.majorRoadDistanceMeters / option.route.distanceMeters;

    return <String, double>{
      SmartNavigationAiModel.featureTravelTime: _inverseNormalize(
        option.travelMinutes.toDouble(),
        min: _travelMin,
        max: _travelMax,
      ),
      SmartNavigationAiModel.featureTotalCost: _inverseNormalize(
        totalCost,
        min: _totalCostMin,
        max: _totalCostMax,
      ),
      SmartNavigationAiModel.featureWalkDistance: _inverseNormalize(
        option.walkingDistanceMeters,
        min: _walkMin,
        max: _walkMax,
      ),
      SmartNavigationAiModel.featureVacancyChance: option.vacancyProbability
          .clamp(0.01, 0.98),
      SmartNavigationAiModel.featureTollCost: _inverseNormalize(
        option.toll.totalHkd,
        min: _tollMin,
        max: _tollMax,
      ),
      SmartNavigationAiModel.featureParkingCost: _inverseNormalize(
        parkingCost,
        min: _parkingMin,
        max: _parkingMax,
      ),
      SmartNavigationAiModel.featureTrafficFlow: 1 - trafficPenalty,
      SmartNavigationAiModel.featureMajorRoad: _clampDouble(roadCoverage),
      SmartNavigationAiModel.featureAvailabilityNow:
          option.carpark.vacancy == null
          ? 0.45
          : option.carpark.vacancy! > 0
          ? 1.0
          : 0.0,
      SmartNavigationAiModel.featureMetered:
          option.carpark.id.startsWith('metered:') ? 1.0 : 0.0,
    };
  }

  static double _parkingFallbackFor(List<SmartNavigationOption> options) {
    final knownParkingCosts = options
        .map((option) => option.parkingCostEstimateHkd)
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);
    if (knownParkingCosts.isEmpty) return 24.0;
    return math.max(_maxValue(knownParkingCosts), 24.0);
  }

  static double _comparableTotalCost(
    SmartNavigationOption option,
    double parkingFallback,
  ) {
    final parkingCost = option.parkingCostEstimateHkd;
    return option.toll.totalHkd +
        ((parkingCost != null && parkingCost.isFinite)
            ? parkingCost
            : parkingFallback);
  }

  static double _trafficPenalty(TdasRouteInsight? insight) {
    if (insight == null) return 0.35;
    final lower = insight.journeySpeed.toLowerCase();
    if (lower.contains('slow') ||
        lower.contains('jam') ||
        lower.contains('擠塞') ||
        lower.contains('拥堵')) {
      return 0.88;
    }
    if (lower.contains('busy') ||
        lower.contains('moderate') ||
        lower.contains('繁忙')) {
      return 0.52;
    }
    return 0.18;
  }

  static double _inverseNormalize(
    double value, {
    required double min,
    required double max,
  }) {
    if ((max - min).abs() < 0.0001) return 0.65;
    final normalized = (value - min) / (max - min);
    return _clampDouble(1 - normalized);
  }

  static double _clampDouble(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  static double _minValue(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce(math.min);
  }

  static double _maxValue(List<double> values) {
    if (values.isEmpty) return 1;
    return values.reduce(math.max);
  }
}

class ParkingCostEstimator {
  static double? estimate(
    parking.Carpark carpark, {
    int estimatedParkingHours = 3,
  }) {
    return estimateDetailed(
      carpark,
      arrivalDateTime: DateTime.now(),
      stayDuration: Duration(hours: estimatedParkingHours),
    )?.amountHkd;
  }

  static ParkingCostEstimate? estimateDetailed(
    parking.Carpark carpark, {
    required DateTime arrivalDateTime,
    required Duration stayDuration,
    String languageCode = 'en',
  }) {
    final priced = carpark.privateCarRates
        .where((rate) => rate.price != null && rate.price! >= 0)
        .toList(growable: false);
    if (priced.isEmpty) return null;

    final estimates = priced
        .map(
          (rate) => _estimateForRate(
            rate,
            arrivalDateTime: arrivalDateTime,
            stayDuration: stayDuration,
            languageCode: languageCode,
          ),
        )
        .whereType<ParkingCostEstimate>()
        .toList(growable: false);
    if (estimates.isEmpty) return null;

    estimates.sort((a, b) => a.amountHkd.compareTo(b.amountHkd));
    return estimates.first;
  }

  static ParkingCostEstimate? _estimateForRate(
    parking.CarparkRate rate, {
    required DateTime arrivalDateTime,
    required Duration stayDuration,
    required String languageCode,
  }) {
    final price = rate.price;
    if (price == null || price < 0) return null;
    if (!_matchesWeekday(rate, arrivalDateTime)) return null;
    if (!_matchesTimeWindow(rate, arrivalDateTime)) return null;

    final normalizedType = (rate.type ?? '').trim();
    final stayHours = math.max(1, (stayDuration.inMinutes / 60).ceil());
    switch (normalizedType) {
      case 'hourly':
        final billableHours = math.max(rate.usageMinimum ?? 1, stayHours);
        final amount = price * billableHours;
        return ParkingCostEstimate(
          amountHkd: amount,
          summary: _localizedEstimatedHourlySummary(
            amount: amount,
            hours: billableHours,
            languageCode: languageCode,
          ),
          rateType: normalizedType,
        );
      case '12-hour':
        final blocks = math.max(1, (stayDuration.inMinutes / (12 * 60)).ceil());
        final amount = price * blocks;
        return ParkingCostEstimate(
          amountHkd: amount,
          summary: _localizedFixedSummary(
            amount: amount,
            type: normalizedType,
            languageCode: languageCode,
          ),
          rateType: normalizedType,
        );
      case '24-hour':
        final blocks = math.max(1, (stayDuration.inMinutes / (24 * 60)).ceil());
        final amount = price * blocks;
        return ParkingCostEstimate(
          amountHkd: amount,
          summary: _localizedFixedSummary(
            amount: amount,
            type: normalizedType,
            languageCode: languageCode,
          ),
          rateType: normalizedType,
        );
      default:
        return ParkingCostEstimate(
          amountHkd: price,
          summary: _localizedFixedSummary(
            amount: price,
            type: normalizedType,
            languageCode: languageCode,
          ),
          rateType: normalizedType,
        );
    }
  }

  static bool _matchesWeekday(
    parking.CarparkRate rate,
    DateTime arrivalDateTime,
  ) {
    if (rate.weekdays.isEmpty) return true;
    final weekdayCode = switch (arrivalDateTime.weekday) {
      DateTime.monday => 'MON',
      DateTime.tuesday => 'TUE',
      DateTime.wednesday => 'WED',
      DateTime.thursday => 'THU',
      DateTime.friday => 'FRI',
      DateTime.saturday => 'SAT',
      DateTime.sunday => 'SUN',
      _ => '',
    };
    return rate.weekdays.contains(weekdayCode) || rate.weekdays.contains('PH');
  }

  static bool _matchesTimeWindow(
    parking.CarparkRate rate,
    DateTime arrivalDateTime,
  ) {
    final start = _parseHm(rate.periodStart);
    final end = _parseHm(rate.periodEnd);
    if (start == null || end == null) return true;

    final minuteOfDay = (arrivalDateTime.hour * 60) + arrivalDateTime.minute;
    if (end == start) return true;
    if (end > start) {
      return minuteOfDay >= start && minuteOfDay <= end;
    }
    return minuteOfDay >= start || minuteOfDay <= end;
  }

  static int? _parseHm(String? value) {
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    return (hour * 60) + minute;
  }

  static String _localizedEstimatedHourlySummary({
    required double amount,
    required int hours,
    required String languageCode,
  }) {
    final formatted = _formatHkd(amount);
    switch (languageCode.toLowerCase()) {
      case 'tc':
        return '預估 $hours 小時 $formatted';
      case 'sc':
        return '预估 $hours 小时 $formatted';
      case 'en':
      default:
        return 'Est. $hours h $formatted';
    }
  }

  static String _localizedFixedSummary({
    required double amount,
    required String type,
    required String languageCode,
  }) {
    final formatted = _formatHkd(amount);
    final label = switch (type) {
      'day-pass' || 'day-park' => switch (languageCode.toLowerCase()) {
        'tc' => '日泊',
        'sc' => '日泊',
        _ => 'Day park',
      },
      'night-park' || 'night-park (monthly)' => switch (languageCode
          .toLowerCase()) {
        'tc' => '夜泊',
        'sc' => '夜泊',
        _ => 'Night park',
      },
      'dayNight' || 'day-night' => switch (languageCode.toLowerCase()) {
        'tc' => '日夜泊',
        'sc' => '日夜泊',
        _ => 'Day & night',
      },
      '12-hour' => switch (languageCode.toLowerCase()) {
        'tc' => '12 小時',
        'sc' => '12 小时',
        _ => '12-hour',
      },
      '24-hour' => switch (languageCode.toLowerCase()) {
        'tc' => '24 小時',
        'sc' => '24 小时',
        _ => '24-hour',
      },
      _ => switch (languageCode.toLowerCase()) {
        'tc' => '停車費預估',
        'sc' => '停车费预估',
        _ => 'Est. parking',
      },
    };
    return '$label $formatted';
  }

  static String _formatHkd(double amount) {
    final rounded = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return 'HK\$$rounded';
  }
}

class VacancyProbabilityEstimator {
  static double estimate({
    required parking.Carpark carpark,
    required int travelMinutes,
  }) {
    final vacancy = carpark.vacancy;
    var probability = switch (vacancy) {
      null => 0.45,
      <= 0 => 0.03,
      <= 2 => 0.10,
      <= 5 => 0.22,
      <= 10 => 0.42,
      <= 20 => 0.65,
      <= 35 => 0.82,
      _ => 0.92,
    };

    probability -= math.min(travelMinutes / 180, 0.24);

    final now = DateTime.now();
    final hour = now.hour;
    if ((hour >= 12 && hour <= 14) || (hour >= 18 && hour <= 21)) {
      probability -= 0.08;
    }
    if (now.weekday >= DateTime.saturday && hour >= 11 && hour <= 19) {
      probability -= 0.05;
    }
    if (isClosed(carpark.openingStatus)) {
      probability = 0.01;
    }

    return probability.clamp(0.01, 0.98);
  }

  static bool isClosed(String? openingStatus) {
    final value = openingStatus?.trim().toLowerCase();
    if (value == null || value.isEmpty) return false;
    return value.contains('closed') ||
        value.contains('full') ||
        value.contains('suspended');
  }
}
