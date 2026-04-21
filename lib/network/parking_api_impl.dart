part of 'parking_api.dart';

/// Model class for a carpark
class Carpark {
  final String _id;
  final String _nameEn;
  final String _nameTc;
  final String _nameSc;
  final String _addressEn;
  final String _addressTc;
  final String _addressSc;
  final double _latitude;
  final double _longitude;
  final String _operator;
  final VacancyInfo _vacancyInfo;
  final String? _photoUrl;
  final String? _openingStatus;
  final List<CarparkRate> _privateCarRates;

  Carpark({
    required String id,
    required String nameEn,
    required String nameTc,
    required String nameSc,
    required String addressEn,
    required String addressTc,
    required String addressSc,
    required double latitude,
    required double longitude,
    required String operatorName,
    String? photoUrl,
    String? openingStatus,
    List<CarparkRate>? privateCarRates,
    VacancyInfo? vacancyInfo,
    Map<String, Map<String, dynamic>>? vacancies,
  }) : _id = id,
       _nameEn = nameEn,
       _nameTc = nameTc,
       _nameSc = nameSc,
       _addressEn = addressEn,
       _addressTc = addressTc,
       _addressSc = addressSc,
       _latitude = latitude,
       _longitude = longitude,
       _operator = operatorName,
       _photoUrl = photoUrl,
       _openingStatus = openingStatus,
       _privateCarRates = privateCarRates ?? const [],
       _vacancyInfo = vacancyInfo ?? VacancyInfo.fromJson(vacancies ?? const {});

  // Getters
  String get id => _id;
  String get nameEn => _nameEn;
  String get nameTc => _nameTc;
  String get nameSc => _nameSc;
  String get addressEn => _addressEn;
  String get addressTc => _addressTc;
  String get addressSc => _addressSc;
  double get latitude => _latitude;
  double get longitude => _longitude;
  String get operatorName => _operator;
  VacancyInfo get vacancyInfo => _vacancyInfo;
  Map<String, Map<String, dynamic>> get vacancies => _vacancyInfo.toLegacyJson();
  String? get photoUrl => _photoUrl;
  String? get openingStatus => _openingStatus;
  List<CarparkRate> get privateCarRates => _privateCarRates;

  // Computed getter: Combine English and Chinese addresses
  String get fullAddress {
    final chinese = _addressTc.isNotEmpty ? _addressTc : _addressSc;
    if (_addressEn.isNotEmpty && chinese.isNotEmpty) {
      return '$_addressEn / $chinese';
    }
    if (_addressEn.isNotEmpty) return _addressEn;
    if (chinese.isNotEmpty) return chinese;
    return '';
  }

  int? get currentVacancy => _vacancyInfo.privateCarVacancy;

  // Backward compatibility: Return privateCar vacancy for existing code
  int? get vacancy => currentVacancy;

  factory Carpark.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    List<dynamic>? asList(dynamic value) {
      if (value is List) return value;
      if (value == null) return null;
      return [value];
    }

    final operatorName = json['operator']?.toString() ?? '';
    final normalizedOperator = operatorName.toLowerCase();
    final isLinkReit =
        normalizedOperator == 'linkreit' ||
        normalizedOperator.contains('linkreit');

    Map<String, dynamic>? govPrices = json['govPrices'] is Map<String, dynamic>
        ? json['govPrices'] as Map<String, dynamic>
        : null;
    final linkPrices = isLinkReit && json['linkPrices'] is Map<String, dynamic>
        ? json['linkPrices'] as Map<String, dynamic>
        : null;

    if (govPrices == null && json['privateCar'] is Map<String, dynamic>) {
      final privateCar = json['privateCar'] as Map<String, dynamic>;
      govPrices = {
        'privateCar': {
          'hourly': asList(privateCar['hourlyCharges'] ?? privateCar['hourly']),
          'dayNight': asList(
            privateCar['dayNightParks'] ?? privateCar['dayNight'],
          ),
          'monthly': asList(
            privateCar['monthlyCharges'] ?? privateCar['monthly'],
          ),
          'dayPass': asList(privateCar['dayPass']),
          'dayNightParks': asList(
            privateCar['dayNightParks'] ?? privateCar['dayNight'],
          ),
        },
      };
    }

    final namesByLang = _stringStringMap(json['namesByLang']);
    final addressesByLang = _stringStringMap(json['displayAddressesByLang']);

    List<CarparkRate> privateCarRates = [];
    if (isLinkReit) {
      privateCarRates = _parseLinkRates(linkPrices);
    }
    if (privateCarRates.isEmpty) {
      privateCarRates = _parseGovPrivateCarRates(govPrices);
    }
    if (privateCarRates.isEmpty) {
      privateCarRates = _parseWilsonRates(json['wilsonPlans']);
    }
    if (privateCarRates.isEmpty) {
      privateCarRates = _deriveRatesFromRemarks(json);
    }

