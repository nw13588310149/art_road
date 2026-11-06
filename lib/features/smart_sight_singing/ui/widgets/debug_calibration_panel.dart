import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:the_road_of_music_flutter/core/theme/app_font.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../audio/pitch_track.dart';
import '../../config/smart_sight_singing_tuning.dart';
import '../../state/smart_sight_singing_controller.dart';
import '../../state/smart_sight_singing_state.dart';
import 'sight_singing_action_button.dart';

/// 智能视唱调试面板：实时指标 + 关键参数滑条。
///
/// 设计目标：
/// - 在真机调试时即时改参数（音准容差、麦克风延迟、串音阈值、稳定平滑…），
///   全链路实时生效；
/// - 调到满意值后可一键复位为默认值；
/// - 不影响生产用户：只有点击页面右上角「调试」按钮才会弹出。
class DebugCalibrationPanel extends ConsumerStatefulWidget {
  const DebugCalibrationPanel({super.key});

  @override
  ConsumerState<DebugCalibrationPanel> createState() =>
      _DebugCalibrationPanelState();
}

class _DebugCalibrationPanelState
    extends ConsumerState<DebugCalibrationPanel> {
  late final VoidCallback _tuningListener;

  @override
  void initState() {
    super.initState();
    _tuningListener = () {
      if (!mounted) return;
      setState(() {});
      ref
          .read(smartSightSingingControllerProvider.notifier)
          .onTuningExternallyChanged();
    };
    SightSingingTuning.instance.addListener(_tuningListener);
  }

  @override
  void dispose() {
    SightSingingTuning.instance.removeListener(_tuningListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartSightSingingControllerProvider);
    final controller = ref.read(smartSightSingingControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;
    final tuning = SightSingingTuning.instance;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: ui(400),
        margin: EdgeInsets.only(left: ui(8)),
        padding: EdgeInsets.fromLTRB(ui(20), ui(10), ui(20), ui(20)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(16)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(-2, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              hasOverride: tuning.hasAnyOverride,
              overrideCount: tuning.overrideCount,
              onClose: () => controller.setDebugPanelVisible(false),
            ),
            SizedBox(height: ui(4)),
            _LiveMetricsCard(state: state),
            SizedBox(height: ui(16)),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(title: '评分 / 打分链路', children: [
                      _IntSlider(
                        label: '麦克风延迟补偿',
                        unit: 'ms',
                        value: tuning.micLatencyMs,
                        min: 0,
                        max: 300,
                        divisions: 60,
                        onChanged: (v) => tuning.setMicLatencyMs(v),
                        hint: '系统/外放越慢越要调大；调小避免「评分晚于实唱」',
                      ),
                      _IntSlider(
                        label: '提前演唱窗口',
                        unit: 'ms',
                        value: tuning.earlySingMs,
                        min: 0,
                        max: 300,
                        divisions: 30,
                        onChanged: (v) => tuning.setEarlySingMs(v),
                      ),
                      _IntSlider(
                        label: '延迟离音窗口',
                        unit: 'ms',
                        value: tuning.lateSingMs,
                        min: 0,
                        max: 400,
                        divisions: 40,
                        onChanged: (v) => tuning.setLateSingMs(v),
                      ),
                      _DoubleSlider(
                        label: '命中容差 (Good)',
                        unit: 'cents',
                        value: tuning.defaultStandardCents,
                        min: 30,
                        max: 200,
                        divisions: 34,
                        onChanged: (v) => tuning.setDefaultStandardCents(v),
                        hint: '专业课堂可压到 60~80；公开课/初学 100~120',
                      ),
                      _DoubleSlider(
                        label: 'Perfect 容差',
                        unit: 'cents',
                        value: tuning.perfectCentsAtDefault,
                        min: 15,
                        max: 90,
                        divisions: 15,
                        onChanged: (v) => tuning.setPerfectCentsAtDefault(v),
                      ),
                      _DoubleSlider(
                        label: 'OK 容差',
                        unit: 'cents',
                        value: tuning.okCentsAtDefault,
                        min: 60,
                        max: 240,
                        divisions: 36,
                        onChanged: (v) => tuning.setOkCentsAtDefault(v),
                      ),
                      _BoolRow(
                        label: '严格音域（关闭八度归一）',
                        value: !tuning.octaveNormalizeScoring,
                        onChanged: (v) =>
                            tuning.setOctaveNormalizeScoring(!v),
                        hint: '关闭后唱错八度直接 miss，更适合视唱考试',
                      ),
                    ]),
                    _Section(title: '实时音高 / YIN', children: [
                      _DoubleSlider(
                        label: '最低 RMS',
                        unit: '',
                        value: tuning.realtimeMinRms,
                        min: 40,
                        max: 800,
                        divisions: 76,
                        onChanged: (v) => tuning.setRealtimeMinRms(v),
                        hint: '高=抗噪，低=灵敏；轻声教室建议 80~150',
                      ),
                      _DoubleSlider(
                        label: '帧最低置信度',
                        unit: '',
                        value: tuning.frameMinConfidence,
                        min: 0.15,
                        max: 0.85,
                        divisions: 28,
                        decimals: 2,
                        onChanged: (v) => tuning.setFrameMinConfidence(v),
                      ),
                      _DoubleSlider(
                        label: '自相关最低置信度',
                        unit: '',
                        value: tuning.autocorrelationMinCorrelation,
                        min: 0.15,
                        max: 0.7,
                        divisions: 22,
                        decimals: 2,
                        onChanged: (v) =>
                            tuning.setAutocorrelationMinCorrelation(v),
                      ),
                      _IntSlider(
                        label: '稳定帧数',
                        unit: '帧',
                        value: tuning.stableFrameCount,
                        min: 1,
                        max: 6,
                        divisions: 5,
                        onChanged: (v) => tuning.setStableFrameCount(v),
                        hint: '高=稳但响应慢；通常 2~3',
                      ),
                      _DoubleSlider(
                        label: '稳定相对差',
                        unit: '',
                        value: tuning.stableFrequencyDiffRatio,
                        min: 0.02,
                        max: 0.20,
                        divisions: 18,
                        decimals: 3,
                        onChanged: (v) =>
                            tuning.setStableFrequencyDiffRatio(v),
                      ),
                      _DoubleSlider(
                        label: '平滑置信度下限',
                        unit: '',
                        value: tuning.smoothedConfidenceFloor,
                        min: 0.3,
                        max: 0.85,
                        divisions: 22,
                        decimals: 2,
                        onChanged: (v) =>
                            tuning.setSmoothedConfidenceFloor(v),
                      ),
                      _IntSlider(
                        label: '静音重置等待',
                        unit: 'ms',
                        value: tuning.silenceResetSmoothingMs,
                        min: 60,
                        max: 600,
                        divisions: 54,
                        onChanged: (v) =>
                            tuning.setSilenceResetSmoothingMs(v),
                        hint: '静音超过该时长后丢弃旧的稳定值（修过的 bug）',
                      ),
                    ]),
                    _Section(title: '人声门控 / 串音过滤', children: [
                      _DoubleSlider(
                        label: '无声跟唱最低响度',
                        unit: '',
                        value: tuning.visualOnlyMinAmplitude,
                        min: 0.002,
                        max: 0.05,
                        divisions: 48,
                        decimals: 3,
                        onChanged: (v) =>
                            tuning.setVisualOnlyMinAmplitude(v),
                      ),
                      _DoubleSlider(
                        label: '有伴奏最低响度',
                        unit: '',
                        value: tuning.accompanimentMinAmplitude,
                        min: 0.005,
                        max: 0.08,
                        divisions: 75,
                        decimals: 3,
                        onChanged: (v) =>
                            tuning.setAccompanimentMinAmplitude(v),
                      ),
                      _DoubleSlider(
                        label: '串音最大响度',
                        unit: '',
                        value: tuning.bleedMatchMaxAmplitude,
                        min: 0.02,
                        max: 0.20,
                        divisions: 36,
                        decimals: 3,
                        onChanged: (v) =>
                            tuning.setBleedMatchMaxAmplitude(v),
                      ),
                      _DoubleSlider(
                        label: '串音音高窗口',
                        unit: 'cents',
                        value: tuning.bleedMatchMaxCents,
                        min: 3,
                        max: 40,
                        divisions: 37,
                        onChanged: (v) => tuning.setBleedMatchMaxCents(v),
                      ),
                      _DoubleSlider(
                        label: '强人声额外响度',
                        unit: '',
                        value: tuning.strongVoiceExtraAmplitude,
                        min: 0.005,
                        max: 0.12,
                        divisions: 23,
                        decimals: 3,
                        onChanged: (v) =>
                            tuning.setStrongVoiceExtraAmplitude(v),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            SizedBox(height: ui(16)),
            _Actions(
              onReset: tuning.hasAnyOverride
                  ? () async {
                      await tuning.resetAll();
                      if (!context.mounted) return;
                      AppToast.showSuccess(context, '已恢复默认参数');
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.hasOverride,
    required this.overrideCount,
    required this.onClose,
  });

  final bool hasOverride;
  final int overrideCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: ui(3.5),
              height: ui(15),
              decoration: BoxDecoration(
                color: const Color(0xFF8741FF),
                borderRadius: BorderRadius.circular(ui(6)),
              ),
            ),
            SizedBox(width: ui(4)),
            Expanded(
              child: Text(
                '调试面板',
                style: TextStyle(
                  fontSize: ui(16),
                  fontWeight: AppFont.w600,
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: ui(32),
                height: ui(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: const Color(0xFFF3F2F3)),
                ),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  AppAssets.smartSightSingingClose,
                  width: ui(32),
                  height: ui(32),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
        Text(
          hasOverride
              ? '已自定义 $overrideCount 项参数（已本地持久化）'
              : '所有参数为默认值',
          style: TextStyle(
            fontSize: ui(12),
            color: const Color(0xFFCECED1),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _LiveMetricsCard extends StatelessWidget {
  const _LiveMetricsCard({required this.state});

  final SightSingingState state;

  String _midiName(double midi) {
    if (midi < 0 || !midi.isFinite) return '--';
    return PitchUtils.midiToNoteName(midi);
  }

  Widget _metricsRow(List<({String label, String value})> cells) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final cell in cells)
          Expanded(
            child: _Metric(label: cell.label, value: cell.value),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cents = state.lastCents;
    final refMidi = state.lastRefMidi;
    final playbackMidi = state.lastPlaybackMidi;
    final userMidi = state.currentUserMidi;
    final amplitude = state.currentUserAmplitude;

    final userValue = userMidi >= 0
        ? '${_midiName(userMidi)} · ${state.lastFrequencyHz.toStringAsFixed(1)} Hz'
        : '- -';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(20), vertical: ui(18)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _metricsRow([
            (label: '你的音', value: userValue),
            (label: '参考', value: _midiName(refMidi)),
            (label: '伴奏', value: _midiName(playbackMidi)),
          ]),
          SizedBox(height: ui(18)),
          _metricsRow([
            (
              label: '偏差',
              value: cents.isFinite
                  ? '${cents > 0 ? '+' : ''}${cents.round()}c'
                  : '- -',
            ),
            (
              label: '置信',
              value: state.lastFrameConfidence > 0
                  ? state.lastFrameConfidence.toStringAsFixed(2)
                  : '- -',
            ),
            (
              label: '振幅',
              value: amplitude > 0
                  ? amplitude.toStringAsFixed(3)
                  : '- -',
            ),
          ]),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFFB6B5BB),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(10)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(18),
            fontWeight: AppFont.w600,
            color: const Color(0xFF0B081A),
            fontFamily: 'Manrope',
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          Container(
            height: ui(0.5),
            margin: EdgeInsets.symmetric(vertical: ui(8)),
            color: const Color(0xFFF3F2F3),
          ),
        );
      }
    }
    return Padding(
      padding: EdgeInsets.only(top: ui(12), bottom: ui(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: ui(12)),
            child: Text(
              title,
              style: TextStyle(
                fontSize: ui(14),
                fontWeight: AppFont.w500,
                color: Colors.black,
                fontFamily: 'PingFang SC',
                height: 20 / 14,
              ),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}

class _IntSlider extends StatelessWidget {
  const _IntSlider({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String unit;
  final int value;
  final int min;
  final int max;
  final int divisions;
  final ValueChanged<int> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return _SliderRow(
      label: label,
      valueLabel: '$value$unit',
      hint: hint,
      slider: Slider(
        value: value.clamp(min, max).toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: divisions,
        onChanged: (v) => onChanged(v.round()),
      ),
    );
  }
}

class _DoubleSlider extends StatelessWidget {
  const _DoubleSlider({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.decimals = 1,
    this.hint,
  });

  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final int decimals;
  final ValueChanged<double> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return _SliderRow(
      label: label,
      valueLabel: '${value.toStringAsFixed(decimals)}$unit',
      hint: hint,
      slider: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.slider,
    this.hint,
  });

  final String label;
  final String valueLabel;
  final Widget slider;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: ui(12),
                  color: const Color(0xFF6D6B75),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(6)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
              ),
              child: Text(
                valueLabel,
                style: TextStyle(
                  fontSize: ui(12),
                  color: Colors.black,
                  fontFamily: 'Barlow',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: ui(4),
            thumbShape: _ShadowThumbShape(radius: ui(6)),
            overlayShape: RoundSliderOverlayShape(overlayRadius: ui(14)),
            overlayColor: const Color(0x298741FF),
            activeTrackColor: Colors.black,
            inactiveTrackColor: const Color(0xFFE1E2E5),
            thumbColor: Colors.black,
          ),
          child: slider,
        ),
        if (hint != null)
          Padding(
            padding: EdgeInsets.only(bottom: ui(2)),
            child: Text(
              hint!,
              style: TextStyle(
                fontSize: ui(10),
                color: const Color(0xFFCECED1),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ),
      ],
    );
  }
}

/// 滑条 thumb：黑色实心圆 + 白色描边 + 阴影，匹配设计稿。
class _ShadowThumbShape extends SliderComponentShape {
  const _ShadowThumbShape({required this.radius});

  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Colors.black.withValues(alpha: 0.12),
      4,
      true,
    );
    canvas.drawCircle(center, radius, Paint()..color = Colors.black);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white,
    );
  }
}

class _BoolRow extends StatelessWidget {
  const _BoolRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: ui(12),
                  color: const Color(0xFF6D6B75),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ),
            _SightSingingToggleSwitch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
        if (hint != null)
          Text(
            hint!,
            style: TextStyle(
              fontSize: ui(10),
              color: const Color(0xFFCECED1),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
      ],
    );
  }
}

/// 与记分板「考试模式」开关一致：44×24 轨道，开启 #A773FF，关闭 #D7D7DE。
class _SightSingingToggleSwitch extends StatelessWidget {
  const _SightSingingToggleSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onChanged == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: ui(44),
          height: ui(24),
          padding: EdgeInsets.all(ui(2)),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? const Color(0xFFA773FF) : const Color(0xFFD7D7DE),
            borderRadius: BorderRadius.circular(ui(12)),
          ),
          child: Container(
            width: ui(20),
            height: ui(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onReset});

  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SightSingingGradientActionButton(
        icon: Icons.mic_none_rounded,
        label: '复位',
        onTap: onReset,
      ),
    );
  }
}
