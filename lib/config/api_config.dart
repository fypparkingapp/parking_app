/// Centralized API endpoint configuration.
///
/// Self-hosted services run under *.ryanpumpkin.com. Change here when
/// re-deploying to a different host.
class ApiConfig {
  ApiConfig._();

  // Self-hosted services — toggle between production and local Docker deploy.
  /// Set to `true` to point self-hosted services at local Docker (see
  /// https://github.com/fypparkingapp/parking_app_backend). Keep `false` for
  /// production builds so the deployed *.ryanpumpkin.com endpoints are used.
  static const bool useLocalBackends = false;

  static const String osrmBaseUrl =
      useLocalBackends ? 'http://localhost:8082' : 'https://osrm.ryanpumpkin.com';
  static const String parkApiBaseUrl = useLocalBackends
      ? 'http://localhost:8000'
      : 'https://parkapi2.ryanpumpkin.com';
  static const String vacancyApiBaseUrl = useLocalBackends
      ? 'http://localhost:8081'
      : 'https://vacancyapi.ryanpumpkin.com';

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
