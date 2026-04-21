part of 'appmain.dart';

const int _kSmartNavigationStayHours = 3;

extension _HomeScreenSmartNavigation on _HomeScreenState {
  static const List<String> _kWeekdaysMonToFri = <String>[
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
  ];
  static const List<String> _kWeekdaysMonToSat = <String>[
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
  ];
  static const List<String> _kWeekdaysAll = <String>[
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];
  static const double _kMeteredHourlyEstimateHkd = 8;
  static const int _kMeteredSmartCandidateLimit = 8;

  LatLng? _resolveSmartNavigationDestination() {
    if (_searchLocationMarker != null) return _searchLocationMarker;
    final destination = _routeDestination;
    if (destination == null) return null;
    final id = destination.id;
    if (id.startsWith('manual:') || id.startsWith('metered:')) {
      return LatLng(destination.latitude, destination.longitude);
    }
    return null;
  }

  String _smartNavigationTooltip() {
    switch (_language) {
      case AppLanguage.english:
        return 'Smart navigation';
      case AppLanguage.traditionalChinese:
        return '智能導航';
      case AppLanguage.simplifiedChinese:
        return '智能导航';
    }
  }

  String _smartNavigationButtonLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Smart';
      case AppLanguage.traditionalChinese:
        return '智慧導航';
      case AppLanguage.simplifiedChinese:
        return '智慧导航';
    }
  }

  String _smartNavigationUnavailableMessage() {
    switch (_language) {
      case AppLanguage.english:
        return 'Select a destination first.';
      case AppLanguage.traditionalChinese:
        return '請先選擇目的地。';
      case AppLanguage.simplifiedChinese:
        return '请先选择目的地。';
    }
  }

  String _smartNavigationFailedMessage() {
    switch (_language) {
      case AppLanguage.english:
        return 'Unable to find a suitable nearby carpark.';
      case AppLanguage.traditionalChinese:
        return '暫時找不到合適的附近停車場。';
      case AppLanguage.simplifiedChinese:
        return '暂时找不到合适的附近停车场。';
    }
  }

  String _smartNavigationSelectedMessage(SmartNavigationOption option) {
    final name = _carparkDisplayName(option.carpark);
    final probability = (option.vacancyProbability * 100).round();
    final isHighRisk = SmartNavigationService.isHighRiskOption(option);
    switch (_language) {
      case AppLanguage.english:
        if (isHighRisk) {
          return 'Selected high-risk fallback $name · ${option.travelMinutes} min · vacancy $probability%';
        }
        return 'Selected $name · ${option.travelMinutes} min · vacancy $probability%';
      case AppLanguage.traditionalChinese:
        if (isHighRisk) {
          return '已選擇高風險備選 $name · 約 ${option.travelMinutes} 分鐘 · 空位機率 $probability%';
        }
        return '已選擇 $name · 約 ${option.travelMinutes} 分鐘 · 空位機率 $probability%';
      case AppLanguage.simplifiedChinese:
        if (isHighRisk) {
          return '已选择高风险备选 $name · 约 ${option.travelMinutes} 分钟 · 空位机率 $probability%';
        }
        return '已选择 $name · 约 ${option.travelMinutes} 分钟 · 空位机率 $probability%';
    }
  }

  String _smartNavigationSummaryTitle() {
    switch (_language) {
      case AppLanguage.english:
        return 'Smart navigation';
      case AppLanguage.traditionalChinese:
        return '智慧導航建議';
      case AppLanguage.simplifiedChinese:
        return '智慧导航建议';
    }
  }

  String _smartNavigationStartLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Start now';
      case AppLanguage.traditionalChinese:
        return '立即開始導航';
      case AppLanguage.simplifiedChinese:
        return '立即开始导航';
    }
  }

  String _smartNavigationAlternativesLabel(bool expanded) {
    switch (_language) {
      case AppLanguage.english:
        return expanded ? 'Hide alternatives' : 'See other suggestions';
      case AppLanguage.traditionalChinese:
        return expanded ? '隱藏其他建議' : '看其他建議';
      case AppLanguage.simplifiedChinese:
        return expanded ? '隐藏其他建议' : '看其他建议';
    }
  }

  String _smartNavigationWhyLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Why this one';
      case AppLanguage.traditionalChinese:
        return '推薦原因';
      case AppLanguage.simplifiedChinese:
        return '推荐原因';
    }
  }

  String _smartNavigationAiStatusText(
    SmartNavigationResult result,
    SmartNavigationOption option,
  ) {
    final confidence = (option.aiConfidence * 100).round();
    switch (_language) {
      case AppLanguage.english:
        if (result.aiPersonalized) {
          return 'AI learned from ${result.aiLearningSamples} choices · confidence $confidence%';
        }
        return 'AI starter model · confidence $confidence%';
      case AppLanguage.traditionalChinese:
        if (result.aiPersonalized) {
          return 'AI 已學習 ${result.aiLearningSamples} 次選擇 · 信心 $confidence%';
        }
        return 'AI 初始模型 · 信心 $confidence%';
      case AppLanguage.simplifiedChinese:
        if (result.aiPersonalized) {
          return 'AI 已学习 ${result.aiLearningSamples} 次选择 · 信心 $confidence%';
        }
        return 'AI 初始模型 · 信心 $confidence%';
    }
  }

  String _smartNavigationAiBadgeLabel(bool personalized) {
    switch (_language) {
      case AppLanguage.english:
        return personalized ? 'AI personalized' : 'AI enabled';
      case AppLanguage.traditionalChinese:
        return personalized ? 'AI 已個人化' : 'AI 已啟用';
      case AppLanguage.simplifiedChinese:
        return personalized ? 'AI 已个人化' : 'AI 已启用';
    }
  }

  String _smartNavigationEtaLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'ETA';
      case AppLanguage.traditionalChinese:
        return '行車時間';
      case AppLanguage.simplifiedChinese:
        return '行车时间';
    }
  }

  String _smartNavigationWalkLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Walk';
      case AppLanguage.traditionalChinese:
        return '步行距離';
      case AppLanguage.simplifiedChinese:
        return '步行距离';
    }
  }

  String _smartNavigationTotalCostLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Total est.';
      case AppLanguage.traditionalChinese:
        return '總成本預估';
      case AppLanguage.simplifiedChinese:
        return '总成本预估';
    }
  }

  String _smartNavigationTollLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Toll';
      case AppLanguage.traditionalChinese:
        return '過路費';
      case AppLanguage.simplifiedChinese:
        return '过路费';
    }
  }

  String _smartNavigationVacancyLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Vacancy chance';
      case AppLanguage.traditionalChinese:
        return '空位機率';
      case AppLanguage.simplifiedChinese:
        return '空位机率';
    }
  }

  String _smartNavigationBestPickLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Best match';
      case AppLanguage.traditionalChinese:
        return '最佳建議';
      case AppLanguage.simplifiedChinese:
        return '最佳建议';
    }
  }

  String _smartNavigationCurrentSelectionLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Current selection';
      case AppLanguage.traditionalChinese:
        return '目前選擇';
      case AppLanguage.simplifiedChinese:
        return '目前选择';
    }
  }

  String _smartNavigationNoReliablePickLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'No reliable match';
      case AppLanguage.traditionalChinese:
        return '暫無可靠建議';
      case AppLanguage.simplifiedChinese:
        return '暂无可靠建议';
    }
  }

  String _smartNavigationPreferenceLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Preference';
      case AppLanguage.traditionalChinese:
        return '偏好';
      case AppLanguage.simplifiedChinese:
        return '偏好';
    }
  }

  String _smartNavigationPreferenceText(SmartNavigationPreference preference) {
    switch (preference) {
      case SmartNavigationPreference.cheapest:
        return switch (_language) {
          AppLanguage.english => 'Cheapest',
          AppLanguage.traditionalChinese => '最平',
          AppLanguage.simplifiedChinese => '最平',
        };
      case SmartNavigationPreference.fastest:
        return switch (_language) {
          AppLanguage.english => 'Fastest',
          AppLanguage.traditionalChinese => '最快',
          AppLanguage.simplifiedChinese => '最快',
        };
      case SmartNavigationPreference.availability:
        return switch (_language) {
          AppLanguage.english => 'Best vacancy',
          AppLanguage.traditionalChinese => '最易有位',
          AppLanguage.simplifiedChinese => '最易有位',
        };
      case SmartNavigationPreference.shortestWalk:
        return switch (_language) {
          AppLanguage.english => 'Shortest walk',
          AppLanguage.traditionalChinese => '最少步行',
          AppLanguage.simplifiedChinese => '最少步行',
        };
    }
  }

  String _smartNavigationNoParkingInfoLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Parking fee unavailable';
      case AppLanguage.traditionalChinese:
        return '停車費資料不足';
      case AppLanguage.simplifiedChinese:
        return '停车费资料不足';
    }
  }

  String _smartNavigationMeteredLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'Metered';
      case AppLanguage.traditionalChinese:
        return '咪錶車位';
      case AppLanguage.simplifiedChinese:
        return '咪表车位';
    }
  }

  String _smartNavigationHighRiskLabel() {
    switch (_language) {
      case AppLanguage.english:
        return 'High-risk fallback';
      case AppLanguage.traditionalChinese:
        return '高風險備選';
      case AppLanguage.simplifiedChinese:
        return '高风险备选';
    }
  }

  String? _smartNavigationRiskNotice({
    required bool usingHighRiskFallback,
    required bool selectedHighRisk,
  }) {
    if (usingHighRiskFallback) {
      return switch (_language) {
        AppLanguage.english =>
          'No nearby option looks reliably available right now. These are shown as high-risk fallbacks only.',
        AppLanguage.traditionalChinese => '附近暫時沒有可靠有位的選項，以下只列作高風險備選。',
        AppLanguage.simplifiedChinese => '附近暂时没有可靠有位的选项，以下只列作高风险备选。',
      };
    }
    if (selectedHighRisk) {
      return switch (_language) {
        AppLanguage.english =>
          'This option is still shown as a backup, but the predicted chance of finding a space is very low.',
        AppLanguage.traditionalChinese => '這個選項仍可作備選，但預測到達時成功泊位的機會很低。',
        AppLanguage.simplifiedChinese => '这个选项仍可作备选，但预测到达时成功泊位的机会很低。',
      };
    }
    return null;
  }

  bool _isMeteredCarpark(Carpark carpark) {
    return carpark.id.startsWith('metered:');
  }

  String _formatSmartDuration(int minutes) {
    if (_language == AppLanguage.english) {
      return '$minutes min';
    }
    return '$minutes 分鐘';
  }

  String _formatWalkingDistance(double meters) {
    if (meters >= 1000) {
      final km = (meters / 1000);
      final value = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
      return _language == AppLanguage.english ? '$value km' : '$value 公里';
    }
    final rounded = meters.round();
    return _language == AppLanguage.english ? '$rounded m' : '$rounded 米';
  }

  String _formatHkdAmount(double? amount) {
    if (amount == null || !amount.isFinite) return 'HK\$--';
    final value = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return 'HK\$$value';
  }

  String _formatSmartProbability(double probability) {
    return '${(probability * 100).round()}%';
  }

  String? _smartPredictedVacancySentence(SmartNavigationOption option) {
    final predictedVacancy = option.predictedVacancy;
    if (predictedVacancy == null) return null;
    return switch (_language) {
      AppLanguage.english =>
        'AI expects about $predictedVacancy spaces when you arrive.',
      AppLanguage.traditionalChinese => '預測到達時約有 $predictedVacancy 個位。',
      AppLanguage.simplifiedChinese => '预测到达时约有 $predictedVacancy 个位。',
    };
  }

  String _smartPredictedChanceSentence(SmartNavigationOption option) {
    final probability = _formatSmartProbability(option.vacancyProbability);
    return switch (_language) {
      AppLanguage.english =>
        'Estimated chance of finding a space on arrival is about $probability.',
      AppLanguage.traditionalChinese => '預測到達時有位機率約 $probability。',
      AppLanguage.simplifiedChinese => '预测到达时有位机率约 $probability。',
    };
  }

  String _smartPredictionSummary(SmartNavigationOption option) {
    final vacancySentence = _smartPredictedVacancySentence(option);
    final chanceSentence = _smartPredictedChanceSentence(option);
    if (vacancySentence == null) return chanceSentence;
    final trimmedVacancy = vacancySentence.endsWith('.')
        ? vacancySentence.substring(0, vacancySentence.length - 1)
        : vacancySentence;
    final trimmedChance = chanceSentence.endsWith('.')
        ? chanceSentence.substring(0, chanceSentence.length - 1)
        : chanceSentence;
    return '$trimmedVacancy · $trimmedChance';
  }

  Widget _smartPredictionExplanation({
    required ThemeData theme,
    required Color accent,
    required SmartNavigationOption option,
  }) {
    final vacancySentence = _smartPredictedVacancySentence(option);
    final chanceSentence = _smartPredictedChanceSentence(option);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vacancySentence != null)
            Text(
              vacancySentence,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          if (vacancySentence != null) const SizedBox(height: 4),
          Text(
            chanceSentence,
            style: theme.textTheme.bodySmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  ({String label, Color color}) _smartVacancyBadge(double probability) {
    if (probability >= 0.7) {
      return (
        label: switch (_language) {
          AppLanguage.english => 'High chance',
          AppLanguage.traditionalChinese => '高機率',
          AppLanguage.simplifiedChinese => '高机率',
        },
        color: const Color(0xFF1B8F4D),
      );
    }
    if (probability >= 0.4) {
      return (
        label: switch (_language) {
          AppLanguage.english => 'Medium chance',
          AppLanguage.traditionalChinese => '中機率',
          AppLanguage.simplifiedChinese => '中机率',
        },
        color: const Color(0xFFC58A00),
      );
    }
    return (
      label: switch (_language) {
        AppLanguage.english => 'Low chance',
        AppLanguage.traditionalChinese => '低機率',
        AppLanguage.simplifiedChinese => '低机率',
      },
      color: const Color(0xFFC44242),
    );
  }

  double _smartComparableTotalCost(SmartNavigationOption option) {
    final parkingCost = option.parkingCostEstimateHkd;
    if (parkingCost == null || !parkingCost.isFinite) {
      return double.infinity;
    }
    return option.toll.totalHkd + parkingCost;
  }

  double? _smartDisplayedTotalCost(SmartNavigationOption option) {
    final total = _smartComparableTotalCost(option);
    if (!total.isFinite) return null;
    return total;
  }

  List<Carpark> _smartNavigationCandidates(LatLng destination) {
    final candidates = List<Carpark>.from(_allCarparks);
    if (_meteredGroups.isEmpty) return candidates;

    final distance = const Distance();
    final nearbyGroups = _meteredGroups
        .map(
          (group) => (
            group: group,
            walkingDistanceMeters: distance(destination, group.center),
          ),
        )
        .where((item) => item.walkingDistanceMeters <= _searchRadiusMeters)
        .toList(growable: false);
    if (nearbyGroups.isEmpty) return candidates;

    final sortedGroups = [...nearbyGroups]
      ..sort((a, b) {
        final walking = a.walkingDistanceMeters.compareTo(
          b.walkingDistanceMeters,
        );
        if (walking != 0) return walking;
        return b.group.vacant.compareTo(a.group.vacant);
      });
    final preferredGroups = sortedGroups.where((item) => item.group.hasVacancy);
    final pickedGroups =
        (preferredGroups.isNotEmpty ? preferredGroups : sortedGroups).take(
          _kMeteredSmartCandidateLimit,
        );

    final knownIds = candidates.map((item) => item.id).toSet();
    for (final entry in pickedGroups) {
      final candidate = _meteredGroupAsSmartNavigationCandidate(entry.group);
      if (knownIds.add(candidate.id)) {
        candidates.add(candidate);
      }
    }
    return candidates;
  }

  Carpark _meteredGroupAsSmartNavigationCandidate(MeteredStreetGroup group) {
    final openingStatus = _smartNavigationMeteredOpeningStatus(group);
    return Carpark(
      id: 'metered:${group.key}',
      nameEn: _meteredStreetLabelFor(group, AppLanguage.english),
      nameTc: _meteredStreetLabelFor(group, AppLanguage.traditionalChinese),
      nameSc: _meteredStreetLabelFor(group, AppLanguage.simplifiedChinese),
      addressEn: group.districtEn,
      addressTc: group.districtTc,
      addressSc: group.districtSc,
      latitude: group.center.latitude,
      longitude: group.center.longitude,
      operatorName: 'Metered',
      openingStatus: openingStatus,
      privateCarRates: _meteredRatesForSmartNavigation(group.operatingPeriod),
      vacancyInfo: VacancyInfo.fromBuckets([
        VacancyBucket(
          key: 'privateCar',
          vehicleTypeKey: 'privateCar',
          available: group.vacant,
          categoryLabel: 'metered',
          lastUpdated: '',
          source: VacancySource.metered,
        ),
      ]),
    );
  }

  String? _smartNavigationMeteredOpeningStatus(MeteredStreetGroup group) {
    final status = resolveOperatingStatus(
      group.operatingPeriod,
      DateTime.now(),
    );
    switch (status) {
      case MeteredOperatingStatus.metering:
        return 'metering';
      case MeteredOperatingStatus.free:
        return 'free';
      case MeteredOperatingStatus.noParking:
        return 'closed:no parking';
      case MeteredOperatingStatus.unknown:
        return null;
    }
  }

  List<CarparkRate> _meteredRatesForSmartNavigation(String operatingPeriod) {
    CarparkRate rate({
      required List<String> weekdays,
      required double price,
      String? periodStart,
      String? periodEnd,
    }) {
      return CarparkRate(
        weekdays: weekdays,
        excludePublicHoliday: false,
        periodStart: periodStart,
        periodEnd: periodEnd,
        price: price,
        type: 'hourly',
        usageMinimum: 1,
      );
    }

    switch (operatingPeriod) {
      case 'A':
        return <CarparkRate>[
          rate(
            weekdays: _kWeekdaysMonToSat,
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '08:00',
            periodEnd: '24:00',
          ),
          rate(weekdays: const <String>['SUN'], price: 0),
          rate(
            weekdays: _kWeekdaysMonToSat,
            price: 0,
            periodStart: '00:00',
            periodEnd: '08:00',
          ),
        ];
      case 'B':
        return <CarparkRate>[
          rate(
            weekdays: _kWeekdaysMonToSat,
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '08:00',
            periodEnd: '20:00',
          ),
          rate(weekdays: const <String>['SUN'], price: 0),
          rate(
            weekdays: _kWeekdaysMonToSat,
            price: 0,
            periodStart: '20:00',
            periodEnd: '08:00',
          ),
        ];
      case 'D':
        return <CarparkRate>[
          rate(
            weekdays: _kWeekdaysMonToSat,
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '08:00',
            periodEnd: '24:00',
          ),
          rate(
            weekdays: const <String>['SUN'],
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '10:00',
            periodEnd: '22:00',
          ),
          rate(
            weekdays: const <String>['SUN'],
            price: 0,
            periodStart: '22:00',
            periodEnd: '10:00',
          ),
          rate(
            weekdays: _kWeekdaysMonToSat,
            price: 0,
            periodStart: '00:00',
            periodEnd: '08:00',
          ),
        ];
      case 'E':
        return <CarparkRate>[
          rate(
            weekdays: _kWeekdaysAll,
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '07:00',
            periodEnd: '20:00',
          ),
          rate(
            weekdays: _kWeekdaysAll,
            price: 0,
            periodStart: '20:00',
            periodEnd: '07:00',
          ),
        ];
      case 'F':
        return <CarparkRate>[
          rate(
            weekdays: _kWeekdaysAll,
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '08:00',
            periodEnd: '21:00',
          ),
          rate(
            weekdays: _kWeekdaysAll,
            price: 0,
            periodStart: '21:00',
            periodEnd: '08:00',
          ),
        ];
      case 'H':
        return <CarparkRate>[
          rate(
            weekdays: _kWeekdaysAll,
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '08:00',
            periodEnd: '20:00',
          ),
          rate(
            weekdays: _kWeekdaysAll,
            price: 0,
            periodStart: '20:00',
            periodEnd: '08:00',
          ),
        ];
      case 'J':
        return <CarparkRate>[
          rate(
            weekdays: _kWeekdaysAll,
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '08:00',
            periodEnd: '24:00',
          ),
          rate(
            weekdays: _kWeekdaysAll,
            price: 0,
            periodStart: '00:00',
            periodEnd: '08:00',
          ),
        ];
      case 'N':
        return <CarparkRate>[
          rate(
            weekdays: _kWeekdaysAll,
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '19:00',
            periodEnd: '24:00',
          ),
          rate(
            weekdays: _kWeekdaysAll,
            price: 0,
            periodStart: '00:00',
            periodEnd: '19:00',
          ),
        ];
      case 'P':
        return <CarparkRate>[
          rate(
            weekdays: _kWeekdaysMonToSat,
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '08:00',
            periodEnd: '20:00',
          ),
          rate(
            weekdays: _kWeekdaysMonToSat,
            price: 0,
            periodStart: '20:00',
            periodEnd: '08:00',
          ),
        ];
      case 'Q':
        return <CarparkRate>[
          rate(
            weekdays: _kWeekdaysMonToSat,
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '08:00',
            periodEnd: '20:00',
          ),
          rate(
            weekdays: const <String>['SUN'],
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '10:00',
            periodEnd: '22:00',
          ),
          rate(
            weekdays: _kWeekdaysMonToSat,
            price: 0,
            periodStart: '20:00',
            periodEnd: '08:00',
          ),
          rate(
            weekdays: const <String>['SUN'],
            price: 0,
            periodStart: '22:00',
            periodEnd: '10:00',
          ),
        ];
      case 'S':
        return <CarparkRate>[
          rate(
            weekdays: _kWeekdaysMonToFri,
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '17:00',
            periodEnd: '24:00',
          ),
          rate(
            weekdays: const <String>['SAT'],
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '08:00',
            periodEnd: '24:00',
          ),
          rate(
            weekdays: const <String>['SUN'],
            price: _kMeteredHourlyEstimateHkd,
            periodStart: '10:00',
            periodEnd: '22:00',
          ),
          rate(
            weekdays: _kWeekdaysMonToFri,
            price: 0,
            periodStart: '00:00',
            periodEnd: '08:00',
          ),
          rate(
            weekdays: const <String>['SAT'],
            price: 0,
            periodStart: '00:00',
            periodEnd: '08:00',
          ),
          rate(
            weekdays: const <String>['SUN'],
            price: 0,
            periodStart: '22:00',
            periodEnd: '10:00',
          ),
        ];
      default:
        return <CarparkRate>[
          rate(weekdays: _kWeekdaysAll, price: _kMeteredHourlyEstimateHkd),
        ];
    }
  }

  List<String> _smartReasonsForOption(
    SmartNavigationOption option,
    List<SmartNavigationOption> options,
  ) {
    if (options.isEmpty) return const [];
    final reasons = <String>[...option.aiReasons];
    final cheapest = options.reduce(
      (a, b) =>
          _smartComparableTotalCost(a) <= _smartComparableTotalCost(b) ? a : b,
    );
    final fastest = options.reduce(
      (a, b) => a.travelMinutes <= b.travelMinutes ? a : b,
    );
    final highestChance = options.reduce(
      (a, b) => a.vacancyProbability >= b.vacancyProbability ? a : b,
    );
    final shortestWalk = options.reduce(
      (a, b) => a.walkingDistanceMeters <= b.walkingDistanceMeters ? a : b,
    );

    if (identical(option, fastest)) {
      final text = switch (_language) {
        AppLanguage.english => 'Shortest drive time',
        AppLanguage.traditionalChinese => '行車時間最短',
        AppLanguage.simplifiedChinese => '行车时间最短',
      };
      if (!reasons.contains(text)) reasons.add(text);
    }
    if (identical(option, cheapest)) {
      final text = switch (_language) {
        AppLanguage.english => 'Lower total cost',
        AppLanguage.traditionalChinese => '總成本較低',
        AppLanguage.simplifiedChinese => '总成本较低',
      };
      if (!reasons.contains(text)) reasons.add(text);
    }
    if (identical(option, highestChance)) {
      final text = switch (_language) {
        AppLanguage.english => 'Better vacancy chance',
        AppLanguage.traditionalChinese => '空位機率較高',
        AppLanguage.simplifiedChinese => '空位机率较高',
      };
      if (!reasons.contains(text)) reasons.add(text);
    }
    if (identical(option, shortestWalk)) {
      final text = switch (_language) {
        AppLanguage.english => 'Shorter walk',
        AppLanguage.traditionalChinese => '步行距離較短',
        AppLanguage.simplifiedChinese => '步行距离较短',
      };
      if (!reasons.contains(text)) reasons.add(text);
    }
    if (reasons.isEmpty) {
      reasons.add(switch (_language) {
        AppLanguage.english => 'Best overall score',
        AppLanguage.traditionalChinese => '整體評分最佳',
        AppLanguage.simplifiedChinese => '整体评分最佳',
      });
    }
    return reasons.take(2).toList(growable: false);
  }

  Future<SmartNavigationOption?> _showSmartNavigationSummarySheet(
    SmartNavigationResult result,
  ) async {
    final allOptions = List<SmartNavigationOption>.from(result.alternatives);
    if (allOptions.isEmpty) return null;

    return showModalBottomSheet<SmartNavigationOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final accent = _mapThemes[_selectedTheme]?.accentColor ?? Colors.blue;
        final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.82;
        var selectedIndex = 0;
        var showAlternatives = false;
        var showPreferenceOptions = false;
        var preference = _smartNavigationPreference;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final rankedOptions = SmartNavigationService.rankOptions(
              allOptions,
              preference,
            );
            final viableOptions = rankedOptions
                .where(SmartNavigationService.isRecommendedOption)
                .toList(growable: false);
            final highRiskOptions = rankedOptions
                .where(SmartNavigationService.isHighRiskOption)
                .toList(growable: false);
            final usingHighRiskFallback = viableOptions.isEmpty;
            final topOptions = usingHighRiskFallback
                ? rankedOptions.take(3).toList(growable: false)
                : [
                    ...viableOptions.take(3),
                    ...highRiskOptions.take(
                      math.max(0, 3 - viableOptions.take(3).length),
                    ),
                  ].take(3).toList(growable: false);
            if (topOptions.isEmpty) {
              return const SizedBox.shrink();
            }
            if (selectedIndex >= topOptions.length) selectedIndex = 0;
            final selected = topOptions[selectedIndex];
            final selectedHighRisk = SmartNavigationService.isHighRiskOption(
              selected,
            );
            final reasons = _smartReasonsForOption(selected, topOptions);
            final vacancy = _smartVacancyBadge(selected.vacancyProbability);
            final parkingSummary =
                selected.parkingCostEstimate?.summary ??
                _smartNavigationNoParkingInfoLabel();
            final totalCost = _formatHkdAmount(
              _smartDisplayedTotalCost(selected),
            );
            final isMeteredSelected = _isMeteredCarpark(selected.carpark);
            final aiStatus = _smartNavigationAiStatusText(result, selected);
            final riskNotice = _smartNavigationRiskNotice(
              usingHighRiskFallback: usingHighRiskFallback,
              selectedHighRisk: selectedHighRisk,
            );
            final selectionLabel = usingHighRiskFallback
                ? _smartNavigationNoReliablePickLabel()
                : selectedIndex == 0
                ? _smartNavigationBestPickLabel()
                : _smartNavigationCurrentSelectionLabel();

            Widget metric(String label, String value, {Color? color}) {
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.55,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                child: Material(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxSheetHeight),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: theme.dividerColor.withValues(
                                        alpha: 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _smartNavigationSummaryTitle(),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(sheetContext).pop(),
                                        child: Text(
                                          AppLocalizations.of(
                                            sheetContext,
                                          )!.close,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      selectionLabel,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: usingHighRiskFallback
                                                ? theme.colorScheme.error
                                                : accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => setSheetState(
                                      () => showPreferenceOptions =
                                          !showPreferenceOptions,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _smartNavigationPreferenceLabel(),
                                                  style: theme
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _smartNavigationPreferenceText(
                                                    preference,
                                                  ),
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: accent,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            showPreferenceOptions
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.72),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (showPreferenceOptions) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: SmartNavigationPreference.values
                                          .map((item) {
                                            return ChoiceChip(
                                              label: Text(
                                                _smartNavigationPreferenceText(
                                                  item,
                                                ),
                                              ),
                                              selected: item == preference,
                                              onSelected: (_) {
                                                if (item == preference) return;
                                                _safeSetState(() {
                                                  _smartNavigationPreference =
                                                      item;
                                                });
                                                unawaited(
                                                  _saveSmartNavigationPreference(
                                                    item,
                                                  ),
                                                );
                                                setSheetState(() {
                                                  preference = item;
                                                  selectedIndex = 0;
                                                });
                                              },
                                            );
                                          })
                                          .toList(growable: false),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  if (riskNotice != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.errorContainer
                                            .withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: theme.colorScheme.error
                                              .withValues(alpha: 0.24),
                                        ),
                                      ),
                                      child: Text(
                                        riskNotice,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onErrorContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _carparkDisplayName(selected.carpark),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _displayAddress(selected.carpark),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.72),
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            if (isMeteredSelected)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: accent.withValues(
                                                    alpha: 0.14,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  _smartNavigationMeteredLabel(),
                                                  style: theme
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        color: accent,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                            if (selectedHighRisk)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme
                                                      .errorContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  _smartNavigationHighRiskLabel(),
                                                  style: theme
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .error,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: accent.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                _smartNavigationAiBadgeLabel(
                                                  result.aiPersonalized,
                                                ),
                                                style: theme
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: accent,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: vacancy.color.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '${_smartNavigationVacancyLabel()} ${vacancy.label}',
                                                style: theme
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: vacancy.color,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                parkingSummary,
                                                style: theme
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _smartNavigationWhyLabel(),
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          reasons.join(' · '),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          aiStatus,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: accent,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        _smartPredictionExplanation(
                                          theme: theme,
                                          accent: vacancy.color,
                                          option: selected,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            metric(
                                              _smartNavigationEtaLabel(),
                                              _formatSmartDuration(
                                                selected.travelMinutes,
                                              ),
                                              color: accent,
                                            ),
                                            const SizedBox(width: 8),
                                            metric(
                                              _smartNavigationTotalCostLabel(),
                                              totalCost,
                                              color: accent,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            metric(
                                              _smartNavigationTollLabel(),
                                              _formatHkdAmount(
                                                selected.toll.totalHkd,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            metric(
                                              _smartNavigationWalkLabel(),
                                              _formatWalkingDistance(
                                                selected.walkingDistanceMeters,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: topOptions.length <= 1
                                          ? null
                                          : () => setSheetState(
                                              () => showAlternatives =
                                                  !showAlternatives,
                                            ),
                                      icon: Icon(
                                        showAlternatives
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                      ),
                                      label: Text(
                                        _smartNavigationAlternativesLabel(
                                          showAlternatives,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (showAlternatives) ...[
                                    const SizedBox(height: 4),
                                    for (
                                      var i = 0;
                                      i < topOptions.length;
                                      i++
                                    ) ...[
                                      if (i > 0) const SizedBox(height: 8),
                                      _buildSmartOptionTile(
                                        option: topOptions[i],
                                        selected: i == selectedIndex,
                                        accent: accent,
                                        onTap: () => setSheetState(
                                          () => selectedIndex = i,
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(),
                                  child: Text(
                                    AppLocalizations.of(sheetContext)!.cancel,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(selected),
                                  icon: const Icon(Icons.navigation),
                                  label: Text(_smartNavigationStartLabel()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSmartOptionTile({
    required SmartNavigationOption option,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final badge = _smartVacancyBadge(option.vacancyProbability);
    final isHighRisk = SmartNavigationService.isHighRiskOption(option);
    final parkingText =
        option.parkingCostEstimate?.summary ??
        _smartNavigationNoParkingInfoLabel();
    final totalCost = _formatHkdAmount(_smartDisplayedTotalCost(option));
    final isMetered = _isMeteredCarpark(option.carpark);
    final predictionSummary = _smartPredictionSummary(option);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? accent
                  : theme.dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? accent : theme.iconTheme.color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _carparkDisplayName(option.carpark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatSmartDuration(option.travelMinutes)} · '
                      '${_formatWalkingDistance(option.walkingDistanceMeters)} · '
                      '$totalCost',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isMetered)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _smartNavigationMeteredLabel(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (isHighRisk)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _smartNavigationHighRiskLabel(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badge.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: badge.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          parkingText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      predictionSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: badge.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startSmartNavigation() async {
    final destination = _resolveSmartNavigationDestination();
    if (destination == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_smartNavigationUnavailableMessage())),
      );
      return;
    }
    if (_smartNavigationRunning) return;

    final origin = await _resolveSmartNavigationOrigin();
    if (origin == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.route_location_not_available,
          ),
        ),
      );
      return;
    }

    _safeSetState(() => _smartNavigationRunning = true);
    try {
      final result = await _smartNavigationService.planToDestination(
        origin: origin,
        destination: destination,
        carparks: _smartNavigationCandidates(destination),
        vehicleType: _vehicleType,
        preference: _smartNavigationPreference,
        languageCode: _language.storageValue,
        searchRadiusMeters: _searchRadiusMeters,
        estimatedParkingHours: _kSmartNavigationStayHours,
      );
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_smartNavigationFailedMessage())),
        );
        return;
      }

      final selected = await _showSmartNavigationSummarySheet(result);
      if (!mounted || selected == null) return;
      unawaited(
        _smartNavigationService.recordSelection(
          selectedOption: selected,
          presentedOptions: result.alternatives,
          preference: _smartNavigationPreference,
        ),
      );
      _safeSetState(() {
        _routeDestination = selected.carpark;
        _pickingRouteStart = false;
        _pickingRouteDestination = false;
      });
      _showNearbyCarparksOnMap(destination);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_smartNavigationSelectedMessage(selected))),
      );
      await _pushNavigationScreen(selected.carpark, autoStartNavigation: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_smartNavigationFailedMessage())));
      debugPrint('Smart navigation failed: $e');
    } finally {
      if (mounted) {
        _safeSetState(() => _smartNavigationRunning = false);
      }
    }
  }

  Future<LatLng?> _resolveSmartNavigationOrigin() async {
    if (_routeStartOverride != null) return _routeStartOverride;
    if (_currentLocation != null) return _currentLocation;

    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      final origin = LatLng(position.latitude, position.longitude);
      _safeSetState(() {
        _currentLocation = origin;
        _allCarparks = _sortCarparksForReference(_allCarparks, origin);
      });
      return origin;
    } catch (_) {
      return null;
    }
  }
}
