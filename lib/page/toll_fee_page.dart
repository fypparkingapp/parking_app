import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:parking_app/manager/map_theme_manager.dart';
import 'package:parking_app/network/toll_service.dart';
import 'package:parking_app/l10n/app_localizations.dart';

class TollFeePage extends StatefulWidget {
  const TollFeePage({
    super.key,
    required this.themeConfig,
    required this.useDarkTheme,
  });

  final MapThemeConfig themeConfig;
  final bool useDarkTheme;

  @override
  State<TollFeePage> createState() => _TollFeePageState();
}

class _TollFeePageState extends State<TollFeePage> {
  final TollService _tollService = TollService();
  late final List<TollFacilityInfo> _facilities =
      _tollService.listFacilities();
  TollFacilityInfo? _selectedFacility;
  DateTime _selectedDateTime = DateTime.now();
  List<double?> _slotRates = List<double?>.filled(48, null);
  bool _isLoadingRates = false;
  int _rateRequestId = 0;
  HkVehicleType _vehicleType = HkVehicleType.privateCar;
  double? _tollAmount;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (_facilities.isNotEmpty) {
      _selectedFacility = _facilities.first;
    }
    _loadSlotRates();
  }

  @override
  void dispose() {
    _tollService.dispose();
    super.dispose();
  }

  String _facilityLanguageCode() {
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode.toLowerCase();
    if (language == 'zh') {
      final script = locale.scriptCode?.toLowerCase();
      if (script == 'hans') return 'sc';
      if (script == 'hant') return 'tc';
      final country = locale.countryCode?.toUpperCase();
      if (country == 'CN' || country == 'SG') return 'sc';
      if (country == 'HK' || country == 'MO' || country == 'TW') return 'tc';
      return 'tc';
    }
    return 'en';
  }

  String _facilityLabel(TollFacilityInfo facility) {
    return facility.nameForLanguageCode(_facilityLanguageCode());
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final local = dt.toLocal();
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _formatHkd(double? amount) {
    if (amount == null) {
      return AppLocalizations.of(context)!.toll_amount_unknown;
    }
    final formatted =
        amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
    return 'HK\$$formatted';
  }

  double? _slotRateForSelectedTime() {
    if (_slotRates.isEmpty) return null;
    final minutes = _selectedDateTime.hour * 60 + _selectedDateTime.minute;
    final slot = (minutes / 30).floor().clamp(0, _slotRates.length - 1);
    return _slotRates[slot];
  }

  Future<void> _pickDateOnly() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });
    await _loadSlotRates();
  }

  Future<void> _pickTimeOnly() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (time == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        time.hour,
        time.minute,
      );
    });
    await _loadSlotRates();
    _searchTollFee();
  }

  Future<void> _searchTollFee() async {
    final facility = _selectedFacility;
    if (facility == null) return;
    setState(() {
      _errorMessage = null;
      _tollAmount = null;
    });
    try {
      final amount = await _tollService.fetchRateForFacility(
        facility: facility,
        vehicleType: _vehicleType,
        dateTime: _selectedDateTime,
      );
      if (!mounted) return;
      setState(() {
        _tollAmount = amount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadSlotRates() async {
    final facility = _selectedFacility;
    if (facility == null) return;
    final requestId = ++_rateRequestId;
    setState(() => _isLoadingRates = true);
    const totalSlots = 48;
    final next = List<double?>.filled(totalSlots, null);
    final fixed = facility.fixedRates?[_vehicleType];
    if (fixed != null && facility.hkMobilityTunnelCode == null) {
      for (var i = 0; i < next.length; i++) {
        next[i] = fixed;
      }
      if (!mounted || requestId != _rateRequestId) return;
      setState(() {
        _slotRates = next;
        _isLoadingRates = false;
      });
    } else {
      Future<void> fetchSlot(int slot) async {
        final minutes = slot * 30;
        final dt = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          minutes ~/ 60,
          minutes % 60,
        );
        final rate = await _tollService.fetchRateForFacility(
          facility: facility,
          vehicleType: _vehicleType,
          dateTime: dt,
        );
        next[slot] = rate;
      }

      final startSlot = ((_selectedDateTime.hour * 60 +
                  _selectedDateTime.minute) /
              30)
          .floor()
          .clamp(0, totalSlots - 1);
      final order = <int>[];
      for (var offset = 0; offset < totalSlots; offset++) {
        if (offset == 0) {
          order.add(startSlot);
          continue;
        }
        final right = startSlot + offset;
        final left = startSlot - offset;
        if (right < totalSlots) order.add(right);
        if (left >= 0) order.add(left);
      }

      for (var i = 0; i < order.length; i += 8) {
        if (!mounted || requestId != _rateRequestId) return;
        final batch = <Future<void>>[];
        final end = (i + 8).clamp(0, order.length);
        for (var j = i; j < end; j++) {
          batch.add(fetchSlot(order[j]));
        }
        await Future.wait(batch);
        if (!mounted || requestId != _rateRequestId) return;
        setState(() => _slotRates = List<double?>.from(next));
      }

      if (!mounted || requestId != _rateRequestId) return;
      setState(() => _slotRates = List<double?>.from(next));
    }
    if (!mounted || requestId != _rateRequestId) return;
    setState(() => _isLoadingRates = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.useDarkTheme;
    final dialLabelColor = isDark ? Colors.white : const Color(0xFF1F1F1F);
    final pageTheme = isDark
        ? ThemeData.dark().copyWith(
            scaffoldBackgroundColor: widget.themeConfig.backgroundColor,
            colorScheme: ThemeData.dark().colorScheme.copyWith(
              surface: widget.themeConfig.appBarColor,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: widget.themeConfig.appBarColor,
              foregroundColor: widget.themeConfig.appBarForeground,
              elevation: 0,
            ),
          )
        : theme;
    final labelStyle = pageTheme.textTheme.titleSmall?.copyWith(
      color: pageTheme.colorScheme.onSurface.withOpacity(0.75),
      fontWeight: FontWeight.w500,
    );
    final valueStyle = pageTheme.textTheme.titleSmall?.copyWith(
      color: pageTheme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final l10n = AppLocalizations.of(context)!;

    return Theme(
      data: pageTheme,
      child: Scaffold(
        backgroundColor: pageTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(l10n.toll_fee_title),
          backgroundColor: pageTheme.colorScheme.surface,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
            Center(
              child: _TollDial(
                dateTime: _selectedDateTime,
                amountLabel:
                    _formatHkd(_tollAmount ?? _slotRateForSelectedTime()),
                hourlyRates: _slotRates,
                isLoadingRates: _isLoadingRates,
                labelColor: dialLabelColor,
                tickColor: isDark ? Colors.white70 : const Color(0xFF1F1F1F),
                onTimeChanged: (next) {
                  setState(() => _selectedDateTime = next);
                },
                onDragEnd: _searchTollFee,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  setState(() => _selectedDateTime = DateTime.now());
                  await _loadSlotRates();
                  _searchTollFee();
                },
                child: Text(l10n.reset),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.toll_select_tunnel,
                style: labelStyle,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<TollFacilityInfo>(
              initialValue: _selectedFacility,
              isExpanded: true,
              items: _facilities
                  .map(
                    (facility) => DropdownMenuItem(
                      value: facility,
                      child: Text(_facilityLabel(facility)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedFacility = value);
                _loadSlotRates();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.toll_select_date(
                      _formatDateTime(_selectedDateTime).split(' ').first,
                    ),
                    style: valueStyle,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDateOnly,
                  icon: const Icon(Icons.edit_calendar),
                  label: Text(l10n.select),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.toll_select_time(
                      _formatDateTime(_selectedDateTime).split(' ').last,
                    ),
                    style: valueStyle,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickTimeOnly,
                  icon: const Icon(Icons.schedule),
                  label: Text(l10n.select),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _VehicleSelector(
                selected: _vehicleType,
                onChanged: (next) {
                  if (next == _vehicleType) return;
                  setState(() => _vehicleType = next);
                  _loadSlotRates();
                  _searchTollFee();
                },
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleSelector extends StatefulWidget {
  const _VehicleSelector({
    required this.selected,
    required this.onChanged,
  });

  final HkVehicleType selected;
  final ValueChanged<HkVehicleType> onChanged;

  @override
  State<_VehicleSelector> createState() => _VehicleSelectorState();
}

class _VehicleSelectorState extends State<_VehicleSelector> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = _indexFor(widget.selected);
    _controller = PageController(viewportFraction: 0.42, initialPage: _index);
  }

  @override
  void didUpdateWidget(covariant _VehicleSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _indexFor(widget.selected);
    if (nextIndex != _index) {
      _index = nextIndex;
      _controller.animateToPage(
        _index,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexFor(HkVehicleType type) {
    switch (type) {
      case HkVehicleType.privateCar:
        return 0;
      case HkVehicleType.motorcycle:
        return 1;
      case HkVehicleType.taxi:
        return 2;
    }
  }

  HkVehicleType _typeForIndex(int index) {
    switch (index) {
      case 1:
        return HkVehicleType.motorcycle;
      case 2:
        return HkVehicleType.taxi;
      case 0:
      default:
        return HkVehicleType.privateCar;
    }
  }

  String _labelFor(HkVehicleType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case HkVehicleType.privateCar:
        return l10n.vehicle_type_private_car;
      case HkVehicleType.motorcycle:
        return l10n.vehicle_type_motorcycle;
      case HkVehicleType.taxi:
        return l10n.vehicle_type_taxi;
    }
  }

  IconData _iconFor(HkVehicleType type) {
    switch (type) {
      case HkVehicleType.privateCar:
        return Icons.directions_car;
      case HkVehicleType.motorcycle:
        return Icons.two_wheeler;
      case HkVehicleType.taxi:
        return Icons.local_taxi;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 104,
      child: PageView.builder(
        controller: _controller,
        itemCount: 3,
        onPageChanged: (index) {
          final type = _typeForIndex(index);
          setState(() => _index = index);
          widget.onChanged(type);
        },
        itemBuilder: (context, index) {
          final type = _typeForIndex(index);
          final selected = index == _index;
          final color = selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline;
          return AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: selected ? 4 : 12,
            ),
            child: Material(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : theme.colorScheme.surface,
              elevation: selected ? 4 : 1,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  _controller.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                  widget.onChanged(type);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_iconFor(type), color: color, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _labelFor(type),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TollDial extends StatefulWidget {
  const _TollDial({
    required this.dateTime,
    required this.amountLabel,
    required this.hourlyRates,
    required this.isLoadingRates,
    required this.labelColor,
    required this.tickColor,
    required this.onTimeChanged,
    required this.onDragEnd,
  });

  final DateTime dateTime;
  final String amountLabel;
  final List<double?> hourlyRates;
  final bool isLoadingRates;
  final Color labelColor;
  final Color tickColor;
  final ValueChanged<DateTime> onTimeChanged;
  final VoidCallback onDragEnd;

  @override
  State<_TollDial> createState() => _TollDialState();
}

class _TollDialState extends State<_TollDial> {
  double? _dragStartAngle;
  int? _dragStartMinutes;

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final local = dt.toLocal();
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final local = dt.toLocal();
    return '${two(local.hour)}:${two(local.minute)}';
  }

  double _angleForOffset(Offset position, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final v = position - center;
    return (math.atan2(v.dy, v.dx) + math.pi * 2) % (math.pi * 2);
  }

  double _normalizeDelta(double delta) {
    var d = delta % (math.pi * 2);
    if (d > math.pi) d -= math.pi * 2;
    if (d < -math.pi) d += math.pi * 2;
    return d;
  }

  void _handleDragStart(Offset position, Size size) {
    _dragStartAngle = _angleForOffset(position, size);
    _dragStartMinutes =
        widget.dateTime.hour * 60 + widget.dateTime.minute;
  }

  void _handleDragUpdate(Offset position, Size size) {
    if (_dragStartAngle == null || _dragStartMinutes == null) return;
    final currentAngle = _angleForOffset(position, size);
    final delta = _normalizeDelta(currentAngle - _dragStartAngle!);
    final deltaMinutes = (-delta / (math.pi * 2) * 1440).round();
    var nextMinutes = (_dragStartMinutes! + deltaMinutes) % 1440;
    if (nextMinutes < 0) nextMinutes += 1440;
    final next = DateTime(
      widget.dateTime.year,
      widget.dateTime.month,
      widget.dateTime.day,
      nextMinutes ~/ 60,
      nextMinutes % 60,
    );
    widget.onTimeChanged(next);
  }

  void _handleDragEnd() {
    _dragStartAngle = null;
    _dragStartMinutes = null;
    widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialSize = math.min(size.width * 0.78, 280.0);

    return SizedBox(
      width: dialSize,
      height: dialSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ringSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          final minutes = widget.dateTime.hour * 60 + widget.dateTime.minute;
          final angle = (minutes / 1440) * math.pi * 2;

          return GestureDetector(
            onPanStart: (details) {
              _handleDragStart(details.localPosition, ringSize);
            },
            onPanUpdate: (details) {
              _handleDragUpdate(details.localPosition, ringSize);
            },
            onPanEnd: (_) => _handleDragEnd(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: ringSize,
                  painter: _TollDialPainter(
                    angle: angle,
                    hourlyRates: widget.hourlyRates,
                    labelColor: widget.labelColor,
                    tickColor: widget.tickColor,
                  ),
                ),
                Container(
                  width: ringSize.width * 0.44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDate(widget.dateTime),
                        style: TextStyle(fontSize: 14, color: widget.labelColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(widget.dateTime),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: widget.labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.amountLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.labelColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isLoadingRates)
                  Positioned(
                    top: ringSize.height * 0.07,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Positioned(
                  right: ringSize.width * 0.06,
                  child: const Icon(Icons.play_arrow, size: 28),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Color _tollColorForRate(double? rate, List<double> distinctRates) {
  if (rate == null) return const Color(0xFFE0E0E0);
  if (distinctRates.length <= 1) return const Color(0xFFD7F1D6);
  final index = distinctRates.indexOf(rate);
  final t = (index / (distinctRates.length - 1)).clamp(0.0, 1.0);
  const anchors = [
    Color(0xFFB4D645), // green (cheap)
    Color(0xFF6BB53E), // yellow-green
    Color(0xFFF2BD2D), // yellow
    Color(0xFFE06A2D), // orange
    Color(0xFFC62828), // red (expensive)
  ];
  if (t <= 0) return anchors.first;
  if (t >= 1) return anchors.last;
  final bucket = (t * (anchors.length - 1)).round();
  return anchors[bucket.clamp(0, anchors.length - 1)];
}

class _TollDialPainter extends CustomPainter {
  _TollDialPainter({
    required this.angle,
    required this.hourlyRates,
    required this.labelColor,
    required this.tickColor,
  });

  final double angle;
  final List<double?> hourlyRates;
  final Color labelColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.62;
    final strokeWidth = outerRadius - innerRadius;
    final rect = Rect.fromCircle(
      center: center,
      radius: outerRadius - strokeWidth / 2,
    );

    final rates = hourlyRates.isNotEmpty
        ? hourlyRates
        : List<double?>.filled(48, null);
    final numericRates = rates.whereType<double>().toList();
    final distinctRates = numericRates.toSet().toList()..sort();

    const slotCount = 48;
    final sweep = (math.pi * 2) / slotCount;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 2 - angle);
    canvas.translate(-center.dx, -center.dy);

    var start = -math.pi / 2;
    for (var i = 0; i < slotCount; i++) {
      final rate = rates[i];
      final paint = Paint()
        ..color = _tollColorForRate(rate, distinctRates)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep - 0.01, false, paint);
      start += sweep;
    }

    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1;
    for (var i = 0; i < slotCount; i++) {
      final tickAngle = -math.pi / 2 + sweep * i;
      final isHour = i % 2 == 0;
      final tickLen = isHour ? 10.0 : 6.0;
      final startPt = Offset(
        center.dx + (innerRadius - 2) * math.cos(tickAngle),
        center.dy + (innerRadius - 2) * math.sin(tickAngle),
      );
      final endPt = Offset(
        center.dx + (innerRadius - 2 - tickLen) * math.cos(tickAngle),
        center.dy + (innerRadius - 2 - tickLen) * math.sin(tickAngle),
      );
      canvas.drawLine(startPt, endPt, tickPaint);
    }

    final textStyle = TextStyle(
      color: labelColor,
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );
    for (var hour = 0; hour < 24; hour++) {
      final label = hour == 0 ? '24' : hour.toString();
      final angle = -math.pi / 2 + (math.pi * 2 / 24) * hour;
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final radius = innerRadius - 18;
      final pos = Offset(
        center.dx + radius * math.cos(angle) - textPainter.width / 2,
        center.dy + radius * math.sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, pos);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TollDialPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.hourlyRates != hourlyRates;
  }
}
