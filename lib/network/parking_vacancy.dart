part of 'parking_api.dart';

enum VacancySource {
  government('government'),
  linkReit('link_reit'),
  metered('metered'),
  unknown('unknown');

  const VacancySource(this.storageValue);

  final String storageValue;

  static VacancySource fromRaw(
    Object? raw, {
    String? fallbackLabel,
  }) {
    final value = raw?.toString().trim().toLowerCase();
    if (value != null && value.isNotEmpty) {
      switch (value) {
        case 'government':
        case 'gov':
          return VacancySource.government;
        case 'link_reit':
        case 'linkreit':
        case 'link':
          return VacancySource.linkReit;
        case 'metered':
          return VacancySource.metered;
      }
    }

    final label = fallbackLabel?.trim().toLowerCase();
    if (label == 'linkreit') return VacancySource.linkReit;
    if (label == 'metered') return VacancySource.metered;
    if (label == 'gov' || label == 'government') {
      return VacancySource.government;
    }
    return VacancySource.unknown;
  }
}

class VacancyBucket {
  const VacancyBucket({
    required this.key,
    required this.vehicleTypeKey,
    this.available,
    this.evAvailable,
    this.disabledAvailable,
    this.unloadingAvailable,
    this.categoryLabel,
    this.lastUpdated,
    this.source = VacancySource.unknown,
  });

  final String key;
  final String vehicleTypeKey;
  final int? available;
  final int? evAvailable;
  final int? disabledAvailable;
  final int? unloadingAvailable;
  final String? categoryLabel;
  final String? lastUpdated;
  final VacancySource source;

  bool get hasData =>
      available != null ||
      evAvailable != null ||
      disabledAvailable != null ||
      unloadingAvailable != null;

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'vehicleTypeKey': vehicleTypeKey,
      'available': available,
      'evAvailable': evAvailable,
      'disabledAvailable': disabledAvailable,
      'unloadingAvailable': unloadingAvailable,
      'categoryLabel': categoryLabel,
      'lastUpdated': lastUpdated,
      'source': source.storageValue,
    };
  }

  Map<String, dynamic> toLegacyJson() {
    return {
      if (available != null) 'vacancy': available,
      if (evAvailable != null) 'vacancyEV': evAvailable,
      if (disabledAvailable != null) 'vacancyDIS': disabledAvailable,
      if (unloadingAvailable != null) 'vacancyUNL': unloadingAvailable,
      'vacancy_type': categoryLabel ?? '',
      'lastupdate': lastUpdated ?? '',
    };
  }

  factory VacancyBucket.fromJson(
    String fallbackKey,
    Map<String, dynamic> json,
  ) {
    int? parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final key = normalizeBucketKey(
      json['key']?.toString() ?? fallbackKey,
      fallback: fallbackKey,
    );
    final vehicleTypeKey = normalizeVehicleTypeKey(
      json['vehicleTypeKey']?.toString() ?? key,
    );
    final categoryLabel =
        json['categoryLabel']?.toString() ?? json['vacancy_type']?.toString();

    return VacancyBucket(
      key: key,
      vehicleTypeKey: vehicleTypeKey,
      available: parseInt(json['available'] ?? json['vacancy'] ?? json['space']),
      evAvailable: parseInt(json['evAvailable'] ?? json['vacancyEV'] ?? json['spaceEV']),
      disabledAvailable: parseInt(
        json['disabledAvailable'] ?? json['vacancyDIS'] ?? json['spaceDIS'],
      ),
      unloadingAvailable: parseInt(
        json['unloadingAvailable'] ?? json['vacancyUNL'] ?? json['spaceUNL'],
      ),
      categoryLabel: categoryLabel == null || categoryLabel.trim().isEmpty
          ? null
          : categoryLabel.trim(),
      lastUpdated:
          json['lastUpdated']?.toString() ?? json['lastupdate']?.toString(),
      source: VacancySource.fromRaw(
        json['source'],
        fallbackLabel: categoryLabel,
      ),
    );
  }

  static String normalizeBucketKey(String raw, {String fallback = 'unknown'}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;
    final segments = trimmed.split(':');
    final vehicleType = normalizeVehicleTypeKey(segments.first);
    if (segments.length == 1) return vehicleType;
    final suffix = _normalizeKeySegment(segments.skip(1).join(':'));
    return suffix.isEmpty ? vehicleType : '$vehicleType:$suffix';
  }

  static String normalizeVehicleTypeKey(String raw) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'p':
      case 'pc':
      case 'privatecar':
      case 'private_car':
      case 'private car':
      case 'privatecars':
      case 'private cars':
        return 'privateCar';
      case 'm':
      case 'mc':
      case 'motor':
      case 'motorcycle':
      case 'motorcyclecar':
      case 'motor_cycle':
      case 'motor cycle':
      case 'motorcyclecars':
      case 'motorcycles':
        return 'motorcycle';
      case 't':
      case 'taxi':
        return 'taxi';
      case 'lgv':
      case 'l':
      case 'lightgoodsvehicle':
      case 'light_goods_vehicle':
      case 'light goods vehicle':
      case 'lightgoods':
      case 'light_goods':
        return 'lightGoodsVehicle';
      case 'hgv':
      case 'h':
      case 'heavygoodsvehicle':
      case 'heavy_goods_vehicle':
      case 'heavy goods vehicle':
      case 'heavygoods':
      case 'heavy_goods':
        return 'heavyGoodsVehicle';
      case 'goodsvehicle':
      case 'goods_vehicle':
      case 'goods vehicle':
      case 'goods':
      case 'g':
        return 'goodsVehicle';
      case 'coach':
      case 'bus':
      case 'b':
        return 'coach';
      default:
        return _normalizeKeySegment(raw, preserveCamelCase: true);
    }
  }

  static String _normalizeKeySegment(
    String raw, {
    bool preserveCamelCase = false,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final cleaned = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ');
    final parts = cleaned
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '';
    if (!preserveCamelCase) {
      return parts.map((part) => part.toLowerCase()).join('_');
    }
    final first = parts.first.toLowerCase();
    final rest = parts
        .skip(1)
        .map(
          (part) =>
              part.substring(0, 1).toUpperCase() + part.substring(1).toLowerCase(),
        )
        .join();
    return '$first$rest';
  }
}

