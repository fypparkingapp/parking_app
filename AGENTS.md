# AGENTS.md

Project: Wilson Parking app (Flutter)

## Scope
- Root: `/Users/rnpk/Documents/wilson_parking/parking_app`
- Languages: Dart/Flutter; helper script in Python (`test.py`)
- App entry: `lib/main.dart`
- Home screen assembly: `lib/page/appmain.dart` (parts)
- Localization source: `lib/l10n/*.arb` (generated Dart in same folder)

## Conventions
- Prefer small, focused widgets; avoid giant files when adding features.
- Keep business logic out of UI widgets where practical.
- Use `rg` for search and `apply_patch` for small edits.
- Keep code ASCII unless the file already uses Unicode.
- Do not edit generated l10n Dart files; edit ARB and re-generate.
- `backup/` is excluded from static analysis.

## Architecture overview
- `main.dart` loads saved language from SharedPreferences and boots `ParkingApp`.
- `ParkingApp` uses `appLanguageNotifier` to set locale and renders `MainScreen`.
- `MainScreen` and `ParkingMapScreen` both render `HomeScreen` with different flags.
- `HomeScreen` is split across parts for prefs, search, routing, map, and detail sheet.
- Map uses `flutter_map` with tile layers, optional HK Speed Map WMS, and location marker.
- Parking data comes from `ParkingApi` with in-memory + SharedPreferences cache.
- Search uses `CarparkSearchDelegate` with geocoding and saved places.
- `NavigationScreen` uses OSRM for routes, `TollService` for toll estimates, TDAS for insight, and `NavigationService` for turn-by-turn.

## Data sources and endpoints (from code)
- Carpark info: `https://api.data.gov.hk/v1/carpark-info-vacancy`
- Gov vacancy feed: `https://resource.data.one.gov.hk/td/carpark/vacancy_all.json`
- Wilson metadata: `https://parkapi2.ryanpumpkin.com/carparks`
- Geocoding: `https://photon.komoot.io/api`
- OSRM: `https://osrm.ryanpumpkin.com` (configurable)
- Toll rates/time: `https://www.hkemobility.gov.hk/api/drss/toll/*`
- TDAS: `https://tdas-api.hkemobility.gov.hk/tdas/api/route`
- Map tiles: Carto Voyager/Dark/Light tiles (see map themes)
- HK Speed Map WMS: `https://www.hkemobility.gov.hk/api/drss/layer/map?` (DRSS:SPEED_MAP)

## Preferences and keys
- `selectedTheme` -> `_themePrefKey`
- `selectedLanguage` -> `_languagePrefKey`
- `recentCarparkSearches` -> `_recentSearchPrefKey`
- `favoriteCarparks` -> `_favoriteCarparkPrefKey`
- `savedPlaces` -> `_savedPlacesPrefKey`
- `selectedVehicleType` -> `_vehicleTypePrefKey`

## lib/ (Dart)
- `lib/main.dart`: App entry; loads language preference; builds MaterialApp with MainScreen.
- `lib/manager/language_manager.dart`: AppLanguage enum, notifier, locale conversion helpers.
- `lib/manager/map_theme_manager.dart`: MapThemeConfig model for tile theme settings.
- `lib/model/saved_place.dart`: SavedPlace model with JSON serialization and geocoding conversion.

## lib/Network
- `lib/Network/api.dart`: Barrel exports for API/services.
- `lib/Network/geocoding_service.dart`: Photon geocoder client; supports bbox and fallback label.
- `lib/Network/navigation_service.dart`: Real-time navigation state; step advancement; turn instructions; off-route detection.
- `lib/Network/parking_api.dart`: Part stub for ParkingApi; SharedPreferences + http.
- `lib/Network/parking_api_impl.dart`: Carpark and CarparkRate models; merges gov, Link REIT, Wilson data; caches results.
- `lib/Network/route_api.dart`: OSRM routing API and UI part declarations.
- `lib/Network/route_api_logic.dart`: OsrmRouteApi with alternatives, road metrics, polyline decode, retry logic.
- `lib/Network/route_api_widgets.dart`: CarparkRouteSheet non-modal bottom sheet; getCurrentLatLng helper.
- `lib/Network/tdas_service.dart`: TDAS route insight fetch and tunnel detection heuristics.
- `lib/Network/toll_service.dart`: Part stub for TollService.
- `lib/Network/toll_service_impl.dart`: Toll detection and pricing; time-varying rates; facility list and helpers.

