// =============================================================================
// 宿管端「到岗打卡」
//
// 入口：宿管工作台快捷入口「到岗打卡」→ controller.openDormCheckInManagement()
//      → SmartCampusPage 路由到本视图；横幅返回 → onBack。
//
// 视觉（原版 970 设计宽，数值照原版同路径文件）：
//   1. 横幅：共享 [SmartCampusPageBanner]，居中标题 + 副标题。
//   2. 主面板（439 高白卡 + 16 圆角）：地图底 + 顶部定位信息条（定位图标 +
//      地址 14/500 + 经纬度 11 + 状态 12）+ 右上白底胶囊「获取当前定位」+
//      中央 160 圆形渐变打卡按钮（打卡类型 16/600 + 实时时间 20/600）。
//   3. 「我的打卡记录」18/500 标题。
//   4. 双列记录卡（背景图 + 12 圆角）：标题 16/500 + 右侧「正常」方角标签 +
//      灰底块「打卡时间 / 打卡位置 / 定位坐标」。
//
// 相对原版保留的差异：定位成功前打卡按钮禁用并在下方说明原因；定位失败只显示
// 中文提示，右上按钮变为「重新获取定位」；演示记录取最近一个工作日。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/demo/demo_clock.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/campus_format.dart';
import '../services/baidu_geo_service.dart';
import '../services/geo_locator.dart';
import 'widgets/baidu_map_view.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_square_tag.dart';