    final structuredVacancy = () {
      final provided = json['vacancyInfo'];
      if (provided != null) return VacancyInfo.fromJson(provided);

      final legacy = json['vacancies'];
      if (legacy != null) return VacancyInfo.fromJson(legacy);

      final buckets = <VacancyBucket>[];
      if (isLinkReit && json['linkVacancy'] is num) {
        buckets.add(
          VacancyBucket(
            key: 'privateCar',
            vehicleTypeKey: 'privateCar',
            available: (json['linkVacancy'] as num).toInt(),
            categoryLabel: 'LinkREIT',
            lastUpdated: json['linkModifiedDate']?.toString(),
            source: VacancySource.linkReit,
          ),
        );
      }

      if (!isLinkReit) {
        buckets.addAll(_extractGovInfoVacancyBuckets(json));
      }

      return VacancyInfo.fromBuckets(buckets);
    }();

    final name = json['name']?.toString() ?? '';
    final displayAddress = json['displayAddress']?.toString() ?? '';
    final nameEn = _firstNonEmptyString([
      _firstFromLangMap(namesByLang, ['en_US', 'en']),
      json['linkNameEn'],
      json['govNameEn'],
      json['name_en'],
      json['nameEn'],
      json['park_Name_en'],
      name,
    ]);
    final nameTc = _firstNonEmptyString([
      _firstFromLangMap(namesByLang, ['zh_TW', 'zh_HK', 'tc', 'zh']),
      json['linkNameTc'],
      json['govNameTc'],
      json['name_tc'],
      json['nameTc'],
      json['park_Name_tc'],
      name,
    ]);
    final nameSc = _firstNonEmptyString([
      _firstFromLangMap(namesByLang, ['zh_CN', 'cn', 'zh']),
      json['linkNameSc'],
      json['govNameSc'],
      json['name_sc'],
      json['nameSc'],
      nameTc,
      json['park_Name_sc'],
      name,
    ]);

    final address = json['address']?.toString() ?? '';
    final addressEn = _firstNonEmptyString([
      _firstFromLangMap(addressesByLang, ['en_US', 'en']),
      json['linkAddressEn'],
      json['govAddressEn'],
      json['displayAddressEn'],
      displayAddress,
      json['address_en'],
      json['addressEn'],
      address,
    ]);
    final addressTc = _firstNonEmptyString([
      _firstFromLangMap(addressesByLang, ['zh_TW', 'zh_HK', 'tc', 'zh']),
      json['linkAddressTc'],
      json['govAddressTc'],
      json['displayAddressTc'],
      json['displayAddressZh'],
      json['displayAddress_tc'],
      json['address_tc'],
      json['address_sc'],
      json['addressTc'],
      displayAddress,
      address,
    ]);
    final addressSc = _firstNonEmptyString([
      _firstFromLangMap(addressesByLang, ['zh_CN', 'cn', 'zh']),
      json['linkAddressSc'],
      json['govAddressSc'],
      json['displayAddressSc'],
      json['displayAddress_sc'],
      json['address_sc'],
      addressTc,
      displayAddress,
      address,
    ]);

    final latitude =
        parseDouble(json['lat']) ?? parseDouble(json['latitude']) ?? 0.0;
    final longitude =
        parseDouble(json['lng']) ?? parseDouble(json['longitude']) ?? 0.0;

    String? photoUrl;
    if (json['image_url'] != null) {
      photoUrl = json['image_url']?.toString();
    } else if (json['photo'] != null) {
      photoUrl = json['photo']?.toString();
    } else if (json['photoUrl'] != null) {
      photoUrl = json['photoUrl']?.toString();
    } else if (json['renditionUrls'] is Map) {
      final renditions = json['renditionUrls'] as Map;
      photoUrl = _firstNonEmptyString([
        renditions['carpark_photo'],
        renditions['banner'],
        renditions['square'],
        renditions['thumbnail'],
      ]);
    }

