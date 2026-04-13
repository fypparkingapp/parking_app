part of 'carpark_search_delegate.dart';

const List<LocalPoiCategory> _poiCategoryOrder = [
  LocalPoiCategory.districtLocality,
  LocalPoiCategory.residentialHousing,
  LocalPoiCategory.education,
  LocalPoiCategory.transportation,
  LocalPoiCategory.shoppingRetail,
  LocalPoiCategory.businessOffice,
  LocalPoiCategory.diningFood,
  LocalPoiCategory.medicalHealth,
  LocalPoiCategory.governmentPublic,
  LocalPoiCategory.cultureLeisure,
  LocalPoiCategory.religionSocialService,
  LocalPoiCategory.naturalLandscape,
];

class _PoiCategoryVisual {
  const _PoiCategoryVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

extension _CarparkSearchSections on CarparkSearchDelegate {
  List<Widget> _intersperse(List<Widget> items, Widget separator) {
    if (items.isEmpty) return const [];
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(separator);
      }
    }
    return out;
  }

  List<Widget> _withDividers(List<Widget> rows) {
    if (rows.isEmpty) return const [];
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      out.add(rows[i]);
      if (i != rows.length - 1) {
        out.add(const Divider(height: 1));
      }
    }
    return out;
  }

  Widget _buildLocationHeader(BuildContext context, GeocodingResult location) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title = _locationPrimaryText(location);
    final subtitle = _locationSecondaryText(location);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.nearby, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _useDarkSurface ? Colors.white70 : null,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _useDarkSurface ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSavedPlacesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    final chips = <Widget>[
      for (final place in _savedPlaces) _buildSavedPlaceChip(context, place),
      _buildAddPlaceChip(context),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_savedPlaces.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l10n.saved_places, style: labelStyle),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _intersperse(chips, const SizedBox(width: 8))),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPlaceChip(BuildContext context, SavedPlace place) {
    final label = place.label.isNotEmpty ? place.label : place.displayName;
    final isDefaultLabel = place.label.trim().isEmpty;
    final defaultColor = _useDarkSurface ? Colors.white60 : Colors.black54;
    return GestureDetector(
      onLongPress: () => _showEditPlaceDialog(context, place),
      child: InputChip(
        avatar: const Icon(Icons.place, size: 18),
        label: Text(
          label,
          style: isDefaultLabel ? TextStyle(color: defaultColor) : null,
        ),
        onPressed: () {
          final savedCarparkId = place.carparkId;
          if (savedCarparkId != null && savedCarparkId.isNotEmpty) {
            if (savedCarparkId.startsWith('metered:')) {
              final meteredKey = savedCarparkId.substring('metered:'.length);
              for (final group in meteredGroups) {
                if (group.key != meteredKey) continue;
                close(
                  context,
                  CarparkSearchSelection.metered(meteredGroup: group),
                );
                return;
              }
            }
            for (final carpark in allCarparks) {
              if (carpark.id != savedCarparkId) continue;
              close(
                context,
                CarparkSearchSelection.carpark(
                  carpark: carpark,
                  showDetails: true,
                  setAsDestination: false,
                ),
              );
              return;
            }
          }
          for (final group in meteredGroups) {
            final latDiff = (group.center.latitude - place.latitude).abs();
            final lngDiff = (group.center.longitude - place.longitude).abs();
            if (latDiff > 0.00001 || lngDiff > 0.00001) continue;
            close(context, CarparkSearchSelection.metered(meteredGroup: group));
            return;
          }
          for (final carpark in allCarparks) {
            final latDiff = (carpark.latitude - place.latitude).abs();
            final lngDiff = (carpark.longitude - place.longitude).abs();
            if (latDiff > 0.00001 || lngDiff > 0.00001) continue;
            close(
              context,
              CarparkSearchSelection.carpark(
                carpark: carpark,
                showDetails: true,
                setAsDestination: false,
              ),
            );
            return;
          }
          close(
            context,
            CarparkSearchSelection.location(
              location: place.toGeocodingResult(),
            ),
          );
        },
        onDeleted: () => _removeSavedPlace(place),
      ),
    );
  }

  Widget _buildAddPlaceChip(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ActionChip(
      avatar: const Icon(Icons.add, size: 18),
      label: Text(l10n.add_place),
      onPressed: () => _showAddPlaceDialog(context),
    );
  }

  Widget _buildLocationTile(BuildContext context, GeocodingResult location) {
    final theme = Theme.of(context);
    final title = _locationPrimaryText(location);
    final subtitle = _locationSecondaryText(location);
    final district = _locationDistrictText(location);
    final visual = _poiCategoryVisual(theme, location.category);
    final categoryLabel = location.category == null
        ? null
        : _poiCategoryLabel(location.category!);
    return ListTile(
      leading: _buildLocationLeadingIcon(context, visual),
      title: Text(title),
      subtitle: (subtitle != null || district != null || categoryLabel != null)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitle != null)
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (district != null)
                  Text(district, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (categoryLabel != null) ...[
                  const SizedBox(height: 6),
                  _buildLocationCategoryBadge(
                    context,
                    label: categoryLabel,
                    visual: visual,
                  ),
                ],
              ],
            )
          : null,
      onTap: () {
        close(context, CarparkSearchSelection.location(location: location));
      },
    );
  }

  String _locationPrimaryText(GeocodingResult location) {
    if (appLanguage.prefersChinese) {
      return location.nameZh ?? location.displayName;
    }
    return location.nameEn ?? location.displayName;
  }

  String? _locationSecondaryText(GeocodingResult location) {
    if (appLanguage == AppLanguage.english) {
      return null;
    }
    final secondary = appLanguage.prefersChinese
        ? location.nameEn
        : location.nameZh;
    if (secondary == null || secondary.isEmpty) {
      return null;
    }
    final primary = _locationPrimaryText(location);
    return secondary == primary ? null : secondary;
  }

  String? _locationDistrictText(GeocodingResult location) {
    final district = appLanguage.prefersChinese
        ? location.districtZh
        : location.districtEn;
    if (district == null || district.isEmpty) return null;
    final secondary = _locationSecondaryText(location);
    if (secondary != null && secondary == district) return null;
    return district;
  }

  String _poiCategoryLabel(LocalPoiCategory category) {
    switch (category) {
      case LocalPoiCategory.districtLocality:
        return appLanguage.prefersChinese ? '地區地名' : 'Area';
      case LocalPoiCategory.residentialHousing:
        return appLanguage.prefersChinese ? '住宅住屋' : 'Residential';
      case LocalPoiCategory.education:
        return appLanguage.prefersChinese ? '教育' : 'Education';
      case LocalPoiCategory.transportation:
        return appLanguage.prefersChinese ? '交通' : 'Transport';
      case LocalPoiCategory.shoppingRetail:
        return appLanguage.prefersChinese ? '商場零售' : 'Retail';
      case LocalPoiCategory.businessOffice:
        return appLanguage.prefersChinese ? '商業辦公' : 'Office';
      case LocalPoiCategory.diningFood:
        return appLanguage.prefersChinese ? '餐飲' : 'Dining';
      case LocalPoiCategory.medicalHealth:
        return appLanguage.prefersChinese ? '醫療健康' : 'Medical';
      case LocalPoiCategory.governmentPublic:
        return appLanguage.prefersChinese ? '政府公共' : 'Government';
      case LocalPoiCategory.cultureLeisure:
        return appLanguage.prefersChinese ? '文化休閒' : 'Leisure';
      case LocalPoiCategory.religionSocialService:
        return appLanguage.prefersChinese ? '宗教社福' : 'Community';
      case LocalPoiCategory.naturalLandscape:
        return appLanguage.prefersChinese ? '自然地貌' : 'Nature';
    }
  }

  String _otherPlacesLabel() {
    return appLanguage.prefersChinese ? '其他地點' : 'Other places';
  }

  String _emptySearchResultsLabel(AppLocalizations l10n) =>
      l10n.no_matching_car_parks;

  _PoiCategoryVisual _poiCategoryVisual(
    ThemeData theme,
    LocalPoiCategory? category,
  ) {
    switch (category) {
      case LocalPoiCategory.districtLocality:
        return const _PoiCategoryVisual(
          icon: Icons.location_city_rounded,
          color: Color(0xFF0F766E),
        );
      case LocalPoiCategory.residentialHousing:
        return const _PoiCategoryVisual(
          icon: Icons.apartment_rounded,
          color: Color(0xFF8B5E3C),
        );
      case LocalPoiCategory.education:
        return const _PoiCategoryVisual(
          icon: Icons.school_rounded,
          color: Color(0xFF1D4ED8),
        );
      case LocalPoiCategory.transportation:
        return const _PoiCategoryVisual(
          icon: Icons.train_rounded,
          color: Color(0xFF0284C7),
        );
      case LocalPoiCategory.shoppingRetail:
        return const _PoiCategoryVisual(
          icon: Icons.shopping_bag_rounded,
          color: Color(0xFFE11D48),
        );
      case LocalPoiCategory.businessOffice:
        return const _PoiCategoryVisual(
          icon: Icons.business_center_rounded,
          color: Color(0xFF475569),
        );
      case LocalPoiCategory.diningFood:
        return const _PoiCategoryVisual(
          icon: Icons.restaurant_rounded,
          color: Color(0xFFEA580C),
        );
      case LocalPoiCategory.medicalHealth:
        return const _PoiCategoryVisual(
          icon: Icons.local_hospital_rounded,
          color: Color(0xFF16A34A),
        );
      case LocalPoiCategory.governmentPublic:
        return const _PoiCategoryVisual(
          icon: Icons.account_balance_rounded,
          color: Color(0xFF2563EB),
        );
      case LocalPoiCategory.cultureLeisure:
        return const _PoiCategoryVisual(
          icon: Icons.museum_rounded,
          color: Color(0xFFC2410C),
        );
      case LocalPoiCategory.religionSocialService:
        return const _PoiCategoryVisual(
          icon: Icons.volunteer_activism_rounded,
          color: Color(0xFF7C3AED),
        );
      case LocalPoiCategory.naturalLandscape:
        return const _PoiCategoryVisual(
          icon: Icons.terrain_rounded,
          color: Color(0xFF15803D),
        );
      case null:
        return _PoiCategoryVisual(
          icon: Icons.place_rounded,
          color: theme.colorScheme.primary,
        );
    }
  }

  Widget _buildLocationLeadingIcon(
    BuildContext context,
    _PoiCategoryVisual visual,
  ) {
    final background = _useDarkSurface
        ? visual.color.withValues(alpha: 0.24)
        : visual.color.withValues(alpha: 0.12);
    final foreground = _useDarkSurface ? Colors.white : visual.color;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(visual.icon, color: foreground, size: 20),
    );
  }

  Widget _buildResultList(
    BuildContext context, {
    Widget? savedSection,
    required Widget filterRow,
    required List<Widget> rows,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (savedSection != null) savedSection,
        if (savedSection != null) const Divider(height: 1),
        filterRow,
        const Divider(height: 1),
        ..._withDividers(rows),
      ],
    );
  }

  List<Widget> _buildLocationSections(
    BuildContext context,
    List<GeocodingResult> locations,
  ) {
    if (locations.isEmpty) return const [];

    final grouped = <LocalPoiCategory?, List<GeocodingResult>>{};
    for (final location in locations) {
      grouped.putIfAbsent(location.category, () => []).add(location);
    }

    final orderedCategories = <LocalPoiCategory?>[
      ..._poiCategoryOrder.where(grouped.containsKey),
      if (grouped.containsKey(null)) null,
    ];

    final rows = <Widget>[];
    for (final category in orderedCategories) {
      final group = grouped[category];
      if (group == null || group.isEmpty) continue;
      final title = category == null
          ? _otherPlacesLabel()
          : _poiCategoryLabel(category);
      final visual = _poiCategoryVisual(Theme.of(context), category);
      rows.add(
        _buildSectionHeader(
          context,
          title: '$title (${group.length})',
          onClear: null,
          icon: visual.icon,
          iconColor: visual.color,
          iconBackgroundColor: _useDarkSurface
              ? visual.color.withValues(alpha: 0.24)
              : visual.color.withValues(alpha: 0.12),
        ),
      );
      rows.addAll(
        group.map((location) => _buildLocationTile(context, location)),
      );
    }
    return rows;
  }

  Widget _buildLocationCategoryBadge(
    BuildContext context, {
    required String label,
    required _PoiCategoryVisual visual,
  }) {
    final foreground = _useDarkSurface ? Colors.white : visual.color;
    final background = _useDarkSurface
        ? visual.color.withValues(alpha: 0.22)
        : visual.color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required VoidCallback? onClear,
    IconData? icon,
    Color? iconColor,
    Color? iconBackgroundColor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBackgroundColor ?? Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 8),
          ],
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          if (onClear != null)
            TextButton(onPressed: onClear, child: Text(l10n.clear)),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chips = <SearchFilter, String>{
      SearchFilter.all: l10n.show_all,
      SearchFilter.parking: l10n.carpark,
      SearchFilter.metered: l10n.metered_parking,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        children: chips.entries.map((entry) {
          final selected = _filter == entry.key;
          return ChoiceChip(
            label: Text(entry.value),
            selected: selected,
            onSelected: (value) {
              if (!value) return;
              _filter = entry.key;
              _refreshSignal.value++;
              showSuggestions(context);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMeteredTile(
    BuildContext context,
    MeteredStreetGroup group, {
    IconData leadingIcon = Icons.local_parking,
    bool showSaveButton = false,
  }) {
    final title = meteredTitleBuilder(group);
    final subtitle = meteredSubtitleBuilder(group);
    final statusColor = statusColorBuilder(
      group.hasVacancy ? 'open' : 'closed',
    );
    final trailingWidgets = <Widget>[Text('${group.vacant}/${group.total}')];
    if (showSaveButton) {
      trailingWidgets.addAll([
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.bookmark_add_outlined),
          tooltip: AppLocalizations.of(context)!.save_place,
          onPressed: () => _showSaveCarparkDialog(
            context,
            _meteredAsCarpark(group),
            title: title,
            subtitle: subtitle,
          ),
        ),
      ]);
    }
    return ListTile(
      leading: Icon(leadingIcon, color: statusColor),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: trailingWidgets),
      onTap: () =>
          close(context, CarparkSearchSelection.metered(meteredGroup: group)),
    );
  }

  Carpark _meteredAsCarpark(MeteredStreetGroup group) {
    String resolveTitle(String street, String section, String fallbackStreet) {
      final s = street.isNotEmpty ? street : fallbackStreet;
      if (section.isNotEmpty) return '$s · $section';
      return s;
    }

    return Carpark(
      id: 'metered:${group.key}',
      nameEn: resolveTitle(group.streetEn, group.sectionEn, group.streetEn),
      nameTc: resolveTitle(group.streetTc, group.sectionTc, group.streetEn),
      nameSc: resolveTitle(group.streetSc, group.sectionSc, group.streetEn),
      addressEn: group.districtEn,
      addressTc: group.districtTc,
      addressSc: group.districtSc,
      latitude: group.center.latitude,
      longitude: group.center.longitude,
      operatorName: 'Metered',
    );
  }

  Widget _buildCarparkTile(
    BuildContext context,
    Carpark carpark, {
    required IconData leadingIcon,
    required bool showDetails,
    bool setAsDestination = true,
  }) {
    final title = titleBuilder(carpark);
    final subtitle = subtitleBuilder(carpark);
    final leadingColor = leadingIcon == Icons.star
        ? accentColor
        : statusColorBuilder(carpark.openingStatus);
    final hourlyPrice = _formatHourlyPriceShort(carpark);

    final trailingWidgets = <Widget>[
      if (hourlyPrice != null) ...[Text(hourlyPrice), const SizedBox(width: 8)],
      IconButton(
        icon: const Icon(Icons.bookmark_add_outlined),
        tooltip: AppLocalizations.of(context)!.save_place,
        onPressed: () => _showSaveCarparkDialog(
          context,
          carpark,
          title: title,
          subtitle: subtitle,
        ),
      ),
    ];

    return ListTile(
      leading: Icon(leadingIcon, color: leadingColor),
      title: Text(title),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: trailingWidgets),
      onTap: () {
        close(
          context,
          CarparkSearchSelection.carpark(
            carpark: carpark,
            showDetails: showDetails,
            setAsDestination: setAsDestination,
          ),
        );
      },
    );
  }

  String? _formatHourlyPriceShort(Carpark carpark) {
    final hourlyRates = carpark.privateCarRates.where(
      (rate) =>
          (rate.type == 'hourly' || rate.type == 'half-hourly') &&
          (rate.price ?? 0) > 0,
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

  Future<void> _showAddPlaceDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final queryController = TextEditingController(text: query.trim());
    final theme = Theme.of(context);
    final isDark = _useDarkSurface;
    final dialogTextColor = isDark ? Colors.white : null;
    final dialogHintColor = isDark ? Colors.white60 : null;
    final dialogBackground = isDark ? const Color(0xFF1C1F24) : null;

    final input = await showDialog<_AddPlaceInput>(
      context: context,
      builder: (dialogContext) {
        return _AddPlaceDialog(
          l10n: l10n,
          theme: theme,
          appLanguage: appLanguage,
          nameController: nameController,
          queryController: queryController,
          geocodingService: geocodingService,
          geocodingFallbackLabel: _geocodingFallbackLabel,
          accentColor: accentColor,
          dialogBackground: dialogBackground,
          dialogTextColor: dialogTextColor,
          dialogHintColor: dialogHintColor,
          isDark: isDark,
        );
      },
    );
    if (input == null) return;
    GeocodingResult? location;
    final trimmedQuery = input.query.trim();
    if (input.location != null && input.location!.displayName == trimmedQuery) {
      location = input.location;
    } else {
      final results = await geocodingService.geocodeMany(
        input.query,
        limit: 1,
        fallbackLabel: _geocodingFallbackLabel,
      );
      if (results.isNotEmpty) {
        location = results.first;
      }
    }
    if (!context.mounted) return;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location found for that search.')),
      );
      return;
    }
    final place = SavedPlace(
      label: input.label,
      displayName: '${input.label} - ${location.displayName}',
      latitude: location.latitude,
      longitude: location.longitude,
    );
    await _addSavedPlace(place);
  }

  Future<void> _showSaveCarparkDialog(
    BuildContext context,
    Carpark carpark, {
    required String title,
    required String subtitle,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final theme = Theme.of(context);
    final isDark = _useDarkSurface;
    final dialogTextColor = isDark ? Colors.white : null;
    final dialogHintColor = isDark ? Colors.white60 : null;
    final dialogBackground = isDark ? const Color(0xFF1C1F24) : null;
    final defaultLabel = title;

    final saved = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBackground,
          title: Text(l10n.save_place),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: dialogHintColor,
                  ),
                ),
              if (subtitle.isNotEmpty) const SizedBox(height: 8),
              Text(
                l10n.place_edit_name_hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: dialogHintColor,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: TextStyle(color: dialogTextColor),
                decoration: InputDecoration(
                  labelText: l10n.place_name,
                  hintText: defaultLabel,
                  labelStyle: TextStyle(color: dialogHintColor),
                  hintStyle: TextStyle(color: dialogHintColor),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                l10n.cancel,
                style: TextStyle(color: isDark ? Colors.white70 : null),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(nameController.text.trim());
              },
              child: Text(
                l10n.save,
                style: theme.textTheme.labelLarge?.copyWith(color: accentColor),
              ),
            ),
          ],
        );
      },
    );
    if (saved == null) return;
    final label = saved.isEmpty ? defaultLabel : saved;
    final displayName = label;
    final place = SavedPlace(
      label: label,
      displayName: displayName,
      latitude: carpark.latitude,
      longitude: carpark.longitude,
      carparkId: carpark.id,
    );
    await _addSavedPlace(place);
  }

  Future<void> _showEditPlaceDialog(
    BuildContext context,
    SavedPlace place,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final locationLabel = _extractLocationLabel(place);
    final nameController = TextEditingController(text: place.label);
    final queryController = TextEditingController(text: locationLabel);
    final theme = Theme.of(context);
    final isDark = _useDarkSurface;
    final dialogTextColor = isDark ? Colors.white : null;
    final dialogHintColor = isDark ? Colors.white60 : null;
    final dialogBackground = isDark ? const Color(0xFF1C1F24) : null;

    final input = await showDialog<_AddPlaceInput>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBackground,
          title: Text(l10n.add_place),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: dialogTextColor),
                decoration: InputDecoration(
                  labelText: l10n.place_name,
                  hintText: l10n.place_name_hint,
                  labelStyle: TextStyle(color: dialogHintColor),
                  hintStyle: TextStyle(color: dialogHintColor),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: queryController,
                style: TextStyle(color: dialogTextColor),
                decoration: InputDecoration(
                  labelText: l10n.place_location,
                  hintText: l10n.place_location_hint,
                  labelStyle: TextStyle(color: dialogHintColor),
                  hintStyle: TextStyle(color: dialogHintColor),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                l10n.cancel,
                style: TextStyle(color: isDark ? Colors.white70 : null),
              ),
            ),
            TextButton(
              onPressed: () {
                final label = nameController.text.trim();
                final placeQuery = queryController.text.trim();
                if (label.isEmpty || placeQuery.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(l10n.place_missing_info)),
                  );
                  return;
                }
                Navigator.of(
                  dialogContext,
                ).pop(_AddPlaceInput(label: label, query: placeQuery));
              },
              child: Text(
                l10n.save,
                style: theme.textTheme.labelLarge?.copyWith(color: accentColor),
              ),
            ),
          ],
        );
      },
    );
    if (input == null) return;
    final results = await geocodingService.geocodeMany(
      input.query,
      limit: 1,
      fallbackLabel: _geocodingFallbackLabel,
    );
    if (!context.mounted) return;
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location found for that search.')),
      );
      return;
    }
    final location = results.first;
    final next = SavedPlace(
      label: input.label,
      displayName: '${input.label} - ${location.displayName}',
      latitude: location.latitude,
      longitude: location.longitude,
    );
    await _removeSavedPlace(place);
    await _addSavedPlace(next);
  }

  String _extractLocationLabel(SavedPlace place) {
    final label = place.label.trim();
    if (label.isEmpty) return place.displayName;
    final prefix = '$label - ';
    if (place.displayName.startsWith(prefix)) {
      return place.displayName.substring(prefix.length);
    }
    return place.displayName;
  }

  Future<void> _addSavedPlace(SavedPlace place) async {
    final labelKey = place.label.trim().toLowerCase();
    _savedPlaces = [
      place,
      ..._savedPlaces.where(
        (item) => item.label.trim().toLowerCase() != labelKey,
      ),
    ];
    _refreshSignal.value++;
    await onAddSavedPlace(place);
  }

  Future<void> _removeSavedPlace(SavedPlace place) async {
    final labelKey = place.label.trim().toLowerCase();
    _savedPlaces = _savedPlaces
        .where((item) => item.label.trim().toLowerCase() != labelKey)
        .toList();
    _refreshSignal.value++;
    await onRemoveSavedPlace(place);
  }
}

