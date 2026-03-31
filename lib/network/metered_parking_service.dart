import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:csv/csv.dart';

enum MeteredOccupancy { vacant, occupied, unknown }

enum MeteredOperatingStatus { metering, free, noParking, unknown }

class MeteredSpace {
  final String parkingSpaceId;
  final String vehicleType;
  final String operatingPeriod;
  final String streetEn;
  final String streetTc;
  final String streetSc;
  final String sectionEn;
  final String sectionTc;
  final String sectionSc;
  final String districtEn;
  final String districtTc;
  final String districtSc;
  final double latitude;
  final double longitude;
  final MeteredOccupancy occupancy;

  const MeteredSpace({
    required this.parkingSpaceId,
    required this.vehicleType,
    required this.operatingPeriod,
    required this.streetEn,
    required this.streetTc,
    required this.streetSc,
    required this.sectionEn,
    required this.sectionTc,
    required this.sectionSc,
    required this.districtEn,
    required this.districtTc,
    required this.districtSc,
    required this.latitude,
    required this.longitude,
    required this.occupancy,
  });

  LatLng get point => LatLng(latitude, longitude);
}

class MeteredStreetGroup {
  final String key;
  final String vehicleType;
  final String operatingPeriod;
  final String streetEn;
  final String streetTc;
  final String streetSc;
  final String sectionEn;
  final String sectionTc;
  final String sectionSc;
  final String districtEn;
  final String districtTc;
  final String districtSc;
  final LatLng center;
  final List<MeteredSpace> spaces;

  const MeteredStreetGroup({
    required this.key,
    required this.vehicleType,
    required this.operatingPeriod,
    required this.streetEn,
    required this.streetTc,
    required this.streetSc,
    required this.sectionEn,
    required this.sectionTc,
    required this.sectionSc,
    required this.districtEn,
    required this.districtTc,
    required this.districtSc,
    required this.center,
    required this.spaces,
  });

  int get total => spaces.length;
  int get vacant =>
      spaces.where((s) => s.occupancy == MeteredOccupancy.vacant).length;
  bool get hasVacancy => vacant > 0;
}

MeteredOperatingStatus resolveOperatingStatus(
  String operatingPeriod,
  DateTime now,
) {
  bool isSunday = now.weekday == DateTime.sunday;
  // NOTE: Public holidays are treated as Sunday since we don't have a holiday calendar.
  bool isHoliday = isSunday;
  bool isSaturday = now.weekday == DateTime.saturday;
  bool isWeekday = now.weekday >= DateTime.monday &&
      now.weekday <= DateTime.friday;
  int minutes = now.hour * 60 + now.minute;

  bool inRange(int startMin, int endMin) {
    if (startMin <= endMin) {
      return minutes >= startMin && minutes < endMin;
    }
    return minutes >= startMin || minutes < endMin;
  }

  bool metering = false;
  bool noParking = false;
  switch (operatingPeriod) {
    case 'A':
      metering = !isHoliday && inRange(8 * 60, 24 * 60);
      break;
    case 'B':
      metering = !isHoliday && inRange(8 * 60, 20 * 60);
      break;
    case 'D':
      if (!isHoliday) {
        metering = inRange(8 * 60, 24 * 60);
      } else {
        metering = inRange(10 * 60, 22 * 60);
      }
      break;
    case 'E':
      metering = inRange(7 * 60, 20 * 60);
      break;
    case 'F':
      metering = inRange(8 * 60, 21 * 60);
      break;
    case 'H':
      metering = inRange(8 * 60, 20 * 60);
      break;
    case 'J':
      metering = inRange(8 * 60, 24 * 60);
      break;
    case 'N':
      metering = inRange(19 * 60, 24 * 60);
      break;
    case 'P':
      if (isHoliday) {
        noParking = true;
      } else {
        metering = inRange(8 * 60, 20 * 60);
      }
      break;
    case 'Q':
      if (!isHoliday) {
        metering = inRange(8 * 60, 20 * 60);
      } else {
        metering = inRange(10 * 60, 22 * 60);
      }
      break;
    case 'S':
      if (isWeekday) {
        noParking = inRange(8 * 60, 17 * 60);
        metering = inRange(17 * 60, 24 * 60);
      } else if (isSaturday) {
        metering = inRange(8 * 60, 24 * 60);
      } else {
        metering = inRange(10 * 60, 22 * 60);
      }
      break;
    default:
      return MeteredOperatingStatus.unknown;
  }

  if (noParking) return MeteredOperatingStatus.noParking;
  if (metering) return MeteredOperatingStatus.metering;
  return MeteredOperatingStatus.free;
}

