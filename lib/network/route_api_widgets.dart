part of 'route_api.dart';

/// Non?‘modal bottom sheet that lets the user tap "Route" while the sheet is open.
class CarparkRouteSheet extends StatefulWidget {
  final Carpark carpark;
  final OsrmRouteApi api;
  final Future<LatLng> Function() getCurrentLocation; // inject from your Home screen
  final void Function(RouteResult) onRoute;            // parent draws the polyline
  final VoidCallback? onClear;                         // optional clear action

  const CarparkRouteSheet({
    super.key,
    required this.carpark,
    required this.api,
    required this.getCurrentLocation,
    required this.onRoute,
    this.onClear,
  });

  /// Shows a persistent (non?‘modal) bottom sheet so the map remains interactive.
  static PersistentBottomSheetController show({
    required BuildContext context,
    required Carpark carpark,
    required OsrmRouteApi api,
    required Future<LatLng> Function() getCurrentLocation,
    required void Function(RouteResult) onRoute,
    VoidCallback? onClear,
  }) {
    final scaffold = Scaffold.maybeOf(context);
    assert(scaffold != null, 'Scaffold required above context');
    return scaffold!.showBottomSheet((ctx) => CarparkRouteSheet(
          carpark: carpark,
          api: api,
          getCurrentLocation: getCurrentLocation,
          onRoute: onRoute,
          onClear: onClear,
        ));
  }

  @override
  State<CarparkRouteSheet> createState() => _CarparkRouteSheetState();
}

class _CarparkRouteSheetState extends State<CarparkRouteSheet> {
  bool _busy = false;
  String? _error;
  RouteResult? _last;

  Future<void> _routeNow() async {
    setState(() { _busy = true; _error = null; });
    try {
      final me = await widget.getCurrentLocation();
      final res = await widget.api.routeGeoJson(origin: me, destination: widget.carpark.ll);
      widget.onRoute(res); // hand points back to parent to draw
      setState(() => _last = res);
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context)!.route_fetch_failed(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cp = widget.carpark;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 12,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_parking),
                  const SizedBox(width: 8),
                  Expanded(child: Text(cp.name, style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  )
                ],
              ),
              const SizedBox(height: 4),
              Text('${l10n.coordinates}: ${cp.lat.toStringAsFixed(5)}, ${cp.lng.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall),
              if (cp.freeSpaces != null)
                Text('${l10n.free_spaces}: ${cp.freeSpaces}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              if (_last != null)
                Wrap(spacing: 12, runSpacing: 6, children: [
                  _Chip(label: l10n.eta, value: _fmtTime(_last!.durationSeconds)),
                  _Chip(label: l10n.distance, value: _fmtDist(_last!.distanceMeters)),
                ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _routeNow,
                    icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                 : const Icon(Icons.alt_route),
                    label: Text(_busy ? l10n.routing : l10n.route),
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.onClear != null)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : widget.onClear,
                    icon: const Icon(Icons.clear),
                    label: Text(l10n.clear),
                  )
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtTime(double sec) {
    final m = (sec / 60).floor();
    final s = (sec - m * 60).round();
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  String _fmtDist(double m) {
    if (m >= 1000) {
      return '${(m / 1000).toStringAsFixed(1)} km';
    }
    return '${m.toStringAsFixed(0)} m';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Helper: get current location with permission handling.
Future<LatLng> getCurrentLatLng() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    await Geolocator.openLocationSettings();
    throw Exception('Location services are disabled.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }
  }
  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permissions are permanently denied.');
  }

  final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  return LatLng(pos.latitude, pos.longitude);
}