class _AddPlaceDialog extends StatefulWidget {
  const _AddPlaceDialog({
    required this.l10n,
    required this.theme,
    required this.appLanguage,
    required this.nameController,
    required this.queryController,
    required this.geocodingService,
    required this.geocodingFallbackLabel,
    required this.accentColor,
    required this.dialogBackground,
    required this.dialogTextColor,
    required this.dialogHintColor,
    required this.isDark,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final AppLanguage appLanguage;
  final TextEditingController nameController;
  final TextEditingController queryController;
  final GeocodingService geocodingService;
  final String geocodingFallbackLabel;
  final Color accentColor;
  final Color? dialogBackground;
  final Color? dialogTextColor;
  final Color? dialogHintColor;
  final bool isDark;

  @override
  State<_AddPlaceDialog> createState() => _AddPlaceDialogState();
}

class _AddPlaceDialogState extends State<_AddPlaceDialog> {
  static const int _maxLocationResults = 5;
  static const Duration _searchDebounce = Duration(milliseconds: 300);

  final List<GeocodingResult> _suggestions = [];
  Timer? _searchTimer;
  bool _isSearching = false;
  GeocodingResult? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _scheduleSearch(widget.queryController.text);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _selectedLocation = null;
    _scheduleSearch(value);
  }

  void _scheduleSearch(String rawQuery) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () async {
      final query = rawQuery.trim();
      if (query.isEmpty) {
        if (!mounted) return;
        setState(() {
          _suggestions.clear();
          _isSearching = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() => _isSearching = true);
      final results = await widget.geocodingService.geocodeMany(
        query,
        limit: _maxLocationResults,
        fallbackLabel: widget.geocodingFallbackLabel,
      );
      if (!mounted) return;
      setState(() {
        _suggestions
          ..clear()
          ..addAll(results);
        _isSearching = false;
      });
    });
  }

  void _selectLocation(GeocodingResult location) {
    widget.queryController.text = location.displayName;
    widget.queryController.selection = TextSelection.collapsed(
      offset: widget.queryController.text.length,
    );
    setState(() {
      _selectedLocation = location;
      _isSearching = false;
      _suggestions.clear();
    });
  }

  void _submit() {
    final label = widget.nameController.text.trim();
    final placeQuery = widget.queryController.text.trim();
    if (label.isEmpty || placeQuery.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.l10n.place_missing_info)));
      return;
    }
    Navigator.of(context).pop(
      _AddPlaceInput(
        label: label,
        query: placeQuery,
        location: _selectedLocation,
      ),
    );
  }

  String _locationPrimaryText(GeocodingResult location) {
    if (widget.appLanguage.prefersChinese) {
      return location.nameZh ?? location.displayName;
    }
    return location.nameEn ?? location.displayName;
  }

  String? _locationSecondaryText(GeocodingResult location) {
    if (widget.appLanguage == AppLanguage.english) {
      return null;
    }
    final secondary = widget.appLanguage.prefersChinese
        ? location.nameEn
        : location.nameZh;
    if (secondary == null || secondary.isEmpty) return null;
    return secondary == _locationPrimaryText(location) ? null : secondary;
  }

  String? _locationDistrictText(GeocodingResult location) {
    final district = widget.appLanguage.prefersChinese
        ? location.districtZh
        : location.districtEn;
    if (district == null || district.isEmpty) return null;
    final secondary = _locationSecondaryText(location);
    if (secondary != null && secondary == district) return null;
    return district;
  }

  String? _locationCategoryLabel(LocalPoiCategory? category) {
    if (category == null) return null;
    switch (category) {
      case LocalPoiCategory.districtLocality:
        return widget.appLanguage.prefersChinese ? '地區地名' : 'Area';
      case LocalPoiCategory.residentialHousing:
        return widget.appLanguage.prefersChinese ? '住宅住屋' : 'Residential';
      case LocalPoiCategory.education:
        return widget.appLanguage.prefersChinese ? '教育' : 'Education';
      case LocalPoiCategory.transportation:
        return widget.appLanguage.prefersChinese ? '交通' : 'Transport';
      case LocalPoiCategory.shoppingRetail:
        return widget.appLanguage.prefersChinese ? '商場零售' : 'Retail';
      case LocalPoiCategory.businessOffice:
        return widget.appLanguage.prefersChinese ? '商業辦公' : 'Office';
      case LocalPoiCategory.diningFood:
        return widget.appLanguage.prefersChinese ? '餐飲' : 'Dining';
      case LocalPoiCategory.medicalHealth:
        return widget.appLanguage.prefersChinese ? '醫療健康' : 'Medical';
      case LocalPoiCategory.governmentPublic:
        return widget.appLanguage.prefersChinese ? '政府公共' : 'Government';
      case LocalPoiCategory.cultureLeisure:
        return widget.appLanguage.prefersChinese ? '文化休閒' : 'Leisure';
      case LocalPoiCategory.religionSocialService:
        return widget.appLanguage.prefersChinese ? '宗教社福' : 'Community';
      case LocalPoiCategory.naturalLandscape:
        return widget.appLanguage.prefersChinese ? '自然地貌' : 'Nature';
    }
  }

  Widget? _buildSuggestionSubtitle(GeocodingResult location) {
    final secondary = _locationSecondaryText(location);
    final district = _locationDistrictText(location);
    final categoryLabel = _locationCategoryLabel(location.category);
    if (secondary == null && district == null && categoryLabel == null) {
      return null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (secondary != null)
          Text(secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (district != null)
          Text(district, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (categoryLabel != null)
          Padding(
            padding: EdgeInsets.only(
              top: (secondary == null && district == null) ? 0 : 4,
            ),
            child: Text(
              categoryLabel,
              style: widget.theme.textTheme.labelSmall?.copyWith(
                color: widget.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.dialogBackground,
      title: Text(widget.l10n.add_place),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.nameController,
            style: TextStyle(color: widget.dialogTextColor),
            decoration: InputDecoration(
              labelText: widget.l10n.place_name,
              hintText: widget.l10n.place_name_hint,
              labelStyle: TextStyle(color: widget.dialogHintColor),
              hintStyle: TextStyle(color: widget.dialogHintColor),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.queryController,
            style: TextStyle(color: widget.dialogTextColor),
            decoration: InputDecoration(
              labelText: widget.l10n.place_location,
              hintText: widget.l10n.place_location_hint,
              labelStyle: TextStyle(color: widget.dialogHintColor),
              hintStyle: TextStyle(color: widget.dialogHintColor),
            ),
            onChanged: _onQueryChanged,
          ),
          if (_isSearching) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Material(
              color: widget.dialogBackground ?? Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _suggestions.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.place, size: 20),
                      title: Text(_locationPrimaryText(_suggestions[i])),
                      subtitle: _buildSuggestionSubtitle(_suggestions[i]),
                      onTap: () => _selectLocation(_suggestions[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            widget.l10n.cancel,
            style: TextStyle(color: widget.isDark ? Colors.white70 : null),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.l10n.save,
            style: widget.theme.textTheme.labelLarge?.copyWith(
              color: widget.accentColor,
            ),
          ),
        ),
      ],
    );
  }
}
