import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:parking_app/network/smart_navigation_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartNavigationAiModel {
  SmartNavigationAiModel({this.storageKey = 'smartNavigationAiModelV1'});

  static const String featureTravelTime = 'travel_time';
  static const String featureTotalCost = 'total_cost';
  static const String featureWalkDistance = 'walk_distance';
  static const String featureVacancyChance = 'vacancy_chance';
  static const String featureTollCost = 'toll_cost';
  static const String featureParkingCost = 'parking_cost';
  static const String featureTrafficFlow = 'traffic_flow';
  static const String featureMajorRoad = 'major_road';
  static const String featureAvailabilityNow = 'availability_now';
  static const String featureMetered = 'metered';

  static const List<String> featureKeys = <String>[
    featureTravelTime,
    featureTotalCost,
    featureWalkDistance,
    featureVacancyChance,
    featureTollCost,
    featureParkingCost,
    featureTrafficFlow,
    featureMajorRoad,
    featureAvailabilityNow,
    featureMetered,
  ];

  static const Map<String, double> _defaultWeights = <String, double>{
    featureTravelTime: 0.95,
    featureTotalCost: 0.88,
    featureWalkDistance: 0.72,
    featureVacancyChance: 1.08,
    featureTollCost: 0.34,
    featureParkingCost: 0.44,
    featureTrafficFlow: 0.62,
    featureMajorRoad: 0.18,
    featureAvailabilityNow: 0.28,
    featureMetered: 0.04,
  };

  static final Map<SmartNavigationPreference, Map<String, double>>
  _defaultPreferenceWeights = <SmartNavigationPreference, Map<String, double>>{
    SmartNavigationPreference.cheapest: <String, double>{
      featureTotalCost: 0.58,
      featureTollCost: 0.34,
      featureParkingCost: 0.40,
      featureTravelTime: 0.10,
    },
    SmartNavigationPreference.fastest: <String, double>{
      featureTravelTime: 0.66,
      featureTrafficFlow: 0.48,
      featureMajorRoad: 0.22,
      featureWalkDistance: 0.08,
    },
    SmartNavigationPreference.availability: <String, double>{
      featureVacancyChance: 0.74,
      featureAvailabilityNow: 0.36,
      featureTravelTime: 0.16,
      featureWalkDistance: 0.08,
    },
    SmartNavigationPreference.shortestWalk: <String, double>{
      featureWalkDistance: 0.76,
      featureVacancyChance: 0.20,
      featureTravelTime: 0.12,
    },
  };

  final String storageKey;

  bool _loaded = false;
  Future<void>? _loadFuture;
  double _bias = 0;
  int _sampleCount = 0;
  late final Map<String, double> _weights = _copyWeights(_defaultWeights);
  late final Map<SmartNavigationPreference, Map<String, double>>
  _preferenceWeights = <SmartNavigationPreference, Map<String, double>>{
    for (final preference in SmartNavigationPreference.values)
      preference: _copyWeights(
        _defaultPreferenceWeights[preference] ?? const {},
      ),
  };

  int get sampleCount => _sampleCount;
  bool get isPersonalized => _sampleCount >= 3;

  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    _loadFuture ??= _load();
    return _loadFuture!;
  }

  double score(
    Map<String, double> features, {
    required SmartNavigationPreference preference,
  }) {
    final effectiveWeights = weightsFor(preference);
    var total = _bias;
    for (final key in featureKeys) {
      total += (effectiveWeights[key] ?? 0) * (features[key] ?? 0);
    }
    return total;
  }

  Map<String, double> weightsFor(SmartNavigationPreference preference) {
    final merged = _copyWeights(_weights);
    final preferenceWeights = _preferenceWeights[preference];
    if (preferenceWeights == null) return merged;
    for (final entry in preferenceWeights.entries) {
      merged[entry.key] = (merged[entry.key] ?? 0) + entry.value;
    }
    return merged;
  }

  List<String> topFeatureKeys(
    Map<String, double> features, {
    required SmartNavigationPreference preference,
    int limit = 2,
    double minContribution = 0.16,
  }) {
    final weights = weightsFor(preference);
    final ranked = <({String key, double contribution})>[];
    for (final key in featureKeys) {
      final contribution = (weights[key] ?? 0) * (features[key] ?? 0);
      if (contribution >= minContribution) {
        ranked.add((key: key, contribution: contribution));
      }
    }
    ranked.sort((a, b) => b.contribution.compareTo(a.contribution));
    return ranked.take(limit).map((item) => item.key).toList(growable: false);
  }

  Future<void> learnPreferred({
    required Map<String, double> selectedFeatures,
    required Iterable<Map<String, double>> otherFeatures,
    required SmartNavigationPreference preference,
  }) async {
    await ensureLoaded();
    var updated = false;
    final prefWeights = _preferenceWeights[preference]!;
    final baseLearningRate = 0.18 / math.sqrt((_sampleCount + 1).toDouble());
    final preferenceLearningRate = baseLearningRate * 0.85;

    for (final other in otherFeatures) {
      final selectedScore = score(selectedFeatures, preference: preference);
      final otherScore = score(other, preference: preference);
      final margin = selectedScore - otherScore;
      final desiredMargin = 0.55;
      final error = margin >= desiredMargin ? 0.08 : (desiredMargin - margin);

      for (final key in featureKeys) {
        final delta = (selectedFeatures[key] ?? 0) - (other[key] ?? 0);
        if (delta.abs() < 0.0001) continue;
        _weights[key] = _clampDouble(
          (_weights[key] ?? 0) + (baseLearningRate * error * delta),
          min: -2.5,
          max: 2.5,
        );
        prefWeights[key] = _clampDouble(
          (prefWeights[key] ?? 0) + (preferenceLearningRate * error * delta),
          min: -1.8,
          max: 1.8,
        );
      }
      _bias = _clampDouble(
        _bias + (baseLearningRate * error * 0.05),
        min: -1.2,
        max: 1.2,
      );
      updated = true;
    }

    if (!updated) return;
    _sampleCount += 1;
    await _persist();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) {
        _loaded = true;
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _loaded = true;
        return;
      }

      _bias = (decoded['bias'] as num?)?.toDouble() ?? 0;
      _sampleCount = (decoded['sampleCount'] as num?)?.toInt() ?? 0;

      final weights = decoded['weights'];
      if (weights is Map) {
        for (final key in featureKeys) {
          final value = weights[key];
          if (value is num) {
            _weights[key] = value.toDouble();
          }
        }
      }

      final preferences = decoded['preferences'];
      if (preferences is Map) {
        for (final preference in SmartNavigationPreference.values) {
          final rawPreference = preferences[preference.name];
          if (rawPreference is! Map) continue;
          final target = _preferenceWeights[preference]!;
          for (final key in featureKeys) {
            final value = rawPreference[key];
            if (value is num) {
              target[key] = value.toDouble();
            }
          }
        }
      }
    } catch (error) {
      debugPrint('SmartNavigationAiModel load skipped -> $error');
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'bias': _bias,
        'sampleCount': _sampleCount,
        'weights': _weights,
        'preferences': <String, Map<String, double>>{
          for (final entry in _preferenceWeights.entries)
            entry.key.name: entry.value,
        },
      };
      await prefs.setString(storageKey, jsonEncode(payload));
    } catch (error) {
      debugPrint('SmartNavigationAiModel persist skipped -> $error');
    }
  }

  static Map<String, double> _copyWeights(Map<String, double> source) =>
      <String, double>{
        for (final entry in source.entries) entry.key: entry.value,
      };

  static double _clampDouble(
    double value, {
    required double min,
    required double max,
  }) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
