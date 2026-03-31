// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_title => 'Parking App';

  @override
  String get parking_map_title => 'Parking Map';

  @override
  String get settings_title => 'Settings';

  @override
  String get map_settings_title => 'Map Settings';

  @override
  String get map_style => 'Map style';

  @override
  String get map_controls => 'Map Controls';

  @override
  String get normal => 'Normal';

  @override
  String get dark => 'Dark';

  @override
  String get bright => 'Bright';

  @override
  String get map_theme_default => 'Default';

  @override
  String get map_theme_night_drive => 'Night Drive';

  @override
  String get map_theme_clean_atlas => 'Clean Atlas';

  @override
  String get dark_mode => 'Dark mode';

  @override
  String get language => 'Language';

  @override
  String get language_english => 'English';

  @override
  String get language_traditional_chinese => 'Traditional Chinese';

  @override
  String get language_simplified_chinese => 'Simplified Chinese';

  @override
  String get vehicle_type => 'Vehicle type';

  @override
  String get vehicle_type_private_car => 'Private car';

  @override
  String get vehicle_type_motorcycle => 'Motorcycle';

  @override
  String get vehicle_type_taxi => 'Taxi';

  @override
  String get vacancy_type_private_car => 'Private car';

  @override
  String get vacancy_type_motorcycle => 'Motorcycle';

  @override
  String get vacancy_type_taxi => 'Taxi';

  @override
  String get back => 'Back';

  @override
  String get zoom_in => 'Zoom in';

  @override
  String get zoom_out => 'Zoom out';

  @override
  String get go_to_my_location => 'Go to my location';

  @override
  String get cluster_nearby_carparks => 'Cluster nearby car parks';

  @override
  String get reset_view => 'Reset view';

  @override
  String get clear_cached_parking_data => 'Clear cached parking data';

  @override
  String get clear_cached_parking_data_subtitle =>
      'Show loading and re-download';

  @override
  String get loading => 'Loading...';

  @override
  String get loading_carparks => 'Loading car parks...';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get close => 'Close';

  @override
  String get apply => 'Apply';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get route => 'Route';

  @override
  String get routing => 'Routing...';

  @override
  String get route_priorities => 'Route priorities';

  @override
  String get route_priorities_subtitle =>
      'Select one or more, and choose the primary priority.';

  @override
  String get set_primary => 'Set primary';

  @override
  String get route_again => 'Route again';

  @override
  String get tap_map_to_set_start_point => 'Tap the map to set a start point';

  @override
  String get tap_map_to_set_destination_point =>
      'Tap the map to set a destination';

  @override
  String get tap_map_to_place_start_marker =>
      'Tap the map to place a start marker';

  @override
  String get move_and_zoom_map_under_pin =>
      'Move and zoom the map under the pin';

  @override
  String get current_start_point => 'Current start point';

  @override
  String from_start_point_coords(Object coords) {
    return 'From: $coords';
  }

  @override
  String get from_current_location => 'From: current location';

  @override
  String get from_selected_start => 'From: selected start';

  @override
  String get choose_start_point => 'Choose start point';

  @override
  String get choose_destination => 'Choose destination';

  @override
  String get use_current_location => 'Use current location';

  @override
  String get pick_on_map => 'Pick on map';

  @override
  String get clear_selected_start => 'Clear selected start';

  @override
  String get avoid_toll_fees => 'Avoid toll fees';

  @override
  String get toll_fee_title => 'Toll fees';

  @override
  String get requesting_route => 'Requesting route...';

  @override
  String get routing_failed => 'Routing failed';

  @override
  String get no_routes_available => 'No routes available.';

  @override
  String get no_route_data_yet => 'No route data yet.';

  @override
  String get compare_routes => 'Compare routes';

  @override
  String get roads => 'Roads';

  @override
  String get more_roads_omitted => 'More roads omitted…';

  @override
  String get stop => 'Stop';

  @override
  String get start_navigation => 'Start Navigation';

  @override
  String get eta => 'ETA';

  @override
  String get distance => 'Distance';

  @override
  String get time => 'Time';

  @override
  String get toll_cost => 'Toll cost';

  @override
  String get toll_time => 'Toll time';

  @override
  String get toll_pricing_time => 'Toll pricing time';

  @override
  String get toll_time_mode_now => 'Now';

  @override
  String get toll_time_mode_depart_at => 'Depart at';

  @override
  String get toll_time_mode_arrive_by => 'Arrive by';

  @override
  String get use_current_time => 'Use current time';

  @override
  String get set_departure_time => 'Set departure time';

  @override
  String get set_arrival_time_estimated => 'Set arrival time (estimated)';

  @override
  String get pick_date_time => 'Pick date/time';

  @override
  String get change_date_time => 'Change date/time';

  @override
  String get reset => 'Reset';

  @override
  String get select => 'Select';

  @override
  String get toll_select_tunnel => 'Select tunnel';

  @override
  String toll_select_date(Object date) {
    return 'Select date  $date';
  }

  @override
  String toll_select_time(Object time) {
    return 'Select time  $time';
  }

  @override
  String get arrive_unknown => 'Arrive: --';

  @override
  String get toll_unknown => 'Toll: --';

  @override
  String get toll_amount_unknown => 'HK\$--';

  @override
  String get no_toll_fees => 'No toll fees';

  @override
  String get toll_chip_unknown => 'toll --';

  @override
  String get toll_chip_free => 'toll HK\$0';

  @override
  String get toll_short => 'toll';

  @override
  String get toll_free_route_may_avoid_major_roads =>
      'Toll-free route may avoid major roads.';

  @override
  String get toll_info_unavailable_showing_best_route =>
      'Toll info unavailable; showing best route.';

  @override
  String get no_toll_free_route_showing_lowest_toll_route =>
      'No toll-free route; showing lowest toll route.';

  @override
  String get coordinates => 'Coordinates';

  @override
  String get free_spaces => 'Free spaces';

  @override
  String get carpark_status_open => 'Open';

  @override
  String get carpark_status_closed => 'Closed';

  @override
  String get unknown_carpark => 'Unknown carpark';

  @override
  String get carpark => 'Carpark';

  @override
  String get nearby => 'Nearby';

  @override
  String get search_parking => 'Search carpark name or address';

  @override
  String get no_matching_car_parks => 'No matching car parks';

  @override
  String get no_matching_locations => 'No matching locations';

  @override
  String get no_recent_searches => 'No recent searches';

  @override
  String get favorites => 'Favorites';

  @override
  String get recent => 'Recent';

  @override
  String get search_results => 'Search results';

  @override
  String get saved_places => 'Saved places';

  @override
  String get add_place => 'Add place';

  @override
  String get save_place => 'Save place';

  @override
  String get place_name => 'Name';

  @override
  String get place_name_hint => 'Home, School';

  @override
  String get place_location => 'Location';

  @override
  String get place_location_hint => 'Search address or place';

  @override
  String get place_edit_name_hint => 'Edit the name for this place (optional).';

  @override
  String get place_missing_info => 'Please enter a name and location.';

  @override
  String get save => 'Save';

  @override
  String get na => 'N/A';

  @override
  String get price => 'Price';

  @override
  String get vacancies => 'Vacancies';

  @override
  String get updated => 'Updated';

  @override
  String get rates => 'Rates';

  @override
  String get navigate => 'Navigate';

  @override
  String get photo_unavailable => 'Photo unavailable';

  @override
  String get show_all => 'Show all';

  @override
  String get show_fewer => 'Show fewer';

  @override
  String get no_pricing_info =>
      'No pricing information available for this car park.';

  @override
  String get no_price_information => 'No price information';

  @override
  String get rate_type_hourly => 'Hourly';

  @override
  String get rate_type_12_hour_parking => '12-hour Parking';

  @override
  String get rate_type_24_hour_parking => '24-hour Parking';

  @override
  String get rate_type_monthly => 'Monthly';

  @override
  String get rate_type_night => 'Night Park';

  @override
  String get rate_type_day => 'Day Park';

  @override
  String get rate_type_day_and_night => 'Day & Night';

  @override
  String get rate_type_day_pass => 'Day Pass';

  @override
  String get excluding_public_holidays => 'Excluding public holidays';

  @override
  String get weekdays => 'Weekdays';

  @override
  String get weekdays_excluding_ph => 'Weekdays (excl. PH)';

  @override
  String get weekends => 'Weekends';

  @override
  String get weekends_and_ph => 'Weekends & PH';

  @override
  String get weekends_excluding_ph => 'Weekends (excl. PH)';

  @override
  String get excluding_public_holiday_suffix => '(excl. PH)';

  @override
  String get public_holiday => 'PH';

  @override
  String get weekday_mon_short => 'Mon';

  @override
  String get weekday_tue_short => 'Tue';

  @override
  String get weekday_wed_short => 'Wed';

  @override
  String get weekday_thu_short => 'Thu';

  @override
  String get weekday_fri_short => 'Fri';

  @override
  String get weekday_sat_short => 'Sat';

  @override
  String get weekday_sun_short => 'Sun';

  @override
  String get location_not_available => 'Location not available';

  @override
  String get location_permission_denied => 'Location permission denied';

  @override
  String get location_permission_permanently_denied =>
      'Location permission permanently denied';

  @override
  String get route_location_not_available =>
      'Location not available, cannot draw route';

  @override
  String get route_not_found => 'Route not found';

  @override
  String route_fetch_failed(Object error) {
    return 'Route fetch failed: $error';
  }

  @override
  String error_getting_location(Object error) {
    return 'Error getting location: $error';
  }

  @override
  String error_loading_carparks(Object error) {
    return 'Error loading carparks: $error';
  }

  @override
  String rate_from_price(Object price) {
    return 'From $price';
  }

  @override
  String vacancy_ev(Object count) {
    return 'EV $count';
  }

  @override
  String vacancy_disabled(Object count) {
    return 'Disabled $count';
  }

  @override
  String rate_minimum_hours(Object hours) {
    return 'Min $hours hr';
  }

  @override
  String rate_valid_until(Object date) {
    return 'Until $date';
  }

  @override
  String route_number(Object number) {
    return 'Route $number';
  }

  @override
  String get metered_parking => 'Metered';

  @override
  String get metered_parking_title => 'Metered Parking';

  @override
  String get loading_metered_parking => 'Loading metered parking...';

  @override
  String get metered_no_data => 'No metered parking data available.';

  @override
  String get metered_vacant => 'Available';

  @override
  String get metered_occupied => 'Occupied';

  @override
  String get metered_unknown => 'Unknown';

  @override
  String metered_spaces_count(Object vacant, Object total) {
    return '$vacant vacant / $total total';
  }

  @override
  String get metered_vehicle_filter => 'Vehicle types';

  @override
  String get metered_vehicle_light_goods => 'Light goods vehicle';

  @override
  String get metered_vehicle_heavy_goods => 'Heavy goods vehicle';

  @override
  String get metered_vehicle_coach => 'Coach';

  @override
  String get metered_vehicle_special => 'Special purpose vehicle';

  @override
  String get metered_status_free_now => 'Free now';

  @override
  String get metered_status_metering_now => 'Metering now';

  @override
  String get metered_status_no_parking_now => 'No parking now';

  @override
  String get metered_status_unknown => 'Hours unknown';

  @override
  String tdas_eta(Object eta, Object speed) {
    return 'TDAS ETA: $eta / $speed';
  }

  @override
  String duration_hours_minutes(Object hours, Object minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String duration_minutes(Object minutes) {
    return '${minutes}m';
  }

  @override
  String distance_km(Object km) {
    return '$km km';
  }

  @override
  String distance_m(Object m) {
    return '$m m';
  }

  @override
  String arrive_at(Object time) {
    return 'Arrive: $time';
  }

  @override
  String depart_and_arrive(Object depart, Object arrive) {
    return 'Depart: $depart · Arrive: $arrive';
  }

  @override
  String arrive_and_est_depart(Object arrive, Object depart) {
    return 'Arrive: $arrive · Est. depart: $depart';
  }

  @override
  String est_toll(Object amount) {
    return 'Est. toll: $amount';
  }
}