    return Carpark(
      id: _firstNonEmptyString([
        json['sourceId'],
        json['park_Id'],
        json['park_id'],
        json['id'],
      ]),
      nameEn: nameEn,
      nameTc: nameTc,
      nameSc: nameSc,
      addressEn: addressEn,
      addressTc: addressTc,
      addressSc: addressSc,
      latitude: latitude,
      longitude: longitude,
      operatorName: operatorName,
      photoUrl: _normalizePhotoUrl(photoUrl),
      openingStatus: json['opening_status']?.toString(),
      privateCarRates: privateCarRates,
      vacancyInfo: structuredVacancy,
    );
  }

  static Map<String, String> _stringStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map(
        (key, value) =>
            MapEntry(key.toString(), value == null ? '' : value.toString()),
      );
    }
    return const {};
  }

  static String _firstFromLangMap(Map<String, String> map, List<String> keys) {
    for (final key in keys) {
      final variants = <String>{
        key,
        key.toLowerCase(),
        key.toUpperCase(),
        key.replaceAll('-', '_'),
        key.replaceAll('_', '-'),
      };
      for (final variant in variants) {
        final value = map[variant];
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return '';
  }

  static String _firstNonEmptyString(
    List<dynamic> values, {
    String fallback = '',
  }) {
    for (final value in values) {
      if (value == null) continue;
      final str = value.toString().trim();
      if (str.isNotEmpty) return str;
    }
    return fallback;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': _id,
      'nameEn': _nameEn,
      'nameTc': _nameTc,
      'nameSc': _nameSc,
      'addressEn': _addressEn,
      'addressTc': _addressTc,
      'addressSc': _addressSc,
      'latitude': _latitude,
      'longitude': _longitude,
      'operator': _operator,
      'photoUrl': _photoUrl,
      'openingStatus': _openingStatus,
      'vacancyInfo': _vacancyInfo.toJson(),
      'privateCarRates': _privateCarRates.map((rate) => rate.toJson()).toList(),
    };
  }

  factory Carpark.fromCacheJson(Map<String, dynamic> json) {
    final rates =
        (json['privateCarRates'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(CarparkRate.fromJson)
            .toList() ??
        const <CarparkRate>[];
    return Carpark(
      id: json['id']?.toString() ?? '',
      nameEn: json['nameEn']?.toString() ?? '',
      nameTc: json['nameTc']?.toString() ?? '',
      nameSc: json['nameSc']?.toString() ?? '',
      addressEn: json['addressEn']?.toString() ?? '',
      addressTc: json['addressTc']?.toString() ?? '',
      addressSc: json['addressSc']?.toString() ?? '',
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : 0,
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : 0,
      operatorName: json['operator']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString(),
      openingStatus: json['openingStatus']?.toString(),
      privateCarRates: rates,
      vacancyInfo: VacancyInfo.fromJson(
        json['vacancyInfo'] ?? json['vacancies'] ?? const {},
      ),
    );
  }
}

const Map<String, String> _govInfoVacancyFieldToVehicleType = {
  'privateCar': 'privateCar',
  'motorCycle': 'motorcycle',
  'motorcycle': 'motorcycle',
  'taxi': 'taxi',
  'LGV': 'lightGoodsVehicle',
  'HGV': 'heavyGoodsVehicle',
  'coach': 'coach',
};

VacancyBucket? _vacancyBucketFromTransport({
  required String key,
  required String vehicleTypeKey,
  required Map<String, dynamic> source,
  required VacancySource vacancySource,
  String? categoryLabel,
  String? fallbackLastUpdated,
}) {
  int? parseInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  final available = parseInt(source['available'] ?? source['space'] ?? source['vacancy']);
  final evAvailable = parseInt(source['evAvailable'] ?? source['spaceEV'] ?? source['vacancyEV']);
  final disabledAvailable = parseInt(
    source['disabledAvailable'] ?? source['spaceDIS'] ?? source['vacancyDIS'],
  );
  final unloadingAvailable = parseInt(
    source['unloadingAvailable'] ?? source['spaceUNL'] ?? source['vacancyUNL'],
  );

  if ([available, evAvailable, disabledAvailable, unloadingAvailable].every((v) => v == null)) {
    return null;
  }

  final normalizedKey = VacancyBucket.normalizeBucketKey(
    key,
    fallback: vehicleTypeKey,
  );
  return VacancyBucket(
    key: normalizedKey,
    vehicleTypeKey: VacancyBucket.normalizeVehicleTypeKey(vehicleTypeKey),
    available: available,
    evAvailable: evAvailable,
    disabledAvailable: disabledAvailable,
    unloadingAvailable: unloadingAvailable,
    categoryLabel: categoryLabel?.trim().isEmpty == true ? null : categoryLabel?.trim(),
    lastUpdated:
        source['lastUpdated']?.toString() ??
        source['lastupdate']?.toString() ??
        fallbackLastUpdated,
    source: vacancySource,
  );
}

VacancyInfo _vacancyInfoFromGovInfoRow(Map<String, dynamic> row) {
  return VacancyInfo.fromBuckets(_extractGovInfoVacancyBuckets(row));
}

List<VacancyBucket> _extractGovInfoVacancyBuckets(Map<String, dynamic> row) {
  final fallbackLastUpdated =
      row['modifiedDate']?.toString() ?? row['publishedDate']?.toString();
  final buckets = <VacancyBucket>[];
  for (final entry in _govInfoVacancyFieldToVehicleType.entries) {
    final source = row[entry.key];
    if (source is! Map<String, dynamic>) continue;
    final bucket = _vacancyBucketFromTransport(
      key: entry.value,
      vehicleTypeKey: entry.value,
      source: source,
      categoryLabel: source['vacancy_type']?.toString(),
      fallbackLastUpdated: fallbackLastUpdated,
      vacancySource: VacancySource.government,
    );
    if (bucket != null) buckets.add(bucket);
  }
  return buckets;
}

VacancyInfo _vacancyInfoFromGovFeedItem(Map<String, dynamic> item) {
  final vehicleTypes = item['vehicle_type'];
  if (vehicleTypes is! List) return VacancyInfo();

  final buckets = <VacancyBucket>[];
  for (final rawVehicle in vehicleTypes.whereType<Map>()) {
    final vehicleMap = Map<String, dynamic>.from(rawVehicle);
    final vehicleTypeKey = VacancyBucket.normalizeVehicleTypeKey(
      vehicleMap['type']?.toString() ?? '',
    );
    final categories = vehicleMap['service_category'];
    if (categories is! List) continue;

    final categoryMaps = categories
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
    if (categoryMaps.isEmpty) continue;

    for (var i = 0; i < categoryMaps.length; i++) {
      final category = categoryMaps[i];
      final categoryLabel = category['vacancy_type']?.toString();
      final bucketKey = _transportBucketKey(
        vehicleTypeKey: vehicleTypeKey,
        categoryLabel: categoryLabel,
        index: i,
        totalCategories: categoryMaps.length,
      );
      final bucket = _vacancyBucketFromTransport(
        key: bucketKey,
        vehicleTypeKey: vehicleTypeKey,
        source: category,
        categoryLabel: categoryLabel,
        fallbackLastUpdated: category['lastupdate']?.toString(),
        vacancySource: VacancySource.government,
      );
      if (bucket != null) buckets.add(bucket);
    }
  }

  return VacancyInfo.fromBuckets(buckets);
}

String _transportBucketKey({
  required String vehicleTypeKey,
  required String? categoryLabel,
  required int index,
  required int totalCategories,
}) {
  if (totalCategories <= 1) {
    return vehicleTypeKey;
  }
  final suffix = VacancyBucket.normalizeBucketKey(
    categoryLabel ?? 'category${index + 1}',
    fallback: 'category${index + 1}',
  );
  final suffixOnly = suffix.contains(':') ? suffix.split(':').last : suffix;
  return '$vehicleTypeKey:$suffixOnly';
}

List<CarparkRate> _parseGovPrivateCarRates(Map<String, dynamic>? govPrices) {
  if (govPrices == null) return const <CarparkRate>[];
  final privateCar = govPrices['privateCar'];
  if (privateCar is! Map<String, dynamic>) return const <CarparkRate>[];

  CarparkRate? pickBest(dynamic listValue, {String? fallbackType}) {
    if (listValue is! List || listValue.isEmpty) return null;
    Map<String, dynamic>? preferred;
    for (final item in listValue.whereType<Map<String, dynamic>>()) {
      if (item['price'] is num && (item['price'] as num) > 0) {
        preferred = item;
        break;
      }
      preferred ??= item;
    }
    if (preferred == null) return null;
    final map = Map<String, dynamic>.from(preferred);
    if (fallbackType != null) {
      final type = map['type']?.toString().trim();
      if (type == null || type.isEmpty) {
        map['type'] = fallbackType;
      }
    }
    // Remove noisy remarks from govPrices-derived rates.
    map.remove('remark');
    return CarparkRate.fromJson(map);
  }

  final rates = <CarparkRate>[];
  final hourly = pickBest(privateCar['hourly'], fallbackType: 'hourly');
  if (hourly != null) rates.add(hourly);
  final dayNight = pickBest(
    privateCar['dayNight'] ?? privateCar['dayNightParks'],
  );
  if (dayNight != null) rates.add(dayNight);
  final monthly = pickBest(privateCar['monthly'], fallbackType: 'monthly-park');
  if (monthly != null) rates.add(monthly);

  return rates;
}

List<CarparkRate> _parseLinkRates(Map<String, dynamic>? linkPrices) {
  if (linkPrices == null) return const <CarparkRate>[];

  const weekday = ['MON', 'TUE', 'WED', 'THU', 'FRI'];
  const weekend = ['SAT', 'SUN', 'PH'];

  final rates = <CarparkRate>[];
  void addRate(
    dynamic value,
    String type,
    List<String> days, {
    bool excludePublicHoliday = false,
    String? remark,
  }) {
    if (value is! num) return;
    rates.add(
      CarparkRate(
        weekdays: days,
        excludePublicHoliday: excludePublicHoliday,
        periodStart: null,
        periodEnd: null,
        price: value.toDouble(),
        covered: null,
        type: type,
        remark: remark,
        usageMinimum: null,
        reserved: null,
        validUntil: null,
      ),
    );
  }

  addRate(
    linkPrices['hourly_weekday'],
    'hourly',
    weekday,
    excludePublicHoliday: true,
  );
  addRate(linkPrices['hourly_weekend'], 'hourly', weekend);
  addRate(
    linkPrices['twelve_hour_weekday'],
    '12-hour',
    weekday,
    excludePublicHoliday: true,
  );
  addRate(linkPrices['twelve_hour_weekend'], '12-hour', weekend);
  addRate(
    linkPrices['twenty_four_hour_weekday'],
    '24-hour',
    weekday,
    excludePublicHoliday: true,
  );
  addRate(linkPrices['twenty_four_hour_weekend'], '24-hour', weekend);

  return _dedupeRates(rates);
}

List<CarparkRate> _parseWilsonRates(dynamic rawPlans) {
  if (rawPlans is! List) return const <CarparkRate>[];

  String? normalizeType(String serviceType, String unit) {
    final type = serviceType.toLowerCase();
    if (type.contains('hourly') || unit == 'per_hour') return 'hourly';
    if (type.contains('day park')) {
      return unit == 'day_pass' ? 'day-pass' : 'day-park';
    }
    if (type.contains('night park')) {
      return type.contains('monthly') ? 'night-park (monthly)' : 'night-park';
    }
    if (type.contains('monthly')) return 'monthly-park';
    if (type.contains('12 hours')) return '12-hour';
    if (type.contains('24 hours')) return '24-hour';
    return null;
  }

  bool excludePublicHoliday(String rule) {
    return RegExp(
      r'EXCL\.?\s*PH|EXCLUDING\s+PUBLIC\s+HOLIDAYS',
      caseSensitive: false,
    ).hasMatch(rule);
  }

  List<String> parseWeekdays(String rule) {
    final normalized = rule.toUpperCase();
    final days = <String>{};
    if (normalized.contains('MON-SAT')) {
      days.addAll(['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']);
    }
    if (normalized.contains('MON-FRI')) {
      days.addAll(['MON', 'TUE', 'WED', 'THU', 'FRI']);
    }
    if (normalized.contains('SUN')) days.add('SUN');
    if (normalized.contains('SAT')) days.add('SAT');
    if (normalized.contains('PH')) days.add('PH');

    const order = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN', 'PH'];
    return order.where(days.contains).toList();
  }

  String? parsePeriodStart(String? timeOfDay) {
    if (timeOfDay == null) return null;
    final parts = timeOfDay.split('-');
    if (parts.length < 2) return null;
    return parts.first.trim();
  }

  String? parsePeriodEnd(String? timeOfDay) {
    if (timeOfDay == null) return null;
    final parts = timeOfDay.split('-');
    if (parts.length < 2) return null;
    return parts.last.trim();
  }

  final rates = <CarparkRate>[];
  for (final plan in rawPlans.whereType<Map>()) {
    final carTypeId = plan['carTypeId'];
    final carTypeEn = plan['carTypeEn']?.toString().toLowerCase() ?? '';
    final carTypeZh = plan['carTypeZh']?.toString() ?? '';
    final supportsPrivateCar =
        (carTypeId is num && <int>{1, 3}.contains(carTypeId.toInt())) ||
        carTypeEn.contains('private car') ||
        carTypeZh.contains('私家車');
    if (!supportsPrivateCar) continue;
    if (plan['isEnable'] == false) continue;
    final amount = plan['amount'];
    if (amount is! num || amount <= 0) continue;

    final serviceType = plan['serviceTypeEn']?.toString() ?? '';
    final unit = plan['unit']?.toString() ?? '';
    final rule = plan['ruleEn']?.toString() ?? '';
    final timeOfDay = plan['timeOfDay']?.toString();
    final normalizedType = normalizeType(serviceType, unit);
    if (normalizedType == null) continue;

    rates.add(
      CarparkRate(
        weekdays: parseWeekdays(rule),
        excludePublicHoliday: excludePublicHoliday(rule),
        periodStart: parsePeriodStart(timeOfDay),
        periodEnd: parsePeriodEnd(timeOfDay),
        price: amount.toDouble(),
        covered: null,
        type: normalizedType,
        remark: null,
        usageMinimum: null,
        reserved: null,
        validUntil: null,
      ),
    );
  }

  return _dedupeRates(rates);
}

String? _normalizePhotoUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('/')) {
    return 'https://parkapi2.ryanpumpkin.com$url';
  }
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  if (uri.scheme == 'https' || uri.scheme == 'data') {
    return url;
  }
  if (uri.hasAuthority) {
    return uri.replace(scheme: 'https').toString();
  }
  return url;
}