// —— 颜色（原版色值；紫色统一为品牌紫）——————————————————————————————
const Color _kCardGreyBg = Color(0xFFF5F6FA);
const Color _kBorderLine = Color(0xFFCECED1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextDarker = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kGreen = Color(0xFF12CE51);
const Color _kGreenSoftBg = Color(0xFFE4FFED);
const Color _kRed = Color(0xFFFF323C);
const Color _kPurple = AppColors.brand;
const Color _kPurpleLight = AppColors.brandSoft;
const Color _kPurpleGlow = Color(0xFFD7D2FF);

/// 顶部定位文案的语义：进行中 / 成功 / 失败。
enum _LocationStatusKind { loading, success, error }

Color _statusColor(_LocationStatusKind k) => switch (k) {
  _LocationStatusKind.loading => _kTextHint,
  _LocationStatusKind.success => _kGreen,
  _LocationStatusKind.error => _kRed,
};

enum _PunchKind {
  morningOn('上午上班'),
  morningOff('上午下班'),
  afternoonOn('下午上班'),
  afternoonOff('下午下班');

  const _PunchKind(this.label);
  final String label;

  static _PunchKind at(DateTime t) {
    final h = t.hour;
    if (h < 11) return morningOn;
    if (h < 13) return morningOff;
    if (h < 15) return afternoonOn;
    return afternoonOff;
  }
}

class _PunchRecord {
  const _PunchRecord({
    required this.kind,
    required this.time,
    required this.location,
    this.lat,
    this.lng,
    this.accuracyMeters,
  });

  final _PunchKind kind;
  final DateTime time;

  /// 地图反编码得到的地址；没有时回退到经纬度文案。
  final String location;

  /// WGS-84 经纬度（浏览器 geolocation 原始坐标），打卡留痕用；演示记录没有。
  final double? lat;
  final double? lng;
  final double? accuracyMeters;
}

// =============================================================================
// 顶级视图
// =============================================================================

class DormManagerCheckInView extends StatefulWidget {
  const DormManagerCheckInView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<DormManagerCheckInView> createState() => _DormManagerCheckInViewState();
}

class _DormManagerCheckInViewState extends State<DormManagerCheckInView> {
  Timer? _ticker;
  late DateTime _now;
  late List<_PunchRecord> _records;

  /// 最近一次定位结果（WGS-84）：地图落点 + 打卡留痕。
  GeoPosition? _position;
  String _locationStatus = '正在获取定位…';
  _LocationStatusKind _locationStatusKind = _LocationStatusKind.loading;

  /// 地图反编码得到的地址；空时回退到经纬度文案。
  String? _resolvedAddress;

  /// 正在定位，避免按钮重入。
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _records = _demoRecords();
    // 圆形按钮上的时间照原版走到秒。
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchLocation());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationStatus = '正在获取定位…';
      _locationStatusKind = _LocationStatusKind.loading;
    });
    try {
      final pos = await getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _position = pos;
        _resolvedAddress = null;
        _locationStatus = '已定位 · 精度 ${pos.accuracyMeters.toStringAsFixed(0)} 米';
        _locationStatusKind = _LocationStatusKind.success;
      });
      unawaited(_resolveAddress(pos));
    } on GeoException catch (e) {
      debugPrint('dorm check-in location failed: $e');
      if (!mounted) return;
      setState(() {
        _locationStatus = e.userMessage;
        _locationStatusKind = _LocationStatusKind.error;
      });
    } catch (e) {
      debugPrint('dorm check-in location failed: $e');
      if (!mounted) return;
      setState(() {
        _locationStatus = '获取定位失败，请重试';
        _locationStatusKind = _LocationStatusKind.error;
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _resolveAddress(GeoPosition pos) async {
    final address = await BaiduGeoService.reverseGeocode(
      lat: pos.lat,
      lng: pos.lng,
    );
    if (!mounted || address == null || address.isEmpty) return;
    _onMapAddressResolved(address);
  }

  void _onMapAddressResolved(String address) {
    if (!mounted) return;
    setState(() => _resolvedAddress = address);
  }

  String get _currentLocationDisplay {
    final address = _resolvedAddress;
    if (address != null && address.isNotEmpty) return address;
    final p = _position;
    if (p != null) {
      return '纬度 ${p.lat.toStringAsFixed(5)} / 经度 ${p.lng.toStringAsFixed(5)}';
    }
    return _locationStatusKind == _LocationStatusKind.error ? '未获取到定位' : '定位中';
  }

  String? get _coordinateLine {
    final p = _position;
    if (p == null) return null;
    return '经纬度 ${p.lat.toStringAsFixed(5)}°N, ${p.lng.toStringAsFixed(5)}°E';
  }

  String _formatClock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  void _onPunch() {
    final p = _position;
    if (p == null) return;
    final now = DateTime.now();
    final kind = _PunchKind.at(now);
    setState(() {
      _records = [
        _PunchRecord(
          kind: kind,
          time: now,
          location: _currentLocationDisplay,
          lat: p.lat,
          lng: p.lng,
          accuracyMeters: p.accuracyMeters,
        ),
        ..._records,
      ];
    });
    AppToast.show(context, '${kind.label}打卡成功');
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SmartCampusSecondaryPageShell(
      bodyTopClipRadius: 8,
      header: SmartCampusPageBanner(
        title: '到岗打卡',
        subtitle: '在指定区域内打卡，下方可查看本人记录',
        onBack: widget.onBack,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PunchPanel(
            clock: _formatClock(_now),
            punchLabel: '${_PunchKind.at(_now).label}打卡',
            locationStatus: _locationStatus,
            locationStatusKind: _locationStatusKind,
            locationAddress: _currentLocationDisplay,
            coordinateLine: _coordinateLine,
            position: _position,
            locating: _locating,
            onRefreshLocation: _fetchLocation,
            onPunch: _onPunch,
            onAddressResolved: _onMapAddressResolved,
          ),
          SizedBox(height: ui(16)),
          Text(
            '我的打卡记录',
            style: TextStyle(
              fontSize: ui(18),
              color: _kTextDarker,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(16)),
          _RecordsGrid(records: _records),
        ],
      ),
    );
  }
}

// =============================================================================
// 大圆形打卡主面板
// =============================================================================

class _PunchPanel extends StatelessWidget {
  const _PunchPanel({
    required this.clock,
    required this.punchLabel,
    required this.locationStatus,
    required this.locationStatusKind,
    required this.locationAddress,
    required this.coordinateLine,
    required this.position,
    required this.locating,
    required this.onRefreshLocation,
    required this.onPunch,
    required this.onAddressResolved,
  });

  final String clock;
  final String punchLabel;
  final String locationStatus;
  final _LocationStatusKind locationStatusKind;
  final String locationAddress;
  final String? coordinateLine;
  final GeoPosition? position;
  final bool locating;
  final VoidCallback onRefreshLocation;
  final VoidCallback onPunch;
  final ValueChanged<String> onAddressResolved;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final statusColor = _statusColor(locationStatusKind);
    final failed = locationStatusKind == _LocationStatusKind.error;
    final coordinates = coordinateLine;
    return Container(
      width: double.infinity,
      height: ui(439),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景：地图。整体作为面板背景，圆形打卡按钮叠在中心。
          Positioned.fill(
            child: BaiduMapView(
              lat: position?.lat,
              lng: position?.lng,
              label: '当前位置',
              onAddressResolved: onAddressResolved,
            ),
          ),
          // 顶部信息条：定位状态 + 详细地址 + 经纬度。
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(12)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.94),
                    Colors.white.withValues(alpha: 0.72),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: ui(22),
                    color: statusColor,
                  ),
                  SizedBox(width: ui(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locationAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(14),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                            height: 1.35,
                          ),
                        ),
                        if (coordinates != null) ...[
                          SizedBox(height: ui(4)),
                          Text(
                            coordinates,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ui(11),
                              color: _kTextHint,
                              fontFamily: 'PingFang SC',
                              height: 1.2,
                            ),
                          ),
                        ],
                        SizedBox(height: ui(4)),
                        Text(
                          locationStatus,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: statusColor,
                            fontFamily: 'PingFang SC',
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  _RefreshLocationButton(
                    label: failed ? '重新获取定位' : '获取当前定位',
                    onTap: onRefreshLocation,
                    busy: locating,
                  ),
                ],
              ),
            ),
          ),
          // 底部半透明条，避免地图被大按钮完全挡住时仍能看到下方区域。
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: ui(48),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 中央大圆形打卡按钮；没有定位时禁用并说明原因。
          Center(
            child: _BigPunchButton(
              label: punchLabel,
              clock: clock,
              hint: position == null
                  ? (failed ? '获取定位后才能打卡' : '定位成功后可打卡')
                  : null,
              onTap: position == null ? null : onPunch,
            ),
          ),
        ],
      ),
    );
  }
}

