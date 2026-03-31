// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get app_title => '停車App';

  @override
  String get parking_map_title => '停車地圖';

  @override
  String get settings_title => '設定';

  @override
  String get map_settings_title => '地圖設定';

  @override
  String get map_style => '地圖樣式';

  @override
  String get map_controls => '地圖控制';

  @override
  String get normal => '一般';

  @override
  String get dark => '深色';

  @override
  String get bright => '明亮';

  @override
  String get map_theme_default => '預設';

  @override
  String get map_theme_night_drive => '夜間駕駛';

  @override
  String get map_theme_clean_atlas => '清爽地圖';

  @override
  String get dark_mode => '深色模式';

  @override
  String get language => '語言';

  @override
  String get language_english => '英文';

  @override
  String get language_traditional_chinese => '繁體中文';

  @override
  String get language_simplified_chinese => '簡體中文';

  @override
  String get vehicle_type => '車輛類型';

  @override
  String get vehicle_type_private_car => '私家車';

  @override
  String get vehicle_type_motorcycle => '電單車';

  @override
  String get vehicle_type_taxi => '的士';

  @override
  String get vacancy_type_private_car => '私家車';

  @override
  String get vacancy_type_motorcycle => '電單車';

  @override
  String get vacancy_type_taxi => '的士';

  @override
  String get back => '返回';

  @override
  String get zoom_in => '放大';

  @override
  String get zoom_out => '縮小';

  @override
  String get go_to_my_location => '前往我的位置';

  @override
  String get cluster_nearby_carparks => '聚合附近停車場';

  @override
  String get reset_view => '重設視圖';

  @override
  String get clear_cached_parking_data => '清除快取停車資料';

  @override
  String get clear_cached_parking_data_subtitle => '顯示載入並重新下載';

  @override
  String get loading => '載入中...';

  @override
  String get loading_carparks => '正在載入停車場...';

  @override
  String get dismiss => '關閉';

  @override
  String get cancel => '取消';

  @override
  String get clear => '清除';

  @override
  String get close => '關閉';

  @override
  String get apply => '套用';

  @override
  String get retry => '重試';

  @override
  String get refresh => '重新整理';

  @override
  String get route => '路線';

  @override
  String get routing => '正在規劃路線...';

  @override
  String get route_priorities => '路線優先項';

  @override
  String get route_priorities_subtitle => '可選擇一個或多個，並設定主要優先項。';

  @override
  String get set_primary => '設為主要';

  @override
  String get route_again => '重新規劃';

  @override
  String get tap_map_to_set_start_point => '點擊地圖設定起點';

  @override
  String get tap_map_to_set_destination_point => '點擊地圖設定目的地';

  @override
  String get tap_map_to_place_start_marker => '點擊地圖放置起點標記';

  @override
  String get from_current_location => '從：目前位置';

  @override
  String get from_selected_start => '從：已選起點';

  @override
  String get choose_start_point => '選擇起點';

  @override
  String get choose_destination => '選擇目的地';

  @override
  String get use_current_location => '使用目前位置';

  @override
  String get pick_on_map => '在地圖上選取';

  @override
  String get clear_selected_start => '清除已選起點';

  @override
  String get avoid_toll_fees => '避免過路費';

  @override
  String get toll_fee_title => '過路費';

  @override
  String get requesting_route => '正在取得路線...';

  @override
  String get routing_failed => '規劃路線失敗';

  @override
  String get no_routes_available => '沒有可用路線。';

  @override
  String get no_route_data_yet => '尚無路線資料。';

  @override
  String get compare_routes => '比較路線';

  @override
  String get roads => '道路';

  @override
  String get more_roads_omitted => '還有更多道路已省略…';

  @override
  String get stop => '停止';

  @override
  String get start_navigation => '開始導航';

  @override
  String get eta => 'ETA';

  @override
  String get distance => '距離';

  @override
  String get time => '時間';

  @override
  String get toll_cost => '過路費';

  @override
  String get toll_time => '收費時間';

  @override
  String get toll_pricing_time => '過路費計算時間';

  @override
  String get toll_time_mode_now => '現在';

  @override
  String get toll_time_mode_depart_at => '出發時間';

  @override
  String get toll_time_mode_arrive_by => '到達時間';

  @override
  String get use_current_time => '使用目前時間';

  @override
  String get set_departure_time => '設定出發時間';

  @override
  String get set_arrival_time_estimated => '設定到達時間（估算）';

  @override
  String get pick_date_time => '選擇日期/時間';

  @override
  String get change_date_time => '更改日期/時間';

  @override
  String get reset => '重置';

  @override
  String get select => '選擇';

  @override
  String get toll_select_tunnel => '選擇隧道';

  @override
  String toll_select_date(Object date) {
    return '選擇日期  $date';
  }

  @override
  String toll_select_time(Object time) {
    return '選擇時間  $time';
  }

  @override
  String get arrive_unknown => '到達：--';

  @override
  String get toll_unknown => '過路費：--';

  @override
  String get toll_amount_unknown => 'HK\$--';

  @override
  String get no_toll_fees => '無過路費';

  @override
  String get toll_chip_unknown => '過路費 --';

  @override
  String get toll_chip_free => '過路費 HK\$0';

  @override
  String get toll_short => '過路費';

  @override
  String get toll_free_route_may_avoid_major_roads => '免過路費路線可能會避開主要道路。';

  @override
  String get toll_info_unavailable_showing_best_route => '過路費資訊無法取得；顯示最佳路線。';

  @override
  String get no_toll_free_route_showing_lowest_toll_route =>
      '沒有免過路費路線；顯示最低過路費路線。';

  @override
  String get coordinates => '座標';

  @override
  String get free_spaces => '空位';

  @override
  String get carpark_status_open => '開放';

  @override
  String get carpark_status_closed => '關閉';

  @override
  String get unknown_carpark => '未知停車場';

  @override
  String get carpark => '停車場';

  @override
  String get nearby => '附近';

  @override
  String get search_parking => '搜尋停車場名稱或地址';

  @override
  String get no_matching_car_parks => '沒有符合的停車場';

  @override
  String get no_recent_searches => '沒有最近搜尋';

  @override
  String get favorites => '收藏';

  @override
  String get recent => '最近';

  @override
  String get search_results => '搜尋結果';

  @override
  String get saved_places => '已儲存地點';

  @override
  String get add_place => '新增地點';

  @override
  String get save_place => '儲存地點';

  @override
  String get place_name => '名稱';

  @override
  String get place_name_hint => '家、學校';

  @override
  String get place_location => '位置';

  @override
  String get place_location_hint => '搜尋地址或地點';

  @override
  String get place_edit_name_hint => '可編輯地點名稱（選填）。';

  @override
  String get place_missing_info => '請輸入名稱和位置。';

  @override
  String get save => '儲存';

  @override
  String get na => '不適用';

  @override
  String get price => '價格';

  @override
  String get vacancies => '空位';

  @override
  String get updated => '更新';

  @override
  String get rates => '費率';

  @override
  String get navigate => '導航';

  @override
  String get photo_unavailable => '無法顯示圖片';

  @override
  String get show_all => '顯示全部';

  @override
  String get show_fewer => '顯示較少';

  @override
  String get no_pricing_info => '此停車場沒有可用的收費資訊。';

  @override
  String get no_price_information => '沒有收費資訊';

  @override
  String get rate_type_hourly => '每小時';

  @override
  String get rate_type_12_hour_parking => '12 小時停車';

  @override
  String get rate_type_24_hour_parking => '24 小時停車';

  @override
  String get rate_type_monthly => '月租';

  @override
  String get rate_type_night => '夜間停車';

  @override
  String get rate_type_day => '日間停車';

  @override
  String get rate_type_day_and_night => '日夜';

  @override
  String get rate_type_day_pass => '日票';

  @override
  String get excluding_public_holidays => '不包括公眾假期';

  @override
  String get weekdays => '平日';

  @override
  String get weekdays_excluding_ph => '平日（不包括公假）';

  @override
  String get weekends => '週末';

  @override
  String get weekends_and_ph => '週末及公假';

  @override
  String get weekends_excluding_ph => '週末（不包括公假）';

  @override
  String get excluding_public_holiday_suffix => '(不包括公假)';

  @override
  String get public_holiday => '公假';

  @override
  String get weekday_mon_short => '一';

  @override
  String get weekday_tue_short => '二';

  @override
  String get weekday_wed_short => '三';

  @override
  String get weekday_thu_short => '四';

  @override
  String get weekday_fri_short => '五';

  @override
  String get weekday_sat_short => '六';

  @override
  String get weekday_sun_short => '日';

  @override
  String get location_not_available => '無法取得定位';

  @override
  String get location_permission_denied => '位置權限已拒絕';

  @override
  String get location_permission_permanently_denied => '位置權限已永久拒絕';

  @override
  String get route_location_not_available => '無法取得定位，無法繪製路線';

  @override
  String get route_not_found => '找不到路線';

  @override
  String route_fetch_failed(Object error) {
    return '路線擷取失敗：$error';
  }

  @override
  String error_getting_location(Object error) {
    return '取得定位錯誤：$error';
  }

  @override
  String error_loading_carparks(Object error) {
    return '載入停車場錯誤：$error';
  }

  @override
  String rate_from_price(Object price) {
    return '由 $price 起';
  }

  @override
  String vacancy_ev(Object count) {
    return 'EV $count';
  }

  @override
  String vacancy_disabled(Object count) {
    return '無障礙 $count';
  }

  @override
  String rate_minimum_hours(Object hours) {
    return '最少 $hours 小時';
  }

  @override
  String rate_valid_until(Object date) {
    return '至 $date';
  }

  @override
  String route_number(Object number) {
    return '路線 $number';
  }

  @override
  String get metered_parking => '咪錶車位';

  @override
  String get metered_parking_title => '咪錶車位';

  @override
  String get loading_metered_parking => '正在載入咪錶車位...';

  @override
  String get metered_no_data => '沒有咪錶車位資料。';

  @override
  String get metered_vacant => '可用';

  @override
  String get metered_occupied => '已佔用';

  @override
  String get metered_unknown => '未知';

  @override
  String metered_spaces_count(Object vacant, Object total) {
    return '$vacant 空 / 共 $total';
  }

  @override
  String get metered_vehicle_filter => '車輛類型';

  @override
  String get metered_vehicle_light_goods => '輕型貨車';

  @override
  String get metered_vehicle_heavy_goods => '重型貨車';

  @override
  String get metered_vehicle_coach => '巴士';

  @override
  String get metered_vehicle_special => '特種用途車輛';

  @override
  String get metered_status_free_now => '現時免費';

  @override
  String get metered_status_metering_now => '現時收費';

  @override
  String get metered_status_no_parking_now => '現時禁泊';

  @override
  String get metered_status_unknown => '開放時間不明';

  @override
  String tdas_eta(Object eta, Object speed) {
    return 'TDAS ETA：$eta / $speed';
  }

  @override
  String duration_hours_minutes(Object hours, Object minutes) {
    return '$hours 小時 $minutes 分鐘';
  }

  @override
  String duration_minutes(Object minutes) {
    return '$minutes 分鐘';
  }

  @override
  String distance_km(Object km) {
    return '$km 公里';
  }

  @override
  String distance_m(Object m) {
    return '$m 米';
  }

  @override
  String arrive_at(Object time) {
    return '到達：$time';
  }

  @override
  String depart_and_arrive(Object depart, Object arrive) {
    return '出發：$depart · 到達：$arrive';
  }

  @override
  String arrive_and_est_depart(Object arrive, Object depart) {
    return '到達：$arrive · 預計出發：$depart';
  }

  @override
  String est_toll(Object amount) {
    return '預估過路費：$amount';
  }
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

  @override
  String get app_title => '停车App';

  @override
  String get parking_map_title => '停车地图';

  @override
  String get settings_title => '设置';

  @override
  String get map_settings_title => '地图设置';

  @override
  String get map_style => '地图样式';

  @override
  String get map_controls => '地图控制';

  @override
  String get normal => '正常';

  @override
  String get dark => '深色';

  @override
  String get bright => '明亮';

  @override
  String get map_theme_default => '默认';

  @override
  String get map_theme_night_drive => '夜间驾驶';

  @override
  String get map_theme_clean_atlas => '清爽地图';

  @override
  String get dark_mode => '深色模式';

  @override
  String get language => '语言';

  @override
  String get language_english => '英文';

  @override
  String get language_traditional_chinese => '繁体中文';

  @override
  String get language_simplified_chinese => '简体中文';

  @override
  String get vehicle_type => '车辆类型';

  @override
  String get vehicle_type_private_car => '私家车';

  @override
  String get vehicle_type_motorcycle => '摩托车';

  @override
  String get vehicle_type_taxi => '出租车';

  @override
  String get vacancy_type_private_car => '私家车';

  @override
  String get vacancy_type_motorcycle => '摩托车';

  @override
  String get vacancy_type_taxi => '出租车';

  @override
  String get back => '返回';

  @override
  String get zoom_in => '放大';

  @override
  String get zoom_out => '缩小';

  @override
  String get go_to_my_location => '前往我的位置';

  @override
  String get cluster_nearby_carparks => '聚合附近停车场';

  @override
  String get reset_view => '重置视图';

  @override
  String get clear_cached_parking_data => '清除缓存停车数据';

  @override
  String get clear_cached_parking_data_subtitle => '显示加载并重新下载';

  @override
  String get loading => '加载中...';

  @override
  String get loading_carparks => '正在加载停车场...';

  @override
  String get dismiss => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get clear => '清除';

  @override
  String get close => '关闭';

  @override
  String get apply => '应用';

  @override
  String get retry => '重试';

  @override
  String get refresh => '刷新';

  @override
  String get route => '路线';

  @override
  String get routing => '正在规划路线...';

  @override
  String get route_priorities => '路线优先项';

  @override
  String get route_priorities_subtitle => '可选择一个或多个，并设置主要优先项。';

  @override
  String get set_primary => '设为主要';

  @override
  String get route_again => '重新规划';

  @override
  String get tap_map_to_set_start_point => '点击地图设置起点';

  @override
  String get tap_map_to_set_destination_point => '点击地图设置目的地';

  @override
  String get tap_map_to_place_start_marker => '点击地图放置起点标记';

  @override
  String get from_current_location => '从：当前位置';

  @override
  String get from_selected_start => '从：已选起点';

  @override
  String get choose_start_point => '选择起点';

  @override
  String get choose_destination => '选择目的地';

  @override
  String get use_current_location => '使用当前位置';

  @override
  String get pick_on_map => '在地图上选择';

  @override
  String get clear_selected_start => '清除已选起点';

  @override
  String get avoid_toll_fees => '避免过路费';

  @override
  String get toll_fee_title => '过路费';

  @override
  String get requesting_route => '正在获取路线...';

  @override
  String get routing_failed => '规划路线失败';

  @override
  String get no_routes_available => '没有可用路线。';

  @override
  String get no_route_data_yet => '尚无路线数据。';

  @override
  String get compare_routes => '比较路线';

  @override
  String get roads => '道路';

  @override
  String get more_roads_omitted => '更多道路已省略…';

  @override
  String get stop => '停止';

  @override
  String get start_navigation => '开始导航';

  @override
  String get eta => 'ETA';

  @override
  String get distance => '距离';

  @override
  String get time => '时间';

  @override
  String get toll_cost => '过路费';

  @override
  String get toll_time => '收费时间';

  @override
  String get toll_pricing_time => '过路费计算时间';

  @override
  String get toll_time_mode_now => '现在';

  @override
  String get toll_time_mode_depart_at => '出发时间';

  @override
  String get toll_time_mode_arrive_by => '到达时间';

  @override
  String get use_current_time => '使用当前时间';

  @override
  String get set_departure_time => '设置出发时间';

  @override
  String get set_arrival_time_estimated => '设置到达时间（估算）';

  @override
  String get pick_date_time => '选择日期/时间';

  @override
  String get change_date_time => '更改日期/时间';

  @override
  String get reset => '重置';

  @override
  String get select => '选择';

  @override
  String get toll_select_tunnel => '选择隧道';

  @override
  String toll_select_date(Object date) {
    return '选择日期  $date';
  }

  @override
  String toll_select_time(Object time) {
    return '选择时间  $time';
  }

  @override
  String get arrive_unknown => '到达：--';

  @override
  String get toll_unknown => '过路费：--';

  @override
  String get toll_amount_unknown => 'HK\$--';

  @override
  String get no_toll_fees => '无过路费';

  @override
  String get toll_chip_unknown => '过路费 --';

  @override
  String get toll_chip_free => '过路费 HK\$0';

  @override
  String get toll_short => '过路费';

  @override
  String get toll_free_route_may_avoid_major_roads => '免过路费路线可能会避开主要道路。';

  @override
  String get toll_info_unavailable_showing_best_route => '过路费信息无法获取；显示最佳路线。';

  @override
  String get no_toll_free_route_showing_lowest_toll_route =>
      '没有免过路费路线；显示最低过路费路线。';

  @override
  String get coordinates => '坐标';

  @override
  String get free_spaces => '空位';

  @override
  String get carpark_status_open => '开放';

  @override
  String get carpark_status_closed => '关闭';

  @override
  String get unknown_carpark => '未知停车场';

  @override
  String get carpark => '停车场';

  @override
  String get nearby => '附近';

  @override
  String get search_parking => '搜索停车场名称或地址';

  @override
  String get no_matching_car_parks => '没有匹配的停车场';

  @override
  String get no_recent_searches => '没有最近搜索';

  @override
  String get favorites => '收藏';

  @override
  String get recent => '最近';

  @override
  String get search_results => '搜索结果';

  @override
  String get saved_places => '已保存地点';

  @override
  String get add_place => '添加地点';

  @override
  String get save_place => '保存地点';

  @override
  String get place_name => '名称';

  @override
  String get place_name_hint => '家、学校';

  @override
  String get place_location => '位置';

  @override
  String get place_location_hint => '搜索地址或地点';

  @override
  String get place_edit_name_hint => '可编辑地点名称（选填）。';

  @override
  String get place_missing_info => '请输入名称和位置。';

  @override
  String get save => '保存';

  @override
  String get na => '不适用';

  @override
  String get price => '价格';

  @override
  String get vacancies => '空位';

  @override
  String get updated => '更新';

  @override
  String get rates => '费率';

  @override
  String get navigate => '导航';

  @override
  String get photo_unavailable => '无法显示图片';

  @override
  String get show_all => '显示全部';

  @override
  String get show_fewer => '显示更少';

  @override
  String get no_pricing_info => '此停车场没有可用的收费信息。';

  @override
  String get no_price_information => '没有收费信息';

  @override
  String get rate_type_hourly => '每小时';

  @override
  String get rate_type_12_hour_parking => '12小时停车';

  @override
  String get rate_type_24_hour_parking => '24小时停车';

  @override
  String get rate_type_monthly => '月租';

  @override
  String get rate_type_night => '夜间停车';

  @override
  String get rate_type_day => '日间停车';

  @override
  String get rate_type_day_and_night => '日夜';

  @override
  String get rate_type_day_pass => '日票';

  @override
  String get excluding_public_holidays => '不包括公众假期';

  @override
  String get weekdays => '工作日';

  @override
  String get weekdays_excluding_ph => '工作日（不含公假）';

  @override
  String get weekends => '周末';

  @override
  String get weekends_and_ph => '周末及公假';

  @override
  String get weekends_excluding_ph => '周末（不含公假）';

  @override
  String get excluding_public_holiday_suffix => '(不含公假)';

  @override
  String get public_holiday => '公假';

  @override
  String get weekday_mon_short => '一';

  @override
  String get weekday_tue_short => '二';

  @override
  String get weekday_wed_short => '三';

  @override
  String get weekday_thu_short => '四';

  @override
  String get weekday_fri_short => '五';

  @override
  String get weekday_sat_short => '六';

  @override
  String get weekday_sun_short => '日';

  @override
  String get location_not_available => '无法获取定位';

  @override
  String get location_permission_denied => '位置权限被拒绝';

  @override
  String get location_permission_permanently_denied => '位置权限被永久拒绝';

  @override
  String get route_location_not_available => '无法获取定位，无法绘制路线';

  @override
  String get route_not_found => '找不到路线';

  @override
  String route_fetch_failed(Object error) {
    return '路线获取失败：$error';
  }

  @override
  String error_getting_location(Object error) {
    return '获取定位出错：$error';
  }

  @override
  String error_loading_carparks(Object error) {
    return '加载停车场出错：$error';
  }

  @override
  String rate_from_price(Object price) {
    return '从 $price 起';
  }

  @override
  String vacancy_ev(Object count) {
    return 'EV $count';
  }

  @override
  String vacancy_disabled(Object count) {
    return '无障碍 $count';
  }

  @override
  String rate_minimum_hours(Object hours) {
    return '最少 $hours 小时';
  }

  @override
  String rate_valid_until(Object date) {
    return '至 $date';
  }

  @override
  String route_number(Object number) {
    return '路线 $number';
  }

  @override
  String get metered_parking => '咪表车位';

  @override
  String get metered_parking_title => '咪表车位';

  @override
  String get loading_metered_parking => '正在加载咪表车位...';

  @override
  String get metered_no_data => '没有咪表车位数据。';

  @override
  String get metered_vacant => '可用';

  @override
  String get metered_occupied => '已占用';

  @override
  String get metered_unknown => '未知';

  @override
  String metered_spaces_count(Object vacant, Object total) {
    return '$vacant 空 / 共 $total';
  }

  @override
  String get metered_vehicle_filter => '车辆类型';

  @override
  String get metered_vehicle_light_goods => '轻型货车';

  @override
  String get metered_vehicle_heavy_goods => '重型货车';

  @override
  String get metered_vehicle_coach => '巴士';

  @override
  String get metered_vehicle_special => '特种用途车辆';

  @override
  String get metered_status_free_now => '当前免费';

  @override
  String get metered_status_metering_now => '当前收费';

  @override
  String get metered_status_no_parking_now => '当前禁停';

  @override
  String get metered_status_unknown => '开放时间不明';

  @override
  String tdas_eta(Object eta, Object speed) {
    return 'TDAS ETA：$eta / $speed';
  }

  @override
  String duration_hours_minutes(Object hours, Object minutes) {
    return '$hours小时 $minutes分钟';
  }

  @override
  String duration_minutes(Object minutes) {
    return '$minutes分钟';
  }

  @override
  String distance_km(Object km) {
    return '$km 公里';
  }

  @override
  String distance_m(Object m) {
    return '$m 米';
  }

  @override
  String arrive_at(Object time) {
    return '到达：$time';
  }

  @override
  String depart_and_arrive(Object depart, Object arrive) {
    return '出发：$depart · 到达：$arrive';
  }

  @override
  String arrive_and_est_depart(Object arrive, Object depart) {
    return '到达：$arrive · 预计出发：$depart';
  }

  @override
  String est_toll(Object amount) {
    return '预计过路费：$amount';
  }
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get app_title => '停車App';

  @override
  String get parking_map_title => '停車地圖';

  @override
  String get settings_title => '設定';

  @override
  String get map_settings_title => '地圖設定';

  @override
  String get map_style => '地圖樣式';

  @override
  String get map_controls => '地圖控制';

  @override
  String get normal => '一般';

  @override
  String get dark => '深色';

  @override
  String get bright => '明亮';

  @override
  String get map_theme_default => '預設';

  @override
  String get map_theme_night_drive => '夜間駕駛';

  @override
  String get map_theme_clean_atlas => '清爽地圖';

  @override
  String get dark_mode => '深色模式';

  @override
  String get language => '語言';

  @override
  String get language_english => '英文';

  @override
  String get language_traditional_chinese => '繁體中文';

  @override
  String get language_simplified_chinese => '簡體中文';

  @override
  String get vehicle_type => '車輛類型';

  @override
  String get vehicle_type_private_car => '私家車';

  @override
  String get vehicle_type_motorcycle => '電單車';

  @override
  String get vehicle_type_taxi => '的士';

  @override
  String get vacancy_type_private_car => '私家車';

  @override
  String get vacancy_type_motorcycle => '電單車';

  @override
  String get vacancy_type_taxi => '的士';

  @override
  String get back => '返回';

  @override
  String get zoom_in => '放大';

  @override
  String get zoom_out => '縮小';

  @override
  String get go_to_my_location => '前往我的位置';

  @override
  String get cluster_nearby_carparks => '聚合附近停車場';

  @override
  String get reset_view => '重設視圖';

  @override
  String get clear_cached_parking_data => '清除快取停車資料';

  @override
  String get clear_cached_parking_data_subtitle => '顯示載入並重新下載';

  @override
  String get loading => '載入中...';

  @override
  String get loading_carparks => '正在載入停車場...';

  @override
  String get dismiss => '關閉';

  @override
  String get cancel => '取消';

  @override
  String get clear => '清除';

  @override
  String get close => '關閉';

  @override
  String get apply => '套用';

  @override
  String get retry => '重試';

  @override
  String get refresh => '重新整理';

  @override
  String get route => '路線';

  @override
  String get routing => '正在規劃路線...';

  @override
  String get route_priorities => '路線優先項';

  @override
  String get route_priorities_subtitle => '可選擇一個或多個，並設定主要優先項。';

  @override
  String get set_primary => '設為主要';

  @override
  String get route_again => '重新規劃';

  @override
  String get tap_map_to_set_start_point => '點擊地圖設定起點';

  @override
  String get tap_map_to_set_destination_point => '點擊地圖設定目的地';

  @override
  String get tap_map_to_place_start_marker => '點擊地圖放置起點標記';

  @override
  String get from_current_location => '從：目前位置';

  @override
  String get from_selected_start => '從：已選起點';

  @override
  String get choose_start_point => '選擇起點';

  @override
  String get choose_destination => '選擇目的地';

  @override
  String get use_current_location => '使用目前位置';

  @override
  String get pick_on_map => '在地圖上選取';

  @override
  String get clear_selected_start => '清除已選起點';

  @override
  String get avoid_toll_fees => '避免過路費';

  @override
  String get toll_fee_title => '過路費';

  @override
  String get requesting_route => '正在取得路線...';

  @override
  String get routing_failed => '規劃路線失敗';

  @override
  String get no_routes_available => '沒有可用路線。';

  @override
  String get no_route_data_yet => '尚無路線資料。';

  @override
  String get compare_routes => '比較路線';

  @override
  String get roads => '道路';

  @override
  String get more_roads_omitted => '還有更多道路已省略…';

  @override
  String get stop => '停止';

  @override
  String get start_navigation => '開始導航';

  @override
  String get eta => 'ETA';

  @override
  String get distance => '距離';

  @override
  String get time => '時間';

  @override
  String get toll_cost => '過路費';

  @override
  String get toll_time => '收費時間';

  @override
  String get toll_pricing_time => '過路費計算時間';

  @override
  String get toll_time_mode_now => '現在';

  @override
  String get toll_time_mode_depart_at => '出發時間';

  @override
  String get toll_time_mode_arrive_by => '到達時間';

  @override
  String get use_current_time => '使用目前時間';

  @override
  String get set_departure_time => '設定出發時間';

  @override
  String get set_arrival_time_estimated => '設定到達時間（估算）';

  @override
  String get pick_date_time => '選擇日期/時間';

  @override
  String get change_date_time => '更改日期/時間';

  @override
  String get reset => '重置';

  @override
  String get select => '選擇';

  @override
  String get toll_select_tunnel => '選擇隧道';

  @override
  String toll_select_date(Object date) {
    return '選擇日期  $date';
  }

  @override
  String toll_select_time(Object time) {
    return '選擇時間  $time';
  }

  @override
  String get arrive_unknown => '到達：--';

  @override
  String get toll_unknown => '過路費：--';

  @override
  String get toll_amount_unknown => 'HK\$--';

  @override
  String get no_toll_fees => '無過路費';

  @override
  String get toll_chip_unknown => '過路費 --';

  @override
  String get toll_chip_free => '過路費 HK\$0';

  @override
  String get toll_short => '過路費';

  @override
  String get toll_free_route_may_avoid_major_roads => '免過路費路線可能會避開主要道路。';

  @override
  String get toll_info_unavailable_showing_best_route => '過路費資訊無法取得；顯示最佳路線。';

  @override
  String get no_toll_free_route_showing_lowest_toll_route =>
      '沒有免過路費路線；顯示最低過路費路線。';

  @override
  String get coordinates => '座標';

  @override
  String get free_spaces => '空位';

  @override
  String get carpark_status_open => '開放';

  @override
  String get carpark_status_closed => '關閉';

  @override
  String get unknown_carpark => '未知停車場';

  @override
  String get carpark => '停車場';

  @override
  String get nearby => '附近';

  @override
  String get search_parking => '搜尋停車場名稱或地址';

  @override
  String get no_matching_car_parks => '沒有符合的停車場';

  @override
  String get no_recent_searches => '沒有最近搜尋';

  @override
  String get favorites => '收藏';

  @override
  String get recent => '最近';

  @override
  String get search_results => '搜尋結果';

  @override
  String get saved_places => '已儲存地點';

  @override
  String get add_place => '新增地點';

  @override
  String get save_place => '儲存地點';

  @override
  String get place_name => '名稱';

  @override
  String get place_name_hint => '家、學校';

  @override
  String get place_location => '位置';

  @override
  String get place_location_hint => '搜尋地址或地點';

  @override
  String get place_edit_name_hint => '可編輯地點名稱（選填）。';

  @override
  String get place_missing_info => '請輸入名稱和位置。';

  @override
  String get save => '儲存';

  @override
  String get na => '不適用';

  @override
  String get price => '價格';

  @override
  String get vacancies => '空位';

  @override
  String get updated => '更新';

  @override
  String get rates => '費率';

  @override
  String get navigate => '導航';

  @override
  String get photo_unavailable => '無法顯示圖片';

  @override
  String get show_all => '顯示全部';

  @override
  String get show_fewer => '顯示較少';

  @override
  String get no_pricing_info => '此停車場沒有可用的收費資訊。';

  @override
  String get no_price_information => '沒有收費資訊';

  @override
  String get rate_type_hourly => '每小時';

  @override
  String get rate_type_12_hour_parking => '12 小時停車';

  @override
  String get rate_type_24_hour_parking => '24 小時停車';

  @override
  String get rate_type_monthly => '月租';

  @override
  String get rate_type_night => '夜間停車';

  @override
  String get rate_type_day => '日間停車';

  @override
  String get rate_type_day_and_night => '日夜';

  @override
  String get rate_type_day_pass => '日票';

  @override
  String get excluding_public_holidays => '不包括公眾假期';

  @override
  String get weekdays => '平日';

  @override
  String get weekdays_excluding_ph => '平日（不包括公假）';

  @override
  String get weekends => '週末';

  @override
  String get weekends_and_ph => '週末及公假';

  @override
  String get weekends_excluding_ph => '週末（不包括公假）';

  @override
  String get excluding_public_holiday_suffix => '(不包括公假)';

  @override
  String get public_holiday => '公假';

  @override
  String get weekday_mon_short => '一';

  @override
  String get weekday_tue_short => '二';

  @override
  String get weekday_wed_short => '三';

  @override
  String get weekday_thu_short => '四';

  @override
  String get weekday_fri_short => '五';

  @override
  String get weekday_sat_short => '六';

  @override
  String get weekday_sun_short => '日';

  @override
  String get location_not_available => '無法取得定位';

  @override
  String get location_permission_denied => '位置權限已拒絕';

  @override
  String get location_permission_permanently_denied => '位置權限已永久拒絕';

  @override
  String get route_location_not_available => '無法取得定位，無法繪製路線';

  @override
  String get route_not_found => '找不到路線';

  @override
  String route_fetch_failed(Object error) {
    return '路線擷取失敗：$error';
  }

  @override
  String error_getting_location(Object error) {
    return '取得定位錯誤：$error';
  }

  @override
  String error_loading_carparks(Object error) {
    return '載入停車場錯誤：$error';
  }

  @override
  String rate_from_price(Object price) {
    return '由 $price 起';
  }

  @override
  String vacancy_ev(Object count) {
    return 'EV $count';
  }

  @override
  String vacancy_disabled(Object count) {
    return '無障礙 $count';
  }

  @override
  String rate_minimum_hours(Object hours) {
    return '最少 $hours 小時';
  }

  @override
  String rate_valid_until(Object date) {
    return '至 $date';
  }

  @override
  String route_number(Object number) {
    return '路線 $number';
  }

  @override
  String get metered_parking => '咪錶車位';

  @override
  String get metered_parking_title => '咪錶車位';

  @override
  String get loading_metered_parking => '正在載入咪錶車位...';

  @override
  String get metered_no_data => '沒有咪錶車位資料。';

  @override
  String get metered_vacant => '可用';

  @override
  String get metered_occupied => '已佔用';

  @override
  String get metered_unknown => '未知';

  @override
  String metered_spaces_count(Object vacant, Object total) {
    return '$vacant 空 / 共 $total';
  }

  @override
  String get metered_vehicle_filter => '車輛類型';

  @override
  String get metered_vehicle_light_goods => '輕型貨車';

  @override
  String get metered_vehicle_heavy_goods => '重型貨車';

  @override
  String get metered_vehicle_coach => '巴士';

  @override
  String get metered_vehicle_special => '特種用途車輛';

  @override
  String get metered_status_free_now => '目前免費';

  @override
  String get metered_status_metering_now => '目前收費';

  @override
  String get metered_status_no_parking_now => '目前禁泊';

  @override
  String get metered_status_unknown => '開放時間不明';

  @override
  String tdas_eta(Object eta, Object speed) {
    return 'TDAS ETA：$eta / $speed';
  }

  @override
  String duration_hours_minutes(Object hours, Object minutes) {
    return '$hours 小時 $minutes 分鐘';
  }

  @override
  String duration_minutes(Object minutes) {
    return '$minutes 分鐘';
  }

  @override
  String distance_km(Object km) {
    return '$km 公里';
  }

  @override
  String distance_m(Object m) {
    return '$m 米';
  }

  @override
  String arrive_at(Object time) {
    return '到達：$time';
  }

  @override
  String depart_and_arrive(Object depart, Object arrive) {
    return '出發：$depart · 到達：$arrive';
  }

  @override
  String arrive_and_est_depart(Object arrive, Object depart) {
    return '到達：$arrive · 預計出發：$depart';
  }

  @override
  String est_toll(Object amount) {
    return '預估過路費：$amount';
  }
}