class CarparkRate {
  final List<String> weekdays;
  final bool excludePublicHoliday;
  final String? periodStart;
  final String? periodEnd;
  final double? price;
  final String? covered;
  final String? type;
  final String? remark;
  final num? usageMinimum;
  final String? reserved;
  final String? validUntil;

  const CarparkRate({
    required this.weekdays,
    required this.excludePublicHoliday,
    this.periodStart,
    this.periodEnd,
    this.price,
    this.covered,
    this.type,
    this.remark,
    this.usageMinimum,
    this.reserved,
    this.validUntil,
  });

  factory CarparkRate.fromJson(Map<String, dynamic> json) {
    double? parsePrice(dynamic raw) {
      if (raw is num) return raw.toDouble();
      if (raw is String) {
        final cleaned = raw.replaceAll(',', '');
        final numericMatch = RegExp(
          r'([0-9]+(?:\.[0-9]+)?)',
        ).firstMatch(cleaned);
        if (numericMatch != null) {
          return double.tryParse(numericMatch.group(1)!);
        }
        return double.tryParse(cleaned);
      }
      return null;
    }

    final rawRemark =
        json['remark']?.toString() ?? json['description']?.toString();
    final rawPeriodStart = json['periodStart'] ?? json['from'];
    final rawPeriodEnd = json['periodEnd'] ?? json['to'];

    return CarparkRate(
      weekdays: (json['weekdays'] is List)
          ? (json['weekdays'] as List)
                .whereType<String>()
                .map((w) => w.toUpperCase())
                .toList()
          : const [],
      excludePublicHoliday:
          json['excludePublicHoliday'] == true ||
          json['excludePublicHolidays'] == true,
      periodStart: rawPeriodStart?.toString(),
      periodEnd: rawPeriodEnd?.toString(),
      price: parsePrice(json['price']) ?? _extractPriceFromText(rawRemark),
      covered: json['covered']?.toString(),
      type: json['type']?.toString(),
      remark: null,
      usageMinimum: () {
        final value = json['usageMinimum'];
        if (value is num) return value;
        if (value is String) return num.tryParse(value);
        return null;
      }(),
      reserved: json['reserved']?.toString(),
      validUntil:
          json['validUntil']?.toString() ??
          json['validUntilEnd']?.toString() ??
          json['validUntilStart']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weekdays': weekdays,
      'excludePublicHoliday': excludePublicHoliday,
      'periodStart': periodStart,
      'periodEnd': periodEnd,
      'price': price,
      'covered': covered,
      'type': type,
      'remark': remark,
      'usageMinimum': usageMinimum,
      'reserved': reserved,
      'validUntil': validUntil,
    };
  }