class VacancyInfo {
  VacancyInfo({Map<String, VacancyBucket>? buckets})
    : _buckets = Map.unmodifiable(buckets ?? const <String, VacancyBucket>{});

  final Map<String, VacancyBucket> _buckets;

  bool get isEmpty => _buckets.isEmpty;
  Map<String, VacancyBucket> get buckets => _buckets;
  Iterable<MapEntry<String, VacancyBucket>> get entries => _buckets.entries;
  Iterable<VacancyBucket> get values => _buckets.values;

  VacancyBucket? operator [](String key) {
    return _buckets[VacancyBucket.normalizeBucketKey(key, fallback: key)];
  }

  VacancyBucket? get primaryBucket =>
      firstBucketForVehicle('privateCar') ??
      (_buckets.isNotEmpty ? _buckets.values.first : null);

  int? get privateCarVacancy => totalVacancyForVehicle('privateCar');

  int? totalVacancyForVehicle(String vehicleTypeKey) {
    final matches = bucketsForVehicle(vehicleTypeKey).toList(growable: false);
    if (matches.isEmpty) return null;
    final counts = matches
        .map((bucket) => bucket.available)
        .whereType<int>()
        .toList(growable: false);
    if (counts.isEmpty) return null;
    return counts.fold<int>(0, (sum, value) => sum + value);
  }

  VacancyBucket? firstBucketForVehicle(String vehicleTypeKey) {
    final normalized = VacancyBucket.normalizeVehicleTypeKey(vehicleTypeKey);
    for (final bucket in _buckets.values) {
      if (bucket.vehicleTypeKey == normalized) return bucket;
    }
    return null;
  }

  Iterable<VacancyBucket> bucketsForVehicle(String vehicleTypeKey) sync* {
    final normalized = VacancyBucket.normalizeVehicleTypeKey(vehicleTypeKey);
    for (final bucket in _buckets.values) {
      if (bucket.vehicleTypeKey == normalized) yield bucket;
    }
  }

  VacancyInfo withFallback(VacancyInfo fallback) {
    if (fallback.isEmpty) return this;
    if (isEmpty) return fallback;

    final merged = <String, VacancyBucket>{..._buckets};
    final coveredVehicleTypes = _buckets.values
        .map((bucket) => bucket.vehicleTypeKey)
        .toSet();

    for (final entry in fallback.entries) {
      if (coveredVehicleTypes.contains(entry.value.vehicleTypeKey)) continue;
      merged.putIfAbsent(entry.key, () => entry.value);
    }
    return VacancyInfo(buckets: merged);
  }

  Map<String, dynamic> toJson() {
    return {
      'buckets': _buckets.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  Map<String, Map<String, dynamic>> toLegacyJson() {
    return _buckets.map(
      (key, value) => MapEntry(key, value.toLegacyJson()),
    );
  }

  static VacancyInfo fromJson(dynamic raw) {
    if (raw is VacancyInfo) return raw;

    if (raw is Map<String, dynamic>) {
      final bucketSource = raw['buckets'];
      final directSource = bucketSource is Map<String, dynamic> ? bucketSource : raw;
      final buckets = <String, VacancyBucket>{};
      for (final entry in directSource.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final bucket = VacancyBucket.fromJson(
          entry.key,
          Map<String, dynamic>.from(value),
        );
        if (!bucket.hasData) continue;
        buckets[bucket.key] = bucket;
      }
      return VacancyInfo(buckets: buckets);
    }

    if (raw is Map) {
      return fromJson(raw.map((key, value) => MapEntry('$key', value)));
    }

    return VacancyInfo();
  }

  static VacancyInfo fromBuckets(Iterable<VacancyBucket> buckets) {
    final map = <String, VacancyBucket>{};
    for (final bucket in buckets) {
      if (!bucket.hasData) continue;
      map[bucket.key] = bucket;
    }
    return VacancyInfo(buckets: map);
  }
}
