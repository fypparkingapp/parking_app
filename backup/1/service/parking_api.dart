import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model class for a carpark
class Carpark {
  final String id;
  final String nameEn;
  final String nameTc;
  final String nameSc;
  final String addressEn;
  final String addressTc;
  final double latitude;
  final double longitude;
  final int? vacancy;

  Carpark({
    required this.id,
    required this.nameEn,
    required this.nameTc,
    required this.nameSc,
    required this.addressEn,
    required this.addressTc,
    required this.latitude,
    required this.longitude,
    this.vacancy,
  });

  factory Carpark.fromGeoJSON(Map<String, dynamic> feature) {
    final props = feature['properties'];
    final coords = feature['geometry']['coordinates']; // [lon, lat]

    return Carpark(
      id: props['CARPARK_ID']?.toString() ?? '',
      nameEn: props['name_en'] ?? '',
      nameTc: props['name_tc'] ?? '',
      nameSc: props['name_sc'] ?? '',
      addressEn: props['displayAddress_en'] ?? '',
      addressTc: props['displayAddress_tc'] ?? '',
      latitude: coords[1],
      longitude: coords[0],
      vacancy: props['VACANCY'] is int
          ? props['VACANCY']
          : int.tryParse(props['VACANCY']?.toString() ?? ''),
    );
  }
}

/// Service to fetch carparks
class ParkingApi {
  static const String _endpoint =
      'https://portal.csdi.gov.hk/server/services/common/td_rcd_1638948197838_85279/MapServer/WFSServer?'
      'service=wfs&request=GetFeature&typenames=basic_info_all&outputFormat=geojson&'
      'srsName=EPSG:4326&filter=%3CFilter%3E%3CIntersects%3E%3CPropertyName%3ESHAPE%3C/PropertyName%3E'
      '%3Cgml:Envelope%20srsName=%27EPSG:4326%27%3E%3Cgml:lowerCorner%3E22.15%20113.81%3C/gml:lowerCorner%3E'
      '%3Cgml:upperCorner%3E22.62%20114.45%3C/gml:upperCorner%3E%3C/gml:Envelope%3E%3C/Intersects%3E%3C/Filter%3E';

  static Future<List<Carpark>> fetchCarparks() async {
    final response = await http.get(Uri.parse(_endpoint));

    if (response.statusCode == 200) {
      final geojson = json.decode(response.body);
      final List features = geojson['features'];

      return features.map((f) => Carpark.fromGeoJSON(f)).toList();
    } else {
      throw Exception('Failed to load carpark data: ${response.statusCode}');
    }
  }
}
