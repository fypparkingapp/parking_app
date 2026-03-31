import 'package:parking_app/network/geocoding_service.dart';

class SavedPlace {
  const SavedPlace({
    required this.label,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.carparkId,
  });

  final String label;
  final String displayName;
  final double latitude;
  final double longitude;
  final String? carparkId;

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      label: json['label']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : 0.0,
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : 0.0,
      carparkId: (json['carparkId']?.toString().trim().isNotEmpty ?? false)
          ? json['carparkId'].toString()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'displayName': displayName,
      'latitude': latitude,
      'longitude': longitude,
      if (carparkId != null && carparkId!.isNotEmpty) 'carparkId': carparkId,
    };
  }

  GeocodingResult toGeocodingResult() {
    return GeocodingResult(
      displayName: displayName.isNotEmpty ? displayName : label,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