  static double? _extractPriceFromText(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = RegExp(
      r'(?:HK\$|\$)\s*([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(text.replaceAll(',', ''));
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }
}

List<CarparkRate> _deriveRatesFromRemarks(Map<String, dynamic> json) {
  return const <CarparkRate>[];
}

List<CarparkRate> _dedupeRates(List<CarparkRate> rates) {
  final result = <CarparkRate>[];
  final seen = <String>{};

  for (final rate in rates) {
    final weekdays = [...rate.weekdays]..sort();
    final key = [
      rate.type ?? '',
      rate.periodStart ?? '',
      rate.periodEnd ?? '',
      weekdays.join(','),
      rate.excludePublicHoliday ? '1' : '0',
      rate.price?.toStringAsFixed(2) ?? '',
      rate.covered ?? '',
      rate.reserved ?? '',
      rate.usageMinimum?.toString() ?? '',
    ].join('|');
    if (seen.add(key)) {
      result.add(rate);
    }
  }

  return result;
}

/// Service to fetch carparks
class ParkingApi {
  static const String _carparkApiUrl =
      'https://api.data.gov.hk/v1/carpark-info-vacancy';
  static const String _govVacancyApiUrl =
      'https://resource.data.one.gov.hk/td/carpark/vacancy_all.json';
  static const String _ryanCarparkApiUrl =
      'https://parkapi2.ryanpumpkin.com/carparks';
  static const Duration _cacheDuration = Duration(minutes: 10);
  static const String _prefsKeyData = 'parking_api.carparks.data';
  static const String _prefsKeyTimestamp = 'parking_api.carparks.timestamp';

