import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'CN'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @app_title.
  ///
  /// In en, this message translates to:
  /// **'Parking App'**
  String get app_title;

  /// No description provided for @parking_map_title.
  ///
  /// In en, this message translates to:
  /// **'Parking Map'**
  String get parking_map_title;

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// No description provided for @map_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Map Settings'**
  String get map_settings_title;

  /// No description provided for @map_style.
  ///
  /// In en, this message translates to:
  /// **'Map style'**
  String get map_style;

  /// No description provided for @map_controls.
  ///
  /// In en, this message translates to:
  /// **'Map Controls'**
  String get map_controls;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @bright.
  ///
  /// In en, this message translates to:
  /// **'Bright'**
  String get bright;

  /// No description provided for @map_theme_default.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get map_theme_default;

  /// No description provided for @map_theme_night_drive.
  ///
  /// In en, this message translates to:
  /// **'Night Drive'**
  String get map_theme_night_drive;

  /// No description provided for @map_theme_clean_atlas.
  ///
  /// In en, this message translates to:
  /// **'Clean Atlas'**
  String get map_theme_clean_atlas;

  /// No description provided for @dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get dark_mode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @language_english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get language_english;

  /// No description provided for @language_traditional_chinese.
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get language_traditional_chinese;

  /// No description provided for @language_simplified_chinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get language_simplified_chinese;

  /// No description provided for @vehicle_type.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get vehicle_type;

  /// No description provided for @vehicle_type_private_car.
  ///
  /// In en, this message translates to:
  /// **'Private car'**
  String get vehicle_type_private_car;

  /// No description provided for @vehicle_type_motorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get vehicle_type_motorcycle;

  /// No description provided for @vehicle_type_taxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get vehicle_type_taxi;

  /// No description provided for @vacancy_type_private_car.
  ///
  /// In en, this message translates to:
  /// **'Private car'**
  String get vacancy_type_private_car;

  /// No description provided for @vacancy_type_motorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get vacancy_type_motorcycle;

  /// No description provided for @vacancy_type_taxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get vacancy_type_taxi;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @zoom_in.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoom_in;

  /// No description provided for @zoom_out.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoom_out;

  /// No description provided for @go_to_my_location.
  ///
  /// In en, this message translates to:
  /// **'Go to my location'**
  String get go_to_my_location;

  /// No description provided for @cluster_nearby_carparks.
  ///
  /// In en, this message translates to:
  /// **'Cluster nearby car parks'**
  String get cluster_nearby_carparks;

  /// No description provided for @reset_view.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get reset_view;

  /// No description provided for @clear_cached_parking_data.
  ///
  /// In en, this message translates to:
  /// **'Clear cached parking data'**
  String get clear_cached_parking_data;

  /// No description provided for @clear_cached_parking_data_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Show loading and re-download'**
  String get clear_cached_parking_data_subtitle;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @loading_carparks.
  ///
  /// In en, this message translates to:
  /// **'Loading car parks...'**
  String get loading_carparks;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @routing.
  ///
  /// In en, this message translates to:
  /// **'Routing...'**
  String get routing;

  /// No description provided for @route_priorities.
  ///
  /// In en, this message translates to:
  /// **'Route priorities'**
  String get route_priorities;

  /// No description provided for @route_priorities_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select one or more, and choose the primary priority.'**
  String get route_priorities_subtitle;

  /// No description provided for @set_primary.
  ///
  /// In en, this message translates to:
  /// **'Set primary'**
  String get set_primary;

  /// No description provided for @route_again.
  ///
  /// In en, this message translates to:
  /// **'Route again'**
  String get route_again;

  /// No description provided for @tap_map_to_set_start_point.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to set a start point'**
  String get tap_map_to_set_start_point;

  /// No description provided for @tap_map_to_set_destination_point.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to set a destination'**
  String get tap_map_to_set_destination_point;

  /// No description provided for @tap_map_to_place_start_marker.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to place a start marker'**
  String get tap_map_to_place_start_marker;

  /// No description provided for @move_and_zoom_map_under_pin.
  ///
  /// In en, this message translates to:
  /// **'Move and zoom the map under the pin'**
  String get move_and_zoom_map_under_pin;

  /// No description provided for @current_start_point.
  ///
  /// In en, this message translates to:
  /// **'Current start point'**
  String get current_start_point;

  /// No description provided for @from_start_point_coords.
  ///
  /// In en, this message translates to:
  /// **'From: {coords}'**
  String from_start_point_coords(Object coords);

  /// No description provided for @from_current_location.
  ///
  /// In en, this message translates to:
  /// **'From: current location'**
  String get from_current_location;

  /// No description provided for @from_selected_start.
  ///
  /// In en, this message translates to:
  /// **'From: selected start'**
  String get from_selected_start;

  /// No description provided for @choose_start_point.
  ///
  /// In en, this message translates to:
  /// **'Choose start point'**
  String get choose_start_point;

  /// No description provided for @choose_destination.
  ///
  /// In en, this message translates to:
  /// **'Choose destination'**
  String get choose_destination;

  /// No description provided for @use_current_location.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get use_current_location;

  /// No description provided for @pick_on_map.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get pick_on_map;

  /// No description provided for @clear_selected_start.
  ///
  /// In en, this message translates to:
  /// **'Clear selected start'**
  String get clear_selected_start;

  /// No description provided for @avoid_toll_fees.
  ///
  /// In en, this message translates to:
  /// **'Avoid toll fees'**
  String get avoid_toll_fees;

  /// No description provided for @toll_fee_title.
  ///
  /// In en, this message translates to:
  /// **'Toll fees'**
  String get toll_fee_title;

  /// No description provided for @requesting_route.
  ///
  /// In en, this message translates to:
  /// **'Requesting route...'**
  String get requesting_route;

  /// No description provided for @routing_failed.
  ///
  /// In en, this message translates to:
  /// **'Routing failed'**
  String get routing_failed;

  /// No description provided for @no_routes_available.
  ///
  /// In en, this message translates to:
  /// **'No routes available.'**
  String get no_routes_available;

  /// No description provided for @no_route_data_yet.
  ///
  /// In en, this message translates to:
  /// **'No route data yet.'**
  String get no_route_data_yet;

  /// No description provided for @compare_routes.
  ///
  /// In en, this message translates to:
  /// **'Compare routes'**
  String get compare_routes;

  /// No description provided for @roads.
  ///
  /// In en, this message translates to:
  /// **'Roads'**
  String get roads;

  /// No description provided for @more_roads_omitted.
  ///
  /// In en, this message translates to:
  /// **'More roads omitted…'**
  String get more_roads_omitted;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @start_navigation.
  ///
  /// In en, this message translates to:
  /// **'Start Navigation'**
  String get start_navigation;

  /// No description provided for @eta.
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get eta;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @toll_cost.
  ///
  /// In en, this message translates to:
  /// **'Toll cost'**
  String get toll_cost;

  /// No description provided for @toll_time.
  ///
  /// In en, this message translates to:
  /// **'Toll time'**
  String get toll_time;

  /// No description provided for @toll_pricing_time.
  ///
  /// In en, this message translates to:
  /// **'Toll pricing time'**
  String get toll_pricing_time;

  /// No description provided for @toll_time_mode_now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get toll_time_mode_now;

  /// No description provided for @toll_time_mode_depart_at.
  ///
  /// In en, this message translates to:
  /// **'Depart at'**
  String get toll_time_mode_depart_at;

  /// No description provided for @toll_time_mode_arrive_by.
  ///
  /// In en, this message translates to:
  /// **'Arrive by'**
  String get toll_time_mode_arrive_by;

  /// No description provided for @use_current_time.
  ///
  /// In en, this message translates to:
  /// **'Use current time'**
  String get use_current_time;

  /// No description provided for @set_departure_time.
  ///
  /// In en, this message translates to:
  /// **'Set departure time'**
  String get set_departure_time;

  /// No description provided for @set_arrival_time_estimated.
  ///
  /// In en, this message translates to:
  /// **'Set arrival time (estimated)'**
  String get set_arrival_time_estimated;

  /// No description provided for @pick_date_time.
  ///
  /// In en, this message translates to:
  /// **'Pick date/time'**
  String get pick_date_time;

  /// No description provided for @change_date_time.
  ///
  /// In en, this message translates to:
  /// **'Change date/time'**
  String get change_date_time;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @toll_select_tunnel.
  ///
  /// In en, this message translates to:
  /// **'Select tunnel'**
  String get toll_select_tunnel;

  /// No description provided for @toll_select_date.
  ///
  /// In en, this message translates to:
  /// **'Select date  {date}'**
  String toll_select_date(Object date);

  /// No description provided for @toll_select_time.
  ///
  /// In en, this message translates to:
  /// **'Select time  {time}'**
  String toll_select_time(Object time);

  /// No description provided for @arrive_unknown.
  ///
  /// In en, this message translates to:
  /// **'Arrive: --'**
  String get arrive_unknown;

  /// No description provided for @toll_unknown.
  ///
  /// In en, this message translates to:
  /// **'Toll: --'**
  String get toll_unknown;

  /// No description provided for @toll_amount_unknown.
  ///
  /// In en, this message translates to:
  /// **'HK\$--'**
  String get toll_amount_unknown;

  /// No description provided for @no_toll_fees.
  ///
  /// In en, this message translates to:
  /// **'No toll fees'**
  String get no_toll_fees;

  /// No description provided for @toll_chip_unknown.
  ///
  /// In en, this message translates to:
  /// **'toll --'**
  String get toll_chip_unknown;

  /// No description provided for @toll_chip_free.
  ///
  /// In en, this message translates to:
  /// **'toll HK\$0'**
  String get toll_chip_free;

  /// No description provided for @toll_short.
  ///
  /// In en, this message translates to:
  /// **'toll'**
  String get toll_short;

  /// No description provided for @toll_free_route_may_avoid_major_roads.
  ///
  /// In en, this message translates to:
  /// **'Toll-free route may avoid major roads.'**
  String get toll_free_route_may_avoid_major_roads;

  /// No description provided for @toll_info_unavailable_showing_best_route.
  ///
  /// In en, this message translates to:
  /// **'Toll info unavailable; showing best route.'**
  String get toll_info_unavailable_showing_best_route;

  /// No description provided for @no_toll_free_route_showing_lowest_toll_route.
  ///
  /// In en, this message translates to:
  /// **'No toll-free route; showing lowest toll route.'**
  String get no_toll_free_route_showing_lowest_toll_route;

  /// No description provided for @coordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get coordinates;

  /// No description provided for @free_spaces.
  ///
  /// In en, this message translates to:
  /// **'Free spaces'**
  String get free_spaces;

  /// No description provided for @carpark_status_open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get carpark_status_open;

  /// No description provided for @carpark_status_closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get carpark_status_closed;

  /// No description provided for @unknown_carpark.
  ///
  /// In en, this message translates to:
  /// **'Unknown carpark'**
  String get unknown_carpark;

  /// No description provided for @carpark.
  ///
  /// In en, this message translates to:
  /// **'Carpark'**
  String get carpark;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @search_parking.
  ///
  /// In en, this message translates to:
  /// **'Search carpark name or address'**
  String get search_parking;

  /// No description provided for @no_matching_car_parks.
  ///
  /// In en, this message translates to:
  /// **'No matching car parks'**
  String get no_matching_car_parks;

  /// No description provided for @no_matching_locations.
  ///
  /// In en, this message translates to:
  /// **'No matching locations'**
  String get no_matching_locations;

  /// No description provided for @no_recent_searches.
  ///
  /// In en, this message translates to:
  /// **'No recent searches'**
  String get no_recent_searches;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @search_results.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get search_results;

  /// No description provided for @saved_places.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get saved_places;

  /// No description provided for @add_place.
  ///
  /// In en, this message translates to:
  /// **'Add place'**
  String get add_place;

  /// No description provided for @save_place.
  ///
  /// In en, this message translates to:
  /// **'Save place'**
  String get save_place;

  /// No description provided for @place_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get place_name;

  /// No description provided for @place_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Home, School'**
  String get place_name_hint;

  /// No description provided for @place_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get place_location;

  /// No description provided for @place_location_hint.
  ///
  /// In en, this message translates to:
  /// **'Search address or place'**
  String get place_location_hint;

  /// No description provided for @place_edit_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Edit the name for this place (optional).'**
  String get place_edit_name_hint;

  /// No description provided for @place_missing_info.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name and location.'**
  String get place_missing_info;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @na.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get na;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @vacancies.
  ///
  /// In en, this message translates to:
  /// **'Vacancies'**
  String get vacancies;

  /// No description provided for @predictedVacancy.
  ///
  /// In en, this message translates to:
  /// **'Predicted vacancy'**
  String get predictedVacancy;

  /// No description provided for @updated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated;

  /// No description provided for @rates.
  ///
  /// In en, this message translates to:
  /// **'Rates'**
  String get rates;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @photo_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable'**
  String get photo_unavailable;

  /// No description provided for @show_all.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get show_all;

  /// No description provided for @show_fewer.
  ///
  /// In en, this message translates to:
  /// **'Show fewer'**
  String get show_fewer;

  /// No description provided for @no_pricing_info.
  ///
  /// In en, this message translates to:
  /// **'No pricing information available for this car park.'**
  String get no_pricing_info;

  /// No description provided for @no_price_information.
  ///
  /// In en, this message translates to:
  /// **'No price information'**
  String get no_price_information;

  /// No description provided for @rate_type_hourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get rate_type_hourly;

  /// No description provided for @rate_type_half_hourly.
  ///
  /// In en, this message translates to:
  /// **'Half-hourly'**
  String get rate_type_half_hourly;

  /// No description provided for @rate_type_12_hour_parking.
  ///
  /// In en, this message translates to:
  /// **'12-hour Parking'**
  String get rate_type_12_hour_parking;

  /// No description provided for @rate_type_24_hour_parking.
  ///
  /// In en, this message translates to:
  /// **'24-hour Parking'**
  String get rate_type_24_hour_parking;

  /// No description provided for @rate_type_monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get rate_type_monthly;

  /// No description provided for @rate_type_night.
  ///
  /// In en, this message translates to:
  /// **'Night Park'**
  String get rate_type_night;

  /// No description provided for @rate_type_day.
  ///
  /// In en, this message translates to:
  /// **'Day Park'**
  String get rate_type_day;

  /// No description provided for @rate_type_day_and_night.
  ///
  /// In en, this message translates to:
  /// **'Day & Night'**
  String get rate_type_day_and_night;

  /// No description provided for @rate_type_day_pass.
  ///
  /// In en, this message translates to:
  /// **'Day Pass'**
  String get rate_type_day_pass;

  /// No description provided for @excluding_public_holidays.
  ///
  /// In en, this message translates to:
  /// **'Excluding public holidays'**
  String get excluding_public_holidays;

  /// No description provided for @weekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get weekdays;

  /// No description provided for @weekdays_excluding_ph.
  ///
  /// In en, this message translates to:
  /// **'Weekdays (excl. PH)'**
  String get weekdays_excluding_ph;

  /// No description provided for @weekends.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get weekends;

  /// No description provided for @weekends_and_ph.
  ///
  /// In en, this message translates to:
  /// **'Weekends & PH'**
  String get weekends_and_ph;

  /// No description provided for @weekends_excluding_ph.
  ///
  /// In en, this message translates to:
  /// **'Weekends (excl. PH)'**
  String get weekends_excluding_ph;

  /// No description provided for @excluding_public_holiday_suffix.
  ///
  /// In en, this message translates to:
  /// **'(excl. PH)'**
  String get excluding_public_holiday_suffix;

  /// No description provided for @public_holiday.
  ///
  /// In en, this message translates to:
  /// **'PH'**
  String get public_holiday;

  /// No description provided for @weekday_mon_short.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekday_mon_short;

  /// No description provided for @weekday_tue_short.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekday_tue_short;

  /// No description provided for @weekday_wed_short.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekday_wed_short;

  /// No description provided for @weekday_thu_short.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekday_thu_short;

  /// No description provided for @weekday_fri_short.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekday_fri_short;

  /// No description provided for @weekday_sat_short.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekday_sat_short;

  /// No description provided for @weekday_sun_short.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekday_sun_short;

  /// No description provided for @location_not_available.
  ///
  /// In en, this message translates to:
  /// **'Location not available'**
  String get location_not_available;

  /// No description provided for @location_permission_denied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get location_permission_denied;

  /// No description provided for @location_permission_permanently_denied.
  ///
  /// In en, this message translates to:
  /// **'Location permission permanently denied'**
  String get location_permission_permanently_denied;

  /// No description provided for @route_location_not_available.
  ///
  /// In en, this message translates to:
  /// **'Location not available, cannot draw route'**
  String get route_location_not_available;

  /// No description provided for @route_not_found.
  ///
  /// In en, this message translates to:
  /// **'Route not found'**
  String get route_not_found;

  /// No description provided for @route_fetch_failed.
  ///
  /// In en, this message translates to:
  /// **'Route fetch failed: {error}'**
  String route_fetch_failed(Object error);

  /// No description provided for @error_getting_location.
  ///
  /// In en, this message translates to:
  /// **'Error getting location: {error}'**
  String error_getting_location(Object error);

  /// No description provided for @error_loading_carparks.
  ///
  /// In en, this message translates to:
  /// **'Error loading carparks: {error}'**
  String error_loading_carparks(Object error);

  /// No description provided for @rate_from_price.
  ///
  /// In en, this message translates to:
  /// **'From {price}'**
  String rate_from_price(Object price);

  /// No description provided for @vacancy_ev.
  ///
  /// In en, this message translates to:
  /// **'EV {count}'**
  String vacancy_ev(Object count);

  /// No description provided for @vacancy_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled {count}'**
  String vacancy_disabled(Object count);

  /// No description provided for @rate_minimum_hours.
  ///
  /// In en, this message translates to:
  /// **'Min {hours} hr'**
  String rate_minimum_hours(Object hours);

  /// No description provided for @rate_valid_until.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String rate_valid_until(Object date);

  /// No description provided for @route_number.
  ///
  /// In en, this message translates to:
  /// **'Route {number}'**
  String route_number(Object number);

  /// No description provided for @metered_parking.
  ///
  /// In en, this message translates to:
  /// **'Metered'**
  String get metered_parking;

  /// No description provided for @metered_parking_title.
  ///
  /// In en, this message translates to:
  /// **'Metered Parking'**
  String get metered_parking_title;

  /// No description provided for @loading_metered_parking.
  ///
  /// In en, this message translates to:
  /// **'Loading metered parking...'**
  String get loading_metered_parking;

  /// No description provided for @metered_no_data.
  ///
  /// In en, this message translates to:
  /// **'No metered parking data available.'**
  String get metered_no_data;

  /// No description provided for @metered_vacant.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get metered_vacant;

  /// No description provided for @metered_occupied.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get metered_occupied;

  /// No description provided for @metered_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get metered_unknown;

  /// No description provided for @metered_spaces_count.
  ///
  /// In en, this message translates to:
  /// **'{vacant} vacant / {total} total'**
  String metered_spaces_count(Object vacant, Object total);

  /// No description provided for @metered_vehicle_filter.
  ///
  /// In en, this message translates to:
  /// **'Vehicle types'**
  String get metered_vehicle_filter;

  /// No description provided for @metered_vehicle_light_goods.
  ///
  /// In en, this message translates to:
  /// **'Light goods vehicle'**
  String get metered_vehicle_light_goods;

  /// No description provided for @metered_vehicle_heavy_goods.
  ///
  /// In en, this message translates to:
  /// **'Heavy goods vehicle'**
  String get metered_vehicle_heavy_goods;

  /// No description provided for @metered_vehicle_coach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get metered_vehicle_coach;

  /// No description provided for @metered_vehicle_special.
  ///
  /// In en, this message translates to:
  /// **'Special purpose vehicle'**
  String get metered_vehicle_special;

  /// No description provided for @metered_status_free_now.
  ///
  /// In en, this message translates to:
  /// **'Free now'**
  String get metered_status_free_now;

  /// No description provided for @metered_status_metering_now.
  ///
  /// In en, this message translates to:
  /// **'Metering now'**
  String get metered_status_metering_now;

  /// No description provided for @metered_status_no_parking_now.
  ///
  /// In en, this message translates to:
  /// **'No parking now'**
  String get metered_status_no_parking_now;

  /// No description provided for @metered_status_unknown.
  ///
  /// In en, this message translates to:
  /// **'Hours unknown'**
  String get metered_status_unknown;

  /// No description provided for @tdas_eta.
  ///
  /// In en, this message translates to:
  /// **'TDAS ETA: {eta} / {speed}'**
  String tdas_eta(Object eta, Object speed);

  /// No description provided for @duration_hours_minutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String duration_hours_minutes(Object hours, Object minutes);

  /// No description provided for @duration_minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String duration_minutes(Object minutes);

  /// No description provided for @distance_km.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distance_km(Object km);

  /// No description provided for @distance_m.
  ///
  /// In en, this message translates to:
  /// **'{m} m'**
  String distance_m(Object m);

  /// No description provided for @arrive_at.
  ///
  /// In en, this message translates to:
  /// **'Arrive: {time}'**
  String arrive_at(Object time);

  /// No description provided for @depart_and_arrive.
  ///
  /// In en, this message translates to:
  /// **'Depart: {depart} · Arrive: {arrive}'**
  String depart_and_arrive(Object depart, Object arrive);

  /// No description provided for @arrive_and_est_depart.
  ///
  /// In en, this message translates to:
  /// **'Arrive: {arrive} · Est. depart: {depart}'**
  String arrive_and_est_depart(Object arrive, Object depart);

  /// No description provided for @est_toll.
  ///
  /// In en, this message translates to:
  /// **'Est. toll: {amount}'**
  String est_toll(Object amount);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
