import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:parking_app/config/api_config.dart';

enum HkSpeedMapSource { standard, enhancedExperiment }

extension HkSpeedMapSourceX on HkSpeedMapSource {
  String get storageValue => switch (this) {
    HkSpeedMapSource.standard => 'standard',
    HkSpeedMapSource.enhancedExperiment => 'enhancedExperiment',
  };

  String get label => switch (this) {
    HkSpeedMapSource.standard => 'Standard',
    HkSpeedMapSource.enhancedExperiment => 'Enhanced (Experiment)',
  };

  String get description => switch (this) {
    HkSpeedMapSource.standard => 'Existing HKeMobility speed map overlay',
    HkSpeedMapSource.enhancedExperiment =>
      'Experimental wider coverage using VW_IRN_AVG_SPEED_MAP',
  };
}

HkSpeedMapSource hkSpeedMapSourceFromStorage(String? value) {
  return HkSpeedMapSource.values.firstWhere(
    (source) => source.storageValue == value,
    orElse: () => HkSpeedMapSource.standard,
  );
}

class HkSpeedMapTileLayer extends StatelessWidget {
  const HkSpeedMapTileLayer({
    super.key,
    required this.source,
    required this.opacity,
    this.minZoom = 6,
    this.maxZoom = 18,
    this.keepBuffer = 0,
    this.panBuffer = 0,
  });

  static const String _baseUrl = ApiConfig.hkemobilitySpeedMapUrl;
  static const Map<String, String> _headers = {
    'Referer': ApiConfig.hkemobilityRouteReferer,
    'Origin': ApiConfig.hkemobilityBase,
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36',
    'Accept':
        'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
  };

  final HkSpeedMapSource source;
  final double opacity;
  final double minZoom;
  final double maxZoom;
  final int keepBuffer;
  final int panBuffer;

  WMSTileLayerOptions _buildWmsOptions() {
    return switch (source) {
      HkSpeedMapSource.standard => WMSTileLayerOptions(
        baseUrl: _baseUrl,
        layers: const ['DRSS:SPEED_MAP'],
        format: 'image/png',
        transparent: true,
        version: '1.1.1',
        otherParameters: const {'fakeParams': '1'},
      ),
      HkSpeedMapSource.enhancedExperiment => WMSTileLayerOptions(
        baseUrl: _baseUrl,
        layers: const ['VW_IRN_AVG_SPEED_MAP'],
        styles: const ['speed_map'],
        format: 'image/png',
        transparent: true,
        version: '1.1.1',
        otherParameters: const {'fakeParams': '1'},
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: TileLayer(
        minZoom: minZoom,
        maxZoom: maxZoom,
        keepBuffer: keepBuffer,
        panBuffer: panBuffer,
        tileDimension: 512,
        zoomOffset: -1,
        wmsOptions: _buildWmsOptions(),
        tileProvider: NetworkTileProvider(
          headers: Map<String, String>.from(_headers),
          cachingProvider: const DisabledMapCachingProvider(),
        ),
      ),
    );
  }
}