  static List<Carpark>? _memoryCache;
  static DateTime? _memoryCacheTimestamp;
  static Future<List<Carpark>>? _pendingFetch;

  static Future<void> clearCache() async {
    _memoryCache = null;
    _memoryCacheTimestamp = null;
    _pendingFetch = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyData);
    await prefs.remove(_prefsKeyTimestamp);
  }

  static Future<List<Carpark>> fetchCarparks({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();

    if (!forceRefresh) {
      final cached = _memoryCache;
      final cachedAt = _memoryCacheTimestamp;
      if (cached != null &&
          cachedAt != null &&
          now.difference(cachedAt) <= _cacheDuration) {
        return cached;
      }
      final inflight = _pendingFetch;
      if (inflight != null) return inflight;
    }

    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final diskCache = _loadCache(prefs);
      if (diskCache != null &&
          now.difference(diskCache.timestamp) <= _cacheDuration) {
        _memoryCache = diskCache.data;
        _memoryCacheTimestamp = diskCache.timestamp;
        return diskCache.data;
      }
    }

    final fetch = _fetchAndPersist(prefs);
    if (!forceRefresh) {
      _pendingFetch = fetch;
    }

    try {
      final result = await fetch;
      final immutable = List<Carpark>.unmodifiable(result);
      _memoryCache = immutable;
      _memoryCacheTimestamp = DateTime.now();
      return immutable;
    } catch (e) {
      if (!forceRefresh) {
        final stale = _loadCache(prefs);
        if (stale != null) {
          _memoryCache = stale.data;
          _memoryCacheTimestamp = stale.timestamp;
          return stale.data;
        }
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error fetching carparks: $e');
    } finally {
      if (!forceRefresh) {
        _pendingFetch = null;
      }
    }
  }

  static Future<List<Carpark>> _fetchAndPersist(SharedPreferences prefs) async {
    final carparks = await _downloadCarparkData();
    try {
      await prefs.setString(
        _prefsKeyData,
        jsonEncode(carparks.map((c) => c.toJson()).toList()),
      );
      await prefs.setInt(
        _prefsKeyTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ParkingApi: failed to persist cache -> $e');
      }
    }
    return carparks;
  }

  static _CarparkCache? _loadCache(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKeyData);
    final ts = prefs.getInt(_prefsKeyTimestamp);
    if (raw == null || ts == null) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final carparks = decoded
          .whereType<Map<String, dynamic>>()
          .map(Carpark.fromCacheJson)
          .toList(growable: false);
      return _CarparkCache(
        List<Carpark>.unmodifiable(carparks),
        DateTime.fromMillisecondsSinceEpoch(ts),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ParkingApi: failed to read cache -> $e');
      }
      return null;
    }
  }

  static Future<List<Carpark>> _downloadCarparkData() async {
    final ryanMetadata = await _fetchRyanMetadata();
    final govVacancies = await _fetchGovVacancyMap();

    final response = await http.get(Uri.parse(_carparkApiUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load carpark data: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    List<dynamic>? rows;
    if (decoded is List) {
      rows = decoded;
    } else if (decoded is Map && decoded['results'] is List) {
      rows = decoded['results'] as List;
    }

    if (rows == null) {
      throw Exception('Unexpected carpark response structure');
    }

    final govRows = rows.whereType<Map<String, dynamic>>().toList(growable: false);
    return _mergeCarparkData(
      ryanMetadata: ryanMetadata,
      govRows: govRows,
      govVacancies: govVacancies,
    );
  }

  @visibleForTesting
  static VacancyInfo parseGovVacancyFeedEntryForTesting(Map<String, dynamic> item) {
    return _vacancyInfoFromGovFeedItem(item);
  }

  @visibleForTesting
  static List<Carpark> mergeCarparkDataForTesting({
    required Map<String, Map<String, dynamic>> ryanMetadata,
    required List<Map<String, dynamic>> govRows,
    required Map<String, VacancyInfo> govVacancies,
  }) {
    return _mergeCarparkData(
      ryanMetadata: ryanMetadata,
      govRows: govRows,
      govVacancies: govVacancies,
    );
  }

  static List<Carpark> _mergeCarparkData({
    required Map<String, Map<String, dynamic>> ryanMetadata,
    required List<Map<String, dynamic>> govRows,
    required Map<String, VacancyInfo> govVacancies,
  }) {
    String? resolveId(Map<String, dynamic> row) {
      return Carpark._firstNonEmptyString([
        row['sourceId'],
        row['park_Id'],
        row['park_id'],
        row['id'],
      ]);
    }

    final govById = <String, Map<String, dynamic>>{};
    for (final row in govRows) {
      final id = resolveId(row);
      if (id != null) {
        govById[id] = row;
      }
    }

    final carparks = <Carpark>[];

    for (final entry in ryanMetadata.entries) {
      final id = entry.key;
      final ryanRow = Map<String, dynamic>.from(entry.value);
      final govRow = govById[id];

      if (govRow != null) {
        final fallbackVacancy = _vacancyInfoFromGovInfoRow(govRow);
        final liveVacancy = govVacancies[id] ?? VacancyInfo();
        final mergedVacancy = liveVacancy.withFallback(fallbackVacancy);

        if (!mergedVacancy.isEmpty) {
          ryanRow['vacancyInfo'] = mergedVacancy;
        }
        ryanRow['opening_status'] ??= govRow['opening_status'];
        ryanRow['lat'] = ryanRow['lat'] ?? govRow['lat'] ?? govRow['latitude'];
        ryanRow['lng'] = ryanRow['lng'] ?? govRow['lng'] ?? govRow['longitude'];
        void overridePhoto(String key) {
          if (govRow.containsKey(key)) {
            ryanRow[key] = govRow[key];
          }
        }

        overridePhoto('renditionUrls');
        overridePhoto('photo');
        overridePhoto('photoUrl');
      }

      final feedVacancy = govVacancies[id];
      if (!ryanRow.containsKey('vacancyInfo') && feedVacancy != null && !feedVacancy.isEmpty) {
        ryanRow['vacancyInfo'] = feedVacancy;
      }

      final carpark = Carpark.fromJson(ryanRow);
      if (carpark.latitude != 0.0 && carpark.longitude != 0.0) {
        carparks.add(carpark);
      }
    }

    // Include any gov-only carparks not present in Ryan metadata as a fallback.
    for (final entry in govById.entries) {
      if (ryanMetadata.containsKey(entry.key)) continue;
      final merged = Map<String, dynamic>.from(entry.value);
      final fallbackVacancy = _vacancyInfoFromGovInfoRow(merged);
      final liveVacancy = govVacancies[entry.key] ?? VacancyInfo();
      final mergedVacancy = liveVacancy.withFallback(fallbackVacancy);
      if (!mergedVacancy.isEmpty) {
        merged['vacancyInfo'] = mergedVacancy;
      }
      final fallback = Carpark.fromJson(merged);
      if (fallback.latitude != 0.0 && fallback.longitude != 0.0) {
        carparks.add(fallback);
      }
    }

    if (kDebugMode) {
      debugPrint('ParkingApi: returning ${carparks.length} carparks');
    }
    return carparks;
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchRyanMetadata() async {
    try {
      final response = await http.get(Uri.parse(_ryanCarparkApiUrl));
      if (response.statusCode != 200) {
        return const {};
      }
      final decoded = jsonDecode(response.body);
      List<dynamic>? rows;
      if (decoded is List) {
        rows = decoded;
      } else if (decoded is Map && decoded['value'] is List) {
        rows = decoded['value'] as List;
      }
      if (rows == null) return const {};

      final map = <String, Map<String, dynamic>>{};
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final id = Carpark._firstNonEmptyString([
          row['sourceId'],
          row['park_Id'],
          row['park_id'],
          row['id'],
        ]);
        if (id.isEmpty) continue;
        map[id] = row;
      }
      return map;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ParkingApi: failed to fetch Ryan metadata -> $e');
      }
      return const {};
    }
  }

  static Future<Map<String, VacancyInfo>> _fetchGovVacancyMap() async {
    try {
      final response = await http.get(Uri.parse(_govVacancyApiUrl));
      if (response.statusCode != 200) return const <String, VacancyInfo>{};
      String body = response.body.trim();
      if (body.startsWith('?')) {
        body = body.substring(1);
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['car_park'] is! List) {
        return const <String, VacancyInfo>{};
      }

      final result = <String, VacancyInfo>{};
      for (final item in (decoded['car_park'] as List).whereType<Map>()) {
        final id = item['park_id']?.toString();
        if (id == null || id.isEmpty) continue;
        final vacancy = _vacancyInfoFromGovFeedItem(
          Map<String, dynamic>.from(item),
        );
        if (!vacancy.isEmpty) {
          result[id] = vacancy;
        }
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ParkingApi: failed to fetch gov vacancy -> $e');
      }
      return const {};
    }
  }
}

class _CarparkCache {
  const _CarparkCache(this.data, this.timestamp);

  final List<Carpark> data;
  final DateTime timestamp;
}