/// 右上「获取当前定位」：白底胶囊，1px `#CECED1` 描边，14 图标 + 12 号字。
class _RefreshLocationButton extends StatelessWidget {
  const _RefreshLocationButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppPressable(
      onTap: busy ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(4)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderLine, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              AppLoadingIndicator(size: ui(14))
            else
              Icon(
                Icons.my_location_rounded,
                size: ui(14),
                color: const Color(0xFF1C274C),
              ),
            SizedBox(width: ui(4)),
            Text(
              busy ? '定位中…' : label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 中央 160 圆形大按钮（原版数值）：
///
/// - 底圆：180° 线性渐变，品牌紫（14%）→ 浅品牌紫；
/// - 内嵌光晕：径向渐变透明 → 半透明 `#D7D2FF`（stops 0.6 → 1.0），模拟
///   `box-shadow: 0 0 20px #D7D2FF inset`；没有外侧阴影；
/// - 文字：打卡类型 16/600 + 时间 20/600，白色，行高 1.0，间距 11。
///
/// [onTap] 为 null（还没有定位）时是浅色禁用态，[hint] 在按钮下方说明原因。
class _BigPunchButton extends StatelessWidget {
  const _BigPunchButton({
    required this.label,
    required this.clock,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String clock;
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final enabled = onTap != null;
    final fg = enabled ? Colors.white : _kTextSecondary;
    final hintText = hint;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AppPressable(
          onTap: onTap,
          semanticLabel: label,
          child: SizedBox(
            width: ui(160),
            height: ui(160),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: ui(160),
                  height: ui(160),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: enabled
                          ? const [_kPurple, _kPurpleLight]
                          : const [AppColors.brandTint, AppColors.brandWash],
                      stops: const [0.14, 1.0],
                    ),
                  ),
                ),
                if (enabled)
                  IgnorePointer(
                    child: Container(
                      width: ui(160),
                      height: ui(160),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _kPurpleGlow.withValues(alpha: 0),
                            _kPurpleGlow.withValues(alpha: 0.55),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: ui(16),
                        color: fg,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(height: ui(11)),
                    Text(
                      clock,
                      style: TextStyle(
                        fontSize: ui(20),
                        color: fg,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (hintText != null)
          Positioned(
            top: ui(168),
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(8),
                  vertical: ui(4),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: Text(
                  hintText,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// 我的打卡记录 双列卡片网格
// =============================================================================

class _RecordsGrid extends StatelessWidget {
  const _RecordsGrid({required this.records});

  final List<_PunchRecord> records;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (records.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(40)),
        child: Center(
          child: Text(
            '暂无打卡记录',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        // 970 主区 - 16 列间距，左右各 1 → 单卡宽 (W - 16) / 2。
        final cardW = (c.maxWidth - ui(16)) / 2;
        return Wrap(
          spacing: ui(16),
          runSpacing: ui(12),
          children: [
            for (final r in records)
              SizedBox(
                // 向下取整到 0.01，避免浮点误差把第二列挤到下一行。
                width: (cardW * 100).floorToDouble() / 100,
                child: _RecordCard(record: r),
              ),
          ],
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final _PunchRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final lat = record.lat;
    final lng = record.lng;
    final accuracy = record.accuracyMeters;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(12)),
        image: const DecorationImage(
          image: AssetImage(AppAssets.dormCheckPunchRecordCardBg),
          fit: BoxFit.fill,
          alignment: Alignment.centerRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                record.kind.label,
                style: TextStyle(
                  fontSize: ui(16),
                  color: Colors.black,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
              // 原版内距 4×2、12 号字行高 1.27 → 高 19.24。
              const SmartCampusSquareTag(
                label: '正常',
                background: _kGreenSoftBg,
                foreground: _kGreen,
                height: 19.24,
                horizontalPadding: 4,
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ui(16)),
            decoration: BoxDecoration(
              color: _kCardGreyBg,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RecordKeyValue(
                  label: '打卡时间：',
                  value: campusDateTime(record.time),
                ),
                SizedBox(height: ui(6)),
                _RecordKeyValue(label: '打卡位置：', value: record.location),
                if (lat != null && lng != null) ...[
                  SizedBox(height: ui(6)),
                  _RecordKeyValue(
                    label: '定位坐标：',
                    value:
                        '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                        '${accuracy != null ? '（误差约 ${accuracy.toStringAsFixed(0)} 米）' : ''}',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordKeyValue extends StatelessWidget {
  const _RecordKeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 演示记录：最近一个工作日的四次打卡，地点为两栋学生公寓的值班室。
// =============================================================================

List<_PunchRecord> _demoRecords() {
  final base = DemoClock.now().subtract(const Duration(days: 1));
  DateTime at(int h, int m) => DateTime(base.year, base.month, base.day, h, m);
  return [
    _PunchRecord(
      kind: _PunchKind.afternoonOff,
      time: at(17, 36),
      location: '男生公寓2号楼 值班室',
    ),
    _PunchRecord(
      kind: _PunchKind.afternoonOn,
      time: at(13, 27),
      location: '女生公寓1号楼 值班室',
    ),
    _PunchRecord(
      kind: _PunchKind.morningOff,
      time: at(12, 3),
      location: '女生公寓1号楼 值班室',
    ),
    _PunchRecord(
      kind: _PunchKind.morningOn,
      time: at(7, 52),
      location: '女生公寓1号楼 值班室',
    ),
  ];
}