class MeteredParkingService {
  MeteredParkingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _spacesUrl =
      'https://resource.data.one.gov.hk/td/psiparkingspaces/spaceinfo/parkingspaces.csv';
  static const String _occupancyUrl =
      'https://resource.data.one.gov.hk/td/psiparkingspaces/occupancystatus/occupancystatus.csv';

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36',
    'Referer': 'https://www.hkemobility.gov.hk/tc/route-search/pt',
    'Origin': 'https://www.hkemobility.gov.hk',
    'Accept': 'text/csv,*/*;q=0.8',
  };

  Future<List<MeteredStreetGroup>> fetchStreetGroups({
    Set<String>? vehicleTypes,
  }) async {
    final results = await Future.wait([
      _fetchCsv(_spacesUrl),
      _fetchCsv(_occupancyUrl),
    ]);

    final spaces = _parseSpaces(results[0]);
    if (spaces.isEmpty) return const [];
    final occupancy = _parseOccupancy(results[1]);

    final filtered = vehicleTypes == null || vehicleTypes.isEmpty
        ? spaces
        : spaces
            .where((s) => vehicleTypes.contains(s.vehicleType))
            .toList(growable: false);

    final withStatus = filtered
        .map((s) => MeteredSpace(
              parkingSpaceId: s.parkingSpaceId,
              vehicleType: s.vehicleType,
              operatingPeriod: s.operatingPeriod,
              streetEn: s.streetEn,
              streetTc: s.streetTc,
              streetSc: s.streetSc,
              sectionEn: s.sectionEn,
              sectionTc: s.sectionTc,
              sectionSc: s.sectionSc,
              districtEn: s.districtEn,
              districtTc: s.districtTc,
              districtSc: s.districtSc,
              latitude: s.latitude,
              longitude: s.longitude,
              occupancy: occupancy[s.parkingSpaceId] ?? MeteredOccupancy.unknown,
            ))
        .toList(growable: false);

    final grouped = <String, List<MeteredSpace>>{};
    for (final s in withStatus) {
      final key =
          '${s.vehicleType}|${s.operatingPeriod}|${s.districtEn}|${s.streetEn}|${s.sectionEn.isEmpty ? '-' : s.sectionEn}';
      grouped.putIfAbsent(key, () => []).add(s);
    }

    final groups = <MeteredStreetGroup>[];
    for (final entry in grouped.entries) {
      final list = entry.value;
      double lat = 0;
      double lon = 0;
      for (final s in list) {
        lat += s.latitude;
        lon += s.longitude;
      }
      lat /= list.length;
      lon /= list.length;
      final first = list.first;
      groups.add(
        MeteredStreetGroup(
          key: entry.key,
          vehicleType: first.vehicleType,
          operatingPeriod: first.operatingPeriod,
          streetEn: first.streetEn,
          streetTc: first.streetTc,
          streetSc: first.streetSc,
          sectionEn: first.sectionEn,
          sectionTc: first.sectionTc,
          sectionSc: first.sectionSc,
          districtEn: first.districtEn,
          districtTc: first.districtTc,
          districtSc: first.districtSc,
          center: LatLng(lat, lon),
          spaces: list,
        ),
      );
    }

    groups.sort((a, b) => b.vacant.compareTo(a.vacant));
    return groups;
  }

  Future<String> _fetchCsv(String url) async {
    final uri = Uri.parse(url);
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('CSV fetch failed ${res.statusCode}');
    }
    return utf8.decode(res.bodyBytes);
  }

  List<_MeteredSpaceRaw> _parseSpaces(String csvText) {
    final lines = const LineSplitter().convert(csvText);
    if (lines.length <= 2) return const [];
    final cleaned = lines.skip(2).join('\n');
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(cleaned);
    if (rows.isEmpty) return const [];

    final headers = rows.first
        .map((e) => e.toString().replaceAll('\ufeff', '').trim())
        .toList();

    final out = <_MeteredSpaceRaw>[];
    for (final row in rows.skip(1)) {
      if (row.isEmpty) continue;
      final map = <String, String>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i].toString();
      }
      final lat = double.tryParse(map['Latitude'] ?? '');
      final lon = double.tryParse(map['Longitude'] ?? '');
      final id = map['ParkingSpaceId'];
      final vehicleType = map['VehicleType'] ?? '';
      if (lat == null || lon == null || id == null || id.isEmpty) continue;
      out.add(
        _MeteredSpaceRaw(
          parkingSpaceId: id,
          vehicleType: vehicleType,
          operatingPeriod: map['OperatingPeriod'] ?? '',
          streetEn: map['Street'] ?? '',
          streetTc: map['Street_tc'] ?? '',
          streetSc: map['Street_sc'] ?? '',
          sectionEn: map['SectionOfStreet'] ?? '',
          sectionTc: map['SectionOfStreet_tc'] ?? '',
          sectionSc: map['SectionOfStreet_sc'] ?? '',
          districtEn: map['District'] ?? '',
          districtTc: map['District_tc'] ?? '',
          districtSc: map['District_sc'] ?? '',
          latitude: lat,
          longitude: lon,
        ),
      );
    }
    return out;
  }

  Map<String, MeteredOccupancy> _parseOccupancy(String csvText) {
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvText);
    if (rows.length <= 1) return const {};
    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final idIndex = headers.indexOf('ParkingSpaceId');
    final occIndex = headers.indexOf('OccupancyStatus');
    if (idIndex == -1 || occIndex == -1) return const {};
    final out = <String, MeteredOccupancy>{};
    for (final row in rows.skip(1)) {
      if (row.length <= occIndex) continue;
      final id = row[idIndex].toString();
      final status = row[occIndex].toString();
      out[id] = switch (status) {
        'V' => MeteredOccupancy.vacant,
        'O' => MeteredOccupancy.occupied,
        _ => MeteredOccupancy.unknown,
      };
    }
    return out;
  }
}

class _MeteredSpaceRaw {
  final String parkingSpaceId;
  final String vehicleType;
  final String operatingPeriod;
  final String streetEn;
  final String streetTc;
  final String streetSc;
  final String sectionEn;
  final String sectionTc;
  final String sectionSc;
  final String districtEn;
  final String districtTc;
  final String districtSc;
  final double latitude;
  final double longitude;

  const _MeteredSpaceRaw({
    required this.parkingSpaceId,
    required this.vehicleType,
    required this.operatingPeriod,
    required this.streetEn,
    required this.streetTc,
    required this.streetSc,
    required this.sectionEn,
    required this.sectionTc,
    required this.sectionSc,
    required this.districtEn,
    required this.districtTc,
    required this.districtSc,
    required this.latitude,
    required this.longitude,
  });
}