## lib/l10n
- `lib/l10n/app_en.arb`: English strings source.
- `lib/l10n/app_zh.arb`: Chinese base strings source.
- `lib/l10n/app_zh_CN.arb`: Simplified Chinese strings source.
- `lib/l10n/app_zh_TW.arb`: Traditional Chinese strings source.
- `lib/l10n/app_localizations.dart`: Generated localization delegate and string interface.
- `lib/l10n/app_localizations_en.dart`: Generated English implementation.
- `lib/l10n/app_localizations_zh.dart`: Generated Chinese implementations.

## lib/page
- `lib/page/appmain.dart`: HomeScreen aggregator with part files.
- `lib/page/home_screen_widgets.dart`: HomeScreen widget and main UI; map scaffolding; overlays; long press sets red marker; bottom bar.
- `lib/page/home_screen_search.dart`: Search workflow; search bar UI; geocoding selection; saved places integration.
- `lib/page/home_screen_prefs.dart`: SharedPreferences read/write for recents, favorites, saved places, theme, language, vehicle type.
- `lib/page/home_screen_route.dart`: Navigation to ParkingMapScreen and NavigationScreen.
- `lib/page/main_screen.dart`: Main tab entry; shows HomeScreen with markers hidden and bottom function bar.
- `lib/page/parking_map_screen.dart`: Full parking map screen; shows all markers with back button.
- `lib/page/navigation_screen.dart`: Navigation screen entry; imports and parts.
- `lib/page/navigation_screen_widgets.dart`: NavigationScreen UI with map, markers, and route selection.
- `lib/page/navigation_screen_ui.dart`: Route sheet UI, toll chips, and top overlays.
- `lib/page/navigation_screen_routing.dart`: Route fetch, alternatives, toll estimation, camera fit, TDAS insight.
- `lib/page/navigation_screen_pickers.dart`: Route priority picker and start/toll time pickers.
- `lib/page/navigation_screen_components.dart`: Reusable route/toll UI widgets.
- `lib/page/navigation_screen_models.dart`: RouteSortKey and TollTimeMode enums.
- `lib/page/navigation_screen_logic.dart`: Placeholder for future logic extensions.
- `lib/page/open_screen.dart`: Loading splash screen used while carparks load.
- `lib/page/settings.dart`: Settings drawer UI for map theme, language, clustering, speed map, zoom, reset, cache clear.
- `lib/page/toll_fee_page.dart`: Toll fee viewer with dial and time selection.

## lib/widget
- `lib/widget/map_widget.dart`: Map behaviors; location permissions; carpark loading; clustering; prefetch.
- `lib/widget/carpark_sheet.dart`: Carpark detail bottom sheet with vacancies, rates, photos, and navigation button.
- `lib/widget/carpark_search_delegate.dart`: SearchDelegate for carparks and locations; geocoding; recent/favorite handling.
- `lib/widget/carpark_search_sections.dart`: Search UI sections; saved place dialogs; location and carpark tiles.

## assets
- `assets/appicon.png`: App icon used in OpenScreen.
- `assets/icon/app_icon.png`: Alternate app icon asset.

## test
- `test/service/route_api_test.dart`: Widget tests for CarparkRouteSheet success/error flows.
- `test/service/toll_service_test.dart`: Unit test for Tai Lam Tunnel detection and time-varying toll rates.

## Root data and scripts
- `carparks.json`: Large Wilson metadata snapshot used for reference/testing.
- `carpark-info-vacancy.json`: Gov carpark + vacancy sample data.
- `td_toll_rates_en.html`: Transport Department toll rates page snapshot.
- `tdas.pdf`: TDAS documentation snapshot.
- `hkemobility_app.js`: Saved HKeMobility web asset (app bundle).
- `hkemobility_rt_app.js`: Saved HKeMobility runtime asset (app).
- `hkemobility_rt_toll.js`: Saved HKeMobility runtime asset (toll).
- `hkemobility_rt_vendors.js`: Saved HKeMobility runtime vendor bundle.
- `hkemobility_toll.js`: Saved HKeMobility web asset (toll bundle).
- `hkemobility_vendors.js`: Saved HKeMobility vendor bundle.
- `test.py`: Link REIT parking rate scraper; can output CSV.
- `tmp_dt.dart`: DateTime parse scratch file.

## Tooling and config
- `pubspec.yaml`: Dependencies, assets, and Flutter generate flag for l10n.
- `analysis_options.yaml`: Flutter lints; excludes `backup/`.
- `l10n.yaml`: Flutter localization configuration.
- `devtools_options.yaml`: Flutter DevTools config.

## Platform scaffolding (generated by Flutter)
- `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`: Platform build targets.
- `build/`: Build output (do not edit).
- `backup/`: Local backups (excluded from analyzer).
