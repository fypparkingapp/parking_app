/// Centralized API endpoint configuration.
///
/// Self-hosted services run under *.ryanpumpkin.com. Change here when
/// re-deploying to a different host.
class ApiConfig {
  ApiConfig._();

  // Self-hosted services
  static const String osrmBaseUrl = 'https://osrm.ryanpumpkin.com';
  static const String parkApiBaseUrl = 'https://parkapi2.ryanpumpkin.com';
  static const String vacancyApiBaseUrl = 'https://vacancyapi.ryanpumpkin.com';

  // Hong Kong government open data APIs
  static const String hkGovCarparkInfoVacancyUrl =
      'https://api.data.gov.hk/v1/carpark-info-vacancy';
  static const String hkGovVacancyAllUrl =
      'https://resource.data.one.gov.hk/td/carpark/vacancy_all.json';
  static const String hkGovMeterSpaceInfoUrl =
      'https://resource.data.one.gov.hk/td/psiparkingspaces/spaceinfo/parkingspaces.csv';
  static const String hkGovMeterOccupancyUrl =
      'https://resource.data.one.gov.hk/td/psiparkingspaces/occupancystatus/occupancystatus.csv';

  // map.gov.hk (location search / geocoding)
  static const String mapGovBase = 'https://www.map.gov.hk';
  static const String mapGovLocationSearchUrl =
      '$mapGovBase/gs/api/v1.0.0/locationSearch';
  static const String mapGovReferer = '$mapGovBase/gm/';

  // hkemobility (speed map, toll, headers)
  static const String hkemobilityHost = 'www.hkemobility.gov.hk';
  static const String hkemobilityBase = 'https://$hkemobilityHost';
  static const String hkemobilitySpeedMapUrl =
      '$hkemobilityBase/api/drss/layer/map?';
  static const String hkemobilityRouteReferer =
      '$hkemobilityBase/tc/route-search/pt';
  static const String hkemobilityTollReferer =
      '$hkemobilityBase/en/toll-rate/';
  static const String tdasApiBaseUrl = 'https://tdas-api.hkemobility.gov.hk';

  // Map tile providers (Carto basemaps)
  static const String cartoVoyagerTileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const String cartoDarkTileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const String cartoLightTileUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
}
