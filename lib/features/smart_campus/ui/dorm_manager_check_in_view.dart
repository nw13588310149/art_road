// =============================================================================
// 宿管端「到岗打卡」
//
// 入口：宿管工作台快捷入口「到岗打卡」→ controller.openDormCheckInManagement()
//      → SmartCampusPage 路由到本视图；页头返回 → onBack。
//
// 结构：AppPageHeader → 打卡面板（地图底 + 顶部定位信息条 + 中央圆形打卡
//      按钮）→「我的打卡记录」双列卡片。定位成功前打卡按钮禁用。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

import '../../../core/demo/demo_clock.dart';
import '../data/campus_format.dart';
import '../services/baidu_geo_service.dart';
import '../services/geo_locator.dart';
import 'widgets/baidu_map_view.dart';
import 'widgets/smart_campus_page_banner.dart';

/// 顶部定位文案的语义：进行中 / 成功 / 失败。
enum _LocationStatusKind { loading, success, error }

Color _statusColor(_LocationStatusKind k) => switch (k) {
  _LocationStatusKind.loading => AppColors.textTertiary,
  _LocationStatusKind.success => AppColors.success,
  _LocationStatusKind.error => AppColors.danger,
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
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = DateTime.now();
      if (next.minute != _now.minute) setState(() => _now = next);
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
    return SmartCampusSecondaryPageShell(
      header: AppPageHeader(
        title: '到岗打卡',
        subtitle: '在指定区域内打卡，下方可查看本人记录',
        onBack: widget.onBack,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PunchPanel(
            clock: campusClock(_now),
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
          const SizedBox(height: AppSpace.s24),
          const AppSectionHeader(title: '我的打卡记录'),
          const SizedBox(height: AppSpace.s12),
          _RecordsGrid(records: _records),
        ],
      ),
    );
  }
}

// =============================================================================
// 打卡面板
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
    final statusColor = _statusColor(locationStatusKind);
    final failed = locationStatusKind == _LocationStatusKind.error;
    return Container(
      height: 440,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: BaiduMapView(
              lat: position?.lat,
              lng: position?.lng,
              label: '当前位置',
              onAddressResolved: onAddressResolved,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s12,
                AppSpace.s16,
                AppSpace.s12,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      failed
                          ? Icons.location_off_outlined
                          : Icons.location_on_outlined,
                      size: 20,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locationAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body14Strong.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        Text(
                          [locationStatus, ?coordinateLine].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption12.copyWith(
                            color: failed
                                ? AppColors.danger
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  AppButton(
                    label: failed ? '重新获取' : '刷新定位',
                    icon: Icons.my_location_rounded,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    loading: locating,
                    onTap: locating ? null : onRefreshLocation,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            top: 72,
            child: Center(
              child: _PunchButton(
                label: punchLabel,
                clock: clock,
                hint: position == null
                    ? (failed ? '获取定位后才能打卡' : '定位成功后可打卡')
                    : null,
                onTap: position == null ? null : onPunch,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 中央圆形打卡按钮：品牌紫实底；没有定位时转灰并在下方说明原因。
class _PunchButton extends StatelessWidget {
  const _PunchButton({
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
    final enabled = onTap != null;
    final fg = enabled ? AppColors.surface : AppColors.textTertiary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppPressable(
          onTap: onTap,
          enabled: enabled,
          semanticLabel: label,
          child: Container(
            width: 152,
            height: 152,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? AppColors.brand : AppColors.surfaceSubtle,
              border: enabled ? null : Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.title16.copyWith(color: fg)),
                const SizedBox(height: AppSpace.s4),
                Text(clock, style: AppText.number(size: 20, color: fg)),
              ],
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: AppSpace.s8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s12,
              vertical: AppSpace.s4,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.br8,
            ),
            child: Text(
              hint!,
              style: AppText.caption12.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// 我的打卡记录（双列卡片）
// =============================================================================

class _RecordsGrid extends StatelessWidget {
  const _RecordsGrid({required this.records});

  final List<_PunchRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const AppCard(
        child: AppEmptyState(
          icon: Icons.fact_check_outlined,
          title: '还没有打卡记录',
          description: '到岗后在上方打卡，记录会出现在这里',
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final cardW = (c.maxWidth - AppSpace.s16) / 2;
        return Wrap(
          spacing: AppSpace.s16,
          runSpacing: AppSpace.s12,
          children: [
            for (final r in records)
              SizedBox(
                width: cardW,
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
    final lat = record.lat;
    final lng = record.lng;
    final accuracy = record.accuracyMeters;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.kind.label,
                  style: AppText.title16.copyWith(color: AppColors.ink),
                ),
              ),
              const AppStatusTag(label: '正常', tone: AppTone.success),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          _RecordKeyValue(label: '打卡时间', value: campusDateTime(record.time)),
          const SizedBox(height: AppSpace.s4),
          _RecordKeyValue(label: '打卡位置', value: record.location),
          if (lat != null && lng != null) ...[
            const SizedBox(height: AppSpace.s4),
            _RecordKeyValue(
              label: '定位坐标',
              value:
                  '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                  '${accuracy != null ? '（误差约 ${accuracy.toStringAsFixed(0)} 米）' : ''}',
            ),
          ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: AppText.body13.copyWith(color: AppColors.textTertiary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppText.body13.copyWith(color: AppColors.ink),
          ),
        ),
      ],
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
