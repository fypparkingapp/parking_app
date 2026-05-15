import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parking_app/config/api_config.dart';
import 'package:parking_app/network/metered_parking_service.dart';
import 'package:parking_app/network/parking_api.dart';

/// Result from the vacancy prediction API.
class VacancyPrediction {
  final String parkId;
  final int currentVacancy;
  final int predictedVacancy;
  final int horizonMinutes;
  final String confidence; // "ok" | "low_history" | "stale"

  const VacancyPrediction({
    required this.parkId,
    required this.currentVacancy,
    required this.predictedVacancy,
    required this.horizonMinutes,
    required this.confidence,
  });

  factory VacancyPrediction.fromJson(Map<String, dynamic> json) {
    return VacancyPrediction(
      parkId: json['park_id'] as String,
      currentVacancy: (json['current_vacancy'] as num).toInt(),
      predictedVacancy: (json['predicted_vacancy'] as num).toInt(),
      horizonMinutes: (json['horizon_minutes'] as num).toInt(),
      confidence: json['confidence'] as String? ?? 'ok',
    );
  }

  bool get isReliable => confidence == 'ok';
}

class VacancyForecast {
  const VacancyForecast({
    required this.parkId,
    required this.currentVacancy,
    required this.predictedVacancy,
    required this.horizonMinutes,
    required this.confidence,
    this.currentBucket,
  });

  final String parkId;
  final int currentVacancy;
  final int predictedVacancy;
  final int horizonMinutes;
  final String confidence;
  final VacancyBucket? currentBucket;

  int get delta => predictedVacancy - currentVacancy;
  bool get isReliable => confidence == 'ok';

  factory VacancyForecast.fromPrediction({
    required Carpark carpark,
    required VacancyPrediction prediction,
  }) {
    final currentBucket = carpark.vacancyInfo.primaryBucket;
    return VacancyForecast(
      parkId: prediction.parkId,
      currentVacancy: carpark.currentVacancy ?? prediction.currentVacancy,
      predictedVacancy: prediction.predictedVacancy,
      horizonMinutes: prediction.horizonMinutes,
      confidence: prediction.confidence,
      currentBucket: currentBucket,
    );
  }
}

class MeterVacancyPrediction {
  const MeterVacancyPrediction({
    required this.groupKey,
    required this.currentVacancy,
    required this.predictedVacancy,
    required this.totalSpaces,
    required this.horizonMinutes,
    required this.confidence,
  });

  final String groupKey;
  final int currentVacancy;
  final int predictedVacancy;
  final int totalSpaces;
  final int horizonMinutes;
  final String confidence;

  factory MeterVacancyPrediction.fromJson(Map<String, dynamic> json) {
    return MeterVacancyPrediction(
      groupKey: json['group_key'] as String,
      currentVacancy: (json['current_vacancy'] as num).toInt(),
      predictedVacancy: (json['predicted_vacancy'] as num).toInt(),
      totalSpaces: (json['total_spaces'] as num?)?.toInt() ?? 0,
      horizonMinutes: (json['horizon_minutes'] as num).toInt(),
      confidence: json['confidence'] as String? ?? 'ok',
    );
  }

  bool get isReliable => confidence == 'ok';
}

class MeterVacancyForecast {
  const MeterVacancyForecast({
    required this.groupKey,
    required this.currentVacancy,
    required this.predictedVacancy,
    required this.totalSpaces,
    required this.horizonMinutes,
    required this.confidence,
  });

  final String groupKey;
  final int currentVacancy;
  final int predictedVacancy;
  final int totalSpaces;
  final int horizonMinutes;
  final String confidence;

  int get delta => predictedVacancy - currentVacancy;
  bool get isReliable => confidence == 'ok';

  factory MeterVacancyForecast.fromPrediction({
    required MeteredStreetGroup group,
    required MeterVacancyPrediction prediction,
  }) {
    return MeterVacancyForecast(
      groupKey: prediction.groupKey,
      currentVacancy: group.vacant,
      predictedVacancy: prediction.predictedVacancy,
      totalSpaces: prediction.totalSpaces > 0
          ? prediction.totalSpaces
          : group.total,
      horizonMinutes: prediction.horizonMinutes,
      confidence: prediction.confidence,
    );
  }
}

class VacancyPredictionService {
  static const String _baseUrl = ApiConfig.vacancyApiBaseUrl;

  static final VacancyPredictionService _instance =
      VacancyPredictionService._();
  factory VacancyPredictionService() => _instance;
  VacancyPredictionService._();

  /// Fetches the ~1-hour-ahead vacancy prediction for [parkId].
  /// Returns null if the park is unknown to the model or the service is down.
  Future<VacancyPrediction?> predict(String parkId) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/predict',
    ).replace(queryParameters: {'park_id': parkId});
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return VacancyPrediction.fromJson(json);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<VacancyForecast?> forecast(Carpark carpark) async {
    final prediction = await predict(carpark.id);
    if (prediction == null) return null;
    return VacancyForecast.fromPrediction(
      carpark: carpark,
      prediction: prediction,
    );
  }

  Future<MeterVacancyPrediction?> predictMeter(String groupKey) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/predict-meter',
    ).replace(queryParameters: {'group_key': groupKey});
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return MeterVacancyPrediction.fromJson(json);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<MeterVacancyForecast?> forecastMeter(MeteredStreetGroup group) async {
    final prediction = await predictMeter(group.key);
    if (prediction == null) return null;
    return MeterVacancyForecast.fromPrediction(
      group: group,
      prediction: prediction,
    );
  }
}
