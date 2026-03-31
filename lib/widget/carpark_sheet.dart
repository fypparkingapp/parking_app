part of '../page/appmain.dart';

extension _HomeScreenDetails on _HomeScreenState {

  void _showCarparkDetails(Carpark c) {
    unawaited(_rememberRecentSearch(c));
    _safeSetState(() {
      _pickingRouteStart = false;
      _pickingRouteDestination = false;
    });
    final theme = _mapThemes[_selectedTheme]!;
    _prefetchCarparkImage(c);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool showAllVacancies = false;
        bool showAllRates = true;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final sheetTheme = Theme.of(ctx);
            final l10n = AppLocalizations.of(ctx)!;
            final vacancyEntries = c.vacancies.entries.toList();
            final rates = c.privateCarRates;
            final visibleVacancies = showAllVacancies
                ? vacancyEntries
                : vacancyEntries.take(2).toList();
            final visibleRates = showAllRates ? rates : rates.take(2).toList();

            final primaryRate = _findPrimaryRate(rates);
            final priceValue = primaryRate != null
                ? _formatRatePrice(primaryRate)
                : l10n.na;
            final vacancyValue =
                c.vacancy?.toString() ?? l10n.na;

            final displayVacancyValue = (c.vacancy != null && c.vacancy! >= 0)
                ? vacancyValue
                : l10n.na;

            final statusLabel = _formatOpeningStatusLabel(c.openingStatus);
            final statusColor = _resolveOpeningStatusColor(
              c.openingStatus,
              theme.accentColor,
            );
            final displayName = _localizedCarparkName(c);
            final displayAddress = _localizedCarparkAddress(c);
            final isWilson =
                c.operatorName.toLowerCase().trim() == 'wilson';

            Widget statCard({
              required IconData icon,
              required String label,
              required String value,
            }) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sheetTheme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: theme.accentColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: sheetTheme.textTheme.labelMedium),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: sheetTheme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.55,
              minChildSize: 0.28,
              maxChildSize: 0.92,
              builder: (ctx, scrollController) {
                final bottomInset = MediaQuery.of(ctx).padding.bottom;
                return Material(
                  elevation: 14,
                  color: sheetTheme.cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: sheetTheme.dividerColor.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: sheetTheme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.close,
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      if (displayAddress.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          displayAddress,
                          style: sheetTheme.textTheme.bodySmall?.copyWith(
                            color: sheetTheme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                      ],
                      if (isWilson) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Operator: Wilson',
                          style: sheetTheme.textTheme.bodySmall?.copyWith(
                            color: sheetTheme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (statusLabel != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: statusColor, size: 10),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: sheetTheme.textTheme.labelMedium?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: statCard(
                              icon: Icons.attach_money,
                              label: l10n.price,
                              value: priceValue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: statCard(
                              icon: Icons.local_parking,
                              label: l10n.vacancies,
                              value: displayVacancyValue,
                            ),
                          ),
                        ],
                      ),
                      if (primaryRate != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _formatPrimaryRateSummary(primaryRate),
                          style: sheetTheme.textTheme.bodySmall?.copyWith(
                            color: sheetTheme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                      ],
                      if (c.photoUrl != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              c.photoUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: sheetTheme
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: sheetTheme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.image_not_supported,
                                          size: 32,
                                          color: sheetTheme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          l10n.photo_unavailable,
                                        ),
                                      ],
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      ],
                      if (vacancyEntries.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.vacancies,
                          style: sheetTheme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...visibleVacancies.map((entry) {
                          final lastUpdate = entry.value['lastupdate']
                              ?.toString();
                          final updateLabel =
                              (lastUpdate != null && lastUpdate.isNotEmpty)
                              ? ' (${l10n.updated}: $lastUpdate)'
                              : '';
                          final label = _formatVacancyKey(entry.key, l10n);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '$label: ${_formatVacancySummary(entry.value)}$updateLabel',
                              style: sheetTheme.textTheme.bodySmall,
                            ),
                          );
                        }),
                        if (vacancyEntries.length > 2)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => setSheetState(
                                () => showAllVacancies = !showAllVacancies,
                              ),
                              child: Text(
                                showAllVacancies
                                    ? l10n.show_fewer
                                    : l10n.show_all,
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        l10n.rates,
                        style: sheetTheme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (rates.isNotEmpty) ...[
                        ...visibleRates.map(
                          (rate) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildRateLine(rate),
                          ),
                        ),
                        if (rates.length > 2)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => setSheetState(
                                () => showAllRates = !showAllRates,
                              ),
                              child: Text(
                                showAllRates
                                    ? l10n.show_fewer
                                    : l10n.show_all,
                              ),
                            ),
                          ),
                      ] else ...[
                        Text(
                          l10n.no_pricing_info,
                          style: sheetTheme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _openNavigation(c);
                              },
                              icon: const Icon(Icons.directions),
                              label: Text(
                                l10n.navigate,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  String _localizedCarparkName(Carpark carpark) {
    switch (_language) {
      case AppLanguage.english:
        return carpark.nameEn.isNotEmpty ? carpark.nameEn : carpark.id;
      case AppLanguage.traditionalChinese:
        if (carpark.nameTc.isNotEmpty) return carpark.nameTc;
        return carpark.nameSc.isNotEmpty ? carpark.nameSc : carpark.id;
      case AppLanguage.simplifiedChinese:
        if (carpark.nameSc.isNotEmpty) return carpark.nameSc;
        return carpark.nameTc.isNotEmpty ? carpark.nameTc : carpark.id;
    }
  }

  String _localizedCarparkAddress(Carpark carpark) {
    switch (_language) {
      case AppLanguage.english:
        return carpark.addressEn;
      case AppLanguage.traditionalChinese:
        return carpark.addressTc.isNotEmpty
            ? carpark.addressTc
            : carpark.addressSc;
      case AppLanguage.simplifiedChinese:
        return carpark.addressSc.isNotEmpty
            ? carpark.addressSc
            : carpark.addressTc;
    }
  }


  String _formatVacancySummary(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final vacancyValue = data['vacancy'];
    final vacancy = (vacancyValue is num && vacancyValue >= 0)
        ? vacancyValue.toInt().toString()
        : l10n.na;
    final extras = <String>[];
    final type = data['vacancy_type']?.toString();
    if (type != null && type.isNotEmpty && type != 'Unknown') {
      extras.add(type);
    }
    final ev = data['vacancyEV'];
    if (ev is num && ev >= 0) {
      extras.add(l10n.vacancy_ev(ev.toInt()));
    }
    final disabled = data['vacancyDIS'];
    if (disabled is num && disabled >= 0) {
      extras.add(l10n.vacancy_disabled(disabled.toInt()));
    }
    if (extras.isEmpty) return vacancy;
    return '$vacancy - ${extras.join(' - ')}';
  }

  String _formatVacancyKey(String key, AppLocalizations l10n) {
    switch (key.toLowerCase()) {
      case 'privatecar':
      case 'private_car':
      case 'pc':
        return l10n.vacancy_type_private_car;
      case 'motorcycle':
      case 'motorcyclecar':
      case 'mc':
        return l10n.vacancy_type_motorcycle;
      case 'taxi':
        return l10n.vacancy_type_taxi;
      default:
        return key;
    }
  }

  Widget _buildRateLine(CarparkRate rate) {
    final price = _formatRatePrice(rate);
    final timeRange = _formatTimeRange(rate.periodStart, rate.periodEnd);
    final weekdays = _formatWeekdays(rate.weekdays, rate.excludePublicHoliday);
    final details = <String>[];
    final typeLabel = _formatRateType(rate.type);
    if (typeLabel.isNotEmpty && !_priceAlreadyIncludesType(rate.type)) {
      details.add(typeLabel);
    }
    if (timeRange.isNotEmpty) details.add(timeRange);
    if (weekdays.isNotEmpty) details.add(weekdays);
    if (rate.covered != null && rate.covered!.isNotEmpty) {
      details.add(rate.covered!.toUpperCase());
    }
    if (rate.usageMinimum != null) {
      details.add(
        AppLocalizations.of(context)!.rate_minimum_hours(rate.usageMinimum!),
      );
    }
    if (rate.reserved != null && rate.reserved!.isNotEmpty) {
      details.add(rate.reserved!);
    }
    if (rate.validUntil != null &&
        rate.validUntil!.isNotEmpty &&
        rate.validUntil != 'no-restrictions') {
      details.add(
        AppLocalizations.of(context)!.rate_valid_until(rate.validUntil!),
      );
    }
    if (rate.remark != null && rate.remark!.isNotEmpty) {
      details.add(rate.remark!);
    }

    final suffix = details.isNotEmpty ? ' | ${details.join(' | ')}' : '';
    return Text('$price$suffix', style: Theme.of(context).textTheme.bodySmall);
  }


  String _formatTimeRange(String? start, String? end) {
    if ((start == null || start.isEmpty) && (end == null || end.isEmpty)) {
      return '';
    }
    if (start != null && start.isNotEmpty && end != null && end.isNotEmpty) {
      return '$start-$end';
    }
    return start?.isNotEmpty == true ? start! : end ?? '';
  }


  String _formatWeekdays(List<String> weekdays, bool excludePublicHoliday) {
    final l10n = AppLocalizations.of(context)!;
    if (weekdays.isEmpty) {
      return excludePublicHoliday ? l10n.excluding_public_holidays : '';
    }

    const order = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final labels = {
      'MON': l10n.weekday_mon_short,
      'TUE': l10n.weekday_tue_short,
      'WED': l10n.weekday_wed_short,
      'THU': l10n.weekday_thu_short,
      'FRI': l10n.weekday_fri_short,
      'SAT': l10n.weekday_sat_short,
      'SUN': l10n.weekday_sun_short,
      'PH': l10n.public_holiday,
    };

    final normalized =
        weekdays
            .map((w) => w.toUpperCase())
            .where(order.contains)
            .toSet()
            .toList()
          ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    final hasPh = weekdays.any((w) => w.toUpperCase() == 'PH');
    final weekdaySet = {'MON', 'TUE', 'WED', 'THU', 'FRI'};
    final weekendSet = {'SAT', 'SUN'};

    final normalizedSet = normalized.toSet();
    final isWeekdaysOnly =
        normalizedSet.length == weekdaySet.length &&
        normalizedSet.containsAll(weekdaySet);
    final isWeekendOnly =
        normalizedSet.isNotEmpty &&
        normalizedSet.difference(weekendSet).isEmpty;

    if (isWeekdaysOnly) {
      return excludePublicHoliday ? l10n.weekdays_excluding_ph : l10n.weekdays;
    }
    if (isWeekendOnly) {
      if (hasPh && !excludePublicHoliday) return l10n.weekends_and_ph;
      if (hasPh && excludePublicHoliday) return l10n.weekends_excluding_ph;
      return l10n.weekends;
    }

    if (normalized.isEmpty && hasPh) {
      return l10n.public_holiday;
    }

    final ranges = <String>[];
    int i = 0;
    while (i < normalized.length) {
      final startIdx = order.indexOf(normalized[i]);
      int endIdx = startIdx;
      int j = i + 1;
      while (j < normalized.length &&
          order.indexOf(normalized[j]) == endIdx + 1) {
        endIdx = order.indexOf(normalized[j]);
        j++;
      }
      final startLabel = labels[order[startIdx]] ?? order[startIdx];
      final endLabel = labels[order[endIdx]] ?? order[endIdx];
      ranges.add(startIdx == endIdx ? startLabel : '$startLabel-$endLabel');
      i = j;
    }

    if (hasPh) {
      ranges.add(l10n.public_holiday);
    }

    final joined = ranges.join(', ');
    if (excludePublicHoliday) {
      return '$joined ${l10n.excluding_public_holiday_suffix}';
    }
    return joined;
  }


  CarparkRate? _findPrimaryRate(List<CarparkRate> rates) {
    final pricedRates = rates
        .where((r) => r.price != null && r.price! > 0)
        .toList();
    if (pricedRates.isEmpty) return null;
    pricedRates.sort((a, b) {
      final aHourly = a.type == 'hourly';
      final bHourly = b.type == 'hourly';
      if (aHourly != bHourly) {
        return aHourly ? -1 : 1;
      }
      return a.price!.compareTo(b.price!);
    });
    return pricedRates.first;
  }


  String _formatPrimaryRateSummary(CarparkRate rate) {
    final price = _formatRatePrice(rate);
    final timeRange = _formatTimeRange(rate.periodStart, rate.periodEnd);
    final weekdays = _formatWeekdays(rate.weekdays, rate.excludePublicHoliday);
    final typeLabel = _formatRateType(rate.type);
    final details = <String>[
      if (typeLabel.isNotEmpty && !_priceAlreadyIncludesType(rate.type)) typeLabel,
      if (timeRange.isNotEmpty) timeRange,
      if (weekdays.isNotEmpty) weekdays,
    ];
    final summary = AppLocalizations.of(context)!.rate_from_price(price);
    return details.isEmpty ? summary : '$summary (${details.join(' | ')})';
  }


  String _formatRatePrice(CarparkRate rate) {
    final l10n = AppLocalizations.of(context)!;
    final price = rate.price;
    if (price == null || price <= 0) {
      return l10n.no_price_information;
    }
    final formattedPrice = price % 1 == 0
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
    final base = 'HK\$$formattedPrice';

    String? suffix;
    switch (rate.type) {
      case 'hourly':
        suffix = l10n.rate_type_hourly;
        break;
      case '12-hour':
        suffix = l10n.rate_type_12_hour_parking;
        break;
      case '24-hour':
        suffix = l10n.rate_type_24_hour_parking;
        break;
      case 'monthly-park':
        suffix = l10n.rate_type_monthly;
        break;
      case 'night-park':
      case 'night-park (monthly)':
        suffix = l10n.rate_type_night;
        break;
      case 'day-park':
        suffix = l10n.rate_type_day;
        break;
      case 'dayNight':
      case 'day-night':
        suffix = l10n.rate_type_day_and_night;
        break;
      case 'day-pass':
        suffix = l10n.rate_type_day_pass;
        break;
      default:
        suffix = null;
    }
    return suffix == null ? base : '$base/$suffix';
  }

  String? _formatHourlyPriceShort(Carpark carpark) {
    final hourlyRates = carpark.privateCarRates.where(
      (rate) => rate.type == 'hourly' && (rate.price ?? 0) > 0,
    );
    final rate = hourlyRates.isNotEmpty ? hourlyRates.first : null;
    if (rate == null || rate.price == null || rate.price! <= 0) {
      return null;
    }
    final price = rate.price!;
    final formatted = price % 1 == 0
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
    return '\$$formatted';
  }



  bool _priceAlreadyIncludesType(String? type) {
    if (type == null || type.isEmpty) return false;
    switch (type) {
      case 'hourly':
      case '12-hour':
      case '24-hour':
      case 'monthly-park':
      case 'night-park':
      case 'night-park (monthly)':
      case 'day-park':
      case 'dayNight':
      case 'day-night':
      case 'day-pass':
        return true;
      default:
        return false;
    }
  }

  String _formatRateType(String? type) {
    if (type == null || type.isEmpty) return '';
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case 'hourly':
        return l10n.rate_type_hourly;
      case '12-hour':
        return l10n.rate_type_12_hour_parking;
      case '24-hour':
        return l10n.rate_type_24_hour_parking;
      case 'monthly-park':
        return l10n.rate_type_monthly;
      case 'night-park':
        return l10n.rate_type_night;
      case 'day-park':
        return l10n.rate_type_day;
      case 'dayNight':
      case 'day-night':
        return l10n.rate_type_day_and_night;
      case 'day-pass':
        return l10n.rate_type_day_pass;
      default:
        final normalized = type.replaceAll('-', ' ').replaceAll('_', ' ');
        return normalized.isNotEmpty
            ? normalized[0].toUpperCase() + normalized.substring(1)
            : '';
    }
  }


  String? _formatOpeningStatusLabel(String? status) {
    if (status == null) return null;
    final trimmed = status.trim();
    if (trimmed.isEmpty) return null;
    final upper = trimmed.toUpperCase();
    final l10n = AppLocalizations.of(context)!;
    if (upper == 'OPEN') {
      return l10n.carpark_status_open;
    }
    if (upper == 'CLOSED') {
      return l10n.carpark_status_closed;
    }
    final normalized = trimmed.replaceAll('_', ' ');
    final formatted = normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
    return formatted.isEmpty ? trimmed : formatted;
  }


  Color _resolveOpeningStatusColor(String? status, Color fallback) {
    if (status == null) return fallback;
    final normalized = status.trim().toUpperCase();
    if (normalized == 'OPEN') {
      return fallback;
    }
    if (normalized.contains('CLOSE')) {
      return Colors.red.shade600;
    }
    return fallback;
  }


}





