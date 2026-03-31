import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:parking_app/network/navigation_service.dart';
import 'package:parking_app/network/parking_api.dart' as parking;
import 'package:parking_app/network/route_api.dart' as routing;
import 'package:parking_app/network/smart_navigation_service.dart';
import 'package:parking_app/network/tdas_service.dart';
import 'package:parking_app/network/toll_service.dart';
import 'package:parking_app/l10n/app_localizations.dart';
import 'package:parking_app/widget/hk_speed_map_layer.dart';

part 'navigation_screen_models.dart';
part 'navigation_screen_logic.dart';
part 'navigation_screen_widgets.dart';
part 'navigation_screen_ui.dart';
part 'navigation_screen_routing.dart';
part 'navigation_screen_pickers.dart';
part 'navigation_screen_components.dart';
