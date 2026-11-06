import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/scaled_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_navigator.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';
import '../audio/ktv_scoring.dart';
import '../audio/pitch_track.dart';
import '../config/smart_sight_singing_config.dart';
import '../config/smart_sight_singing_tuning.dart';
import '../state/smart_sight_singing_controller.dart';
import '../state/smart_sight_singing_state.dart';
import 'widgets/debug_calibration_panel.dart';
import 'widgets/karaoke_pitch_track.dart';
import 'widgets/osmd_score_viewer.dart';
import 'widgets/score_sight_reading_track.dart';
import 'widgets/sight_singing_action_button.dart';

/// 智能视唱主页：内置 demo.mid → MIDI 参考轨 → 跟唱实时打分。
class SmartSightSingingPage extends ConsumerStatefulWidget {
  const SmartSightSingingPage({super.key});

  @override
  ConsumerState<SmartSightSingingPage> createState() =>
      _SmartSightSingingPageState();
}

class _SmartSightSingingPageState extends ConsumerState<SmartSightSingingPage> {
  var _precachedActionImages = false;

  @override
  void initState() {
    super.initState();
    unawaited(SightSingingTuning.instance.ensureLoaded());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(smartSightSingingControllerProvider.notifier);
      final id = _parseTextbookId(ModalRoute.of(context)?.settings.arguments);
      if (id == null) {
        controller.reportError('缺少教材信息，请从列表进入');
        return;
      }
      unawaited(controller.loadFromTextbook(id));
    });
  }

  int? _parseTextbookId(dynamic raw) {
    if (raw is Map) {
      return int.tryParse(raw['id']?.toString() ?? '');
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precachedActionImages) return;
    _precachedActionImages = true;
    for (final asset in const <String>[
      AppAssets.smartSightSingingPreviewBtn,
      AppAssets.smartSightSingingPreviewPauseBtn,
      AppAssets.smartSightSingingStartBtn,
      AppAssets.smartSightSingingStopBtn,
      AppAssets.smartSightSingingCancelBtn,
    ]) {
      precacheImage(AssetImage(asset), context);
    }
  }

  Future<void> _handleBack(BuildContext context) async {
    final navigator = rootNavigatorKey.currentState ?? Navigator.of(context);
    await ref.read(smartSightSingingControllerProvider.notifier).returnToHome();
    if (!context.mounted) return;

    var reachedCatalog = false;
    navigator.popUntil((route) {
      if (route.settings.name == RoutePaths.smartSinging) {
        reachedCatalog = true;
        return true;
      }
      return route.isFirst;
    });
    if (!reachedCatalog) {
      await navigator.pushReplacementNamed(RoutePaths.smartSinging);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 跟唱结束后弹出「本次视唱结束」结果弹窗。
  Future<void> _showResultDialog() async {
    final controller = ref.read(smartSightSingingControllerProvider.notifier);
    final result = await showScaledDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogContext) {
        final state = ref.read(smartSightSingingControllerProvider);
        final scores = state.completedNoteScores;
        final perfect = scores.where((s) => s.hitLevel == 'perfect').length;
        final good = scores.where((s) => s.hitLevel == 'good').length;
        final ok = scores.where((s) => s.hitLevel == 'ok').length;
        final miss = scores.where((s) => s.hitLevel == 'miss').length;
        final dialogUi = DashboardScaleScope.of(dialogContext).ui;
        return GradientHeaderDialog(
          title: '本次视唱结束',
          headerHeight: 169,
          gradientMidStop: 0.35,
          actionBar: AppDialogActionBar(
            cancelLabel: '重新跟唱',
            confirmLabel: '退出',
            onCancel: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop('restart'),
            onConfirm: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop('exit'),
          ),
          child: Transform.translate(
            offset: Offset(0, -dialogUi(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResultStatCell(label: '准神', value: '$perfect'),
                SizedBox(width: dialogUi(8)),
                _ResultStatCell(label: '优秀', value: '$good'),
                SizedBox(width: dialogUi(8)),
                _ResultStatCell(label: '及格', value: '$ok'),
                SizedBox(width: dialogUi(8)),
                _ResultStatCell(
                  label: '不及格',
                  value: '$miss',
                  valueColor: const Color(0xFFFF323C),
                ),
                SizedBox(width: dialogUi(8)),
                _ResultStatCell(
                  label: '综合得分',
                  value: '${state.currentScore}',
                  valueColor: const Color(0xFF8741FF),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == 'restart' && mounted) {
      unawaited(controller.startSinging());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartSightSingingControllerProvider);
    final controller = ref.read(smartSightSingingControllerProvider.notifier);

    ref.listen(smartSightSingingControllerProvider, (prev, next) {
      if (prev?.stage != SightSingingStage.finished &&
          next.stage == SightSingingStage.finished) {
        unawaited(_showResultDialog());
      }
    });

    final ui = DashboardScaleScope.of(context).ui;

    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(ShellLayoutSpec.panelRadius)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(ui(20), 0, ui(20), 0),
                    child: _Header(
                      onBack: () => unawaited(_handleBack(context)),
                      onToggleDebug: controller.toggleDebugPanel,
                      onScoreModeChanged: controller.setScoreSightReadingMode,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(ui(12), 0, ui(12), ui(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.errorMessage != null) ...[
                            SizedBox(height: ui(12)),
                            if (kDebugMode)
                              _DebugErrorPanel(
                                message: state.errorMessage!,
                                stage: state.stage,
                                onDismiss: controller.dismissError,
                              )
                            else
                              _UserErrorBanner(
                                message:
                                    state.errorMessage!.split('\n').first,
                                onDismiss: controller.dismissError,
                              ),
                          ],
                          SizedBox(height: ui(4)),
                          Expanded(
                            child: _Body(
                              state: state,
                              controller: controller,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (state.debugPanelVisible) const DebugCalibrationPanel(),
          ],
        ),
      ),
    );
  }
}

/// 结果弹窗中的单项统计：上方灰色标签 + 下方浅底数值盒（62×32）。
class _ResultStatCell extends StatelessWidget {
  const _ResultStatCell({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF0B081A),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFF6D6B75),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(8)),
        Container(
          width: ui(62),
          height: ui(32),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(6)),
          ),
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: ui(18),
              color: valueColor,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

/// 正式环境：单行错误提示（不含 stack）。
class _UserErrorBanner extends StatelessWidget {
  const _UserErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: ui(18)),
          SizedBox(width: ui(8)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFFB71C1C),
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
          InkWell(
            onTap: onDismiss,
            child: Padding(
              padding: EdgeInsets.all(ui(4)),
              child: Icon(
                Icons.close,
                size: ui(18),
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 调试阶段：在页面上直接展示完整错误（含 stack），便于排查解码/权限等问题。
class _DebugErrorPanel extends StatelessWidget {
  const _DebugErrorPanel({
    required this.message,
    required this.stage,
    required this.onDismiss,
  });

  final String message;
  final SightSingingStage stage;
  final VoidCallback onDismiss;

  static String _stageLabel(SightSingingStage stage) {
    return switch (stage) {
      SightSingingStage.idle => 'idle',
      SightSingingStage.analyzing => 'analyzing',
      SightSingingStage.selectTrack => 'selectTrack',
      SightSingingStage.ready => 'ready',
      SightSingingStage.preparing => 'preparing',
      SightSingingStage.countdown => 'countdown',
      SightSingingStage.singing => 'singing',
      SightSingingStage.finished => 'finished',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(180),
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.bug_report_outlined,
                color: Colors.red.shade700,
                size: ui(18),
              ),
              SizedBox(width: ui(6)),
              Text(
                '调试错误（stage: ${_stageLabel(stage)}）',
                style: TextStyle(
                  fontSize: ui(13),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB71C1C),
                  fontFamily: 'PingFang SC',
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(ui(8)),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(8),
                    vertical: ui(4),
                  ),
                  child: Text(
                    '关闭',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: const Color(0xFFB71C1C),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                message,
                style: TextStyle(
                  fontSize: ui(12),
                  height: 1.45,
                  color: const Color(0xFF4A1515),
                  fontFamily: 'Consolas',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.onBack,
    required this.onToggleDebug,
    required this.onScoreModeChanged,
  });

  final VoidCallback onBack;
  final VoidCallback onToggleDebug;
  final ValueChanged<bool> onScoreModeChanged;

  static const _practiceTitle = 'AI智能视唱';
  static const _practiceSubtitle =
      '准备就绪:点击下方开始跟唱后看谱视唱（未佩戴耳机会影响评分）';
  static const _examTitle = '视唱考试';
  static const _examSubtitle = '考试模式：不播放旋律伴奏，仍会播放标准音与节拍器';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = DashboardScaleScope.of(context).ui;
    final examMode = ref.watch(
      smartSightSingingControllerProvider.select((s) => s.visualOnlyMode),
    );
    final debugPanelVisible = ref.watch(
      smartSightSingingControllerProvider.select((s) => s.debugPanelVisible),
    );
    final scoreSightReadingMode = ref.watch(
      smartSightSingingControllerProvider.select((s) => s.scoreSightReadingMode),
    );
    final stage = ref.watch(
      smartSightSingingControllerProvider.select((s) => s.stage),
    );
    final scoreModeLocked =
        stage == SightSingingStage.singing ||
        stage == SightSingingStage.preparing ||
        stage == SightSingingStage.countdown;
    final title = examMode ? _examTitle : _practiceTitle;
    final subtitle = examMode ? _examSubtitle : _practiceSubtitle;

    return SizedBox(
      height: ui(72),
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(16),
                    fontWeight: AppFont.w600,
                    color: Colors.black,
                    fontFamily: 'PingFang SC',
                    height: 1,
                  ),
                ),
                SizedBox(height: ui(6)),
                Text(
                  subtitle,
                  maxLines: examMode ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: const Color(0xFFB6B5BB),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: _GlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: debugPanelVisible
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ScoreModeSegmentSwitch(
                          selectedIndex: scoreSightReadingMode ? 0 : 1,
                          onLeftTap: scoreModeLocked
                              ? null
                              : () => onScoreModeChanged(true),
                          onRightTap: scoreModeLocked
                              ? null
                              : () => onScoreModeChanged(false),
                        ),
                        SizedBox(width: ui(8)),
                        _GlassImageButton(
                          asset: AppAssets.smartSightSingingSetIcon,
                          active: false,
                          onTap: onToggleDebug,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});

  final SightSingingState state;
  final SmartSightSingingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    switch (state.stage) {
      case SightSingingStage.idle:
      case SightSingingStage.analyzing:
      case SightSingingStage.selectTrack:
        return _AnalyzingHint(state: state);
      case SightSingingStage.ready:
      case SightSingingStage.preparing:
      case SightSingingStage.countdown:
      case SightSingingStage.singing:
      case SightSingingStage.finished:
        final track = state.track;
        if (track == null || track.isEmpty) {
          return _AnalyzingHint(state: state);
        }
        final preparing = state.stage == SightSingingStage.preparing;
        final countdown = state.stage == SightSingingStage.countdown;
        // 预备 / 倒计时阶段把轨道视图复位到起点，但保持同一棵子树，
        // 不重建 OSMD 谱面（否则 iOS 上会白屏刷新一下）。
        final resetTrackView = preparing || countdown;
        final showNoteDetails =
            state.stage == SightSingingStage.finished &&
            state.completedNoteScores.isNotEmpty;
        return Stack(
          children: [
            Column(
              children: [
                _ScoreBoard(state: state, controller: controller),
                SizedBox(height: ui(16)),
                Expanded(
                  child: _PracticeWorkspace(
                    trackView: _PracticeTrackView(
                      track: track,
                      playbackMs: resetTrackView ? 0 : state.playbackMs,
                      userPoints: resetTrackView
                          ? const <UserPitchPoint>[]
                          : state.userPoints,
                      currentUserMidi: state.currentUserMidi,
                      currentUserAmplitude: state.currentUserAmplitude,
                      scoreSightReadingMode: state.scoreSightReadingMode,
                      musicXmlContent: state.musicXmlContent,
                      musicXmlCursorOnsetMs: state.musicXmlCursorOnsetMs,
                      scoringStandardCents: state.scoringStandardCents,
                    ),
                    controls: _Controls(state: state, controller: controller),
                    extra: showNoteDetails
                        ? _NoteScoresPanel(scores: state.completedNoteScores)
                        : null,
                  ),
                ),
              ],
            ),
            if (preparing) const _PreparingOverlay(),
            if (countdown) _CountdownOverlay(seconds: state.countdownSeconds),
          ],
        );
    }
  }
}

/// 谱面渲染区 + 底部播放控制栏（设计稿为两个独立圆角容器）。
class _PracticeWorkspace extends StatelessWidget {
  const _PracticeWorkspace({
    required this.trackView,
    required this.controls,
    this.extra,
  });

  final Widget trackView;
  final Widget controls;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _PracticeSurface(trackView: trackView, extra: extra)),
        SizedBox(height: ui(12)),
        controls,
      ],
    );
  }
}

/// 设计稿中部浅灰圆角容器：仅承载谱面 / 音高轨（不含底部操作条）。
class _PracticeSurface extends StatelessWidget {
  const _PracticeSurface({
    required this.trackView,
    this.extra,
  });

  final Widget trackView;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(16)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        children: [
          Expanded(child: trackView),
          if (extra != null) ...[SizedBox(height: ui(12)), extra!],
        ],
      ),
    );
  }
}

/// 演唱结束后的「结果分析」：标题 + 四档统计角标 + 横向滚动逐音卡片。
class _NoteScoresPanel extends StatelessWidget {
  const _NoteScoresPanel({required this.scores});

  final List<KtvNoteScore> scores;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final perfectCount = scores.where((s) => s.hitLevel == 'perfect').length;
    final goodCount = scores.where((s) => s.hitLevel == 'good').length;
    final okCount = scores.where((s) => s.hitLevel == 'ok').length;
    final missCount = scores.where((s) => s.hitLevel == 'miss').length;

    return Container(
      height: ui(92),
      padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(12), ui(8)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '结果分析',
                style: TextStyle(
                  fontSize: ui(13),
                  fontWeight: AppFont.w500,
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  height: 1,
                ),
              ),
              SizedBox(width: ui(12)),
              _NoteBadge(
                label: '准神',
                count: perfectCount,
                color: const Color(0xFF40C06C),
                background: const Color(0x3340C06C),
                width: 44,
              ),
              SizedBox(width: ui(4)),
              _NoteBadge(
                label: '优秀',
                count: goodCount,
                color: const Color(0xFF5EA9FF),
                background: const Color(0x4D5EA9FF),
                width: 44,
              ),
              SizedBox(width: ui(4)),
              _NoteBadge(
                label: '及格',
                count: okCount,
                color: const Color(0xFF8741FF),
                background: const Color(0xFFE7D9FF),
                width: 44,
              ),
              SizedBox(width: ui(4)),
              _NoteBadge(
                label: '不及格',
                count: missCount,
                color: const Color(0xFFFF4E7B),
                background: const Color(0xFFFEE4E8),
                width: 53,
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: scores.length,
              separatorBuilder: (_, _) => SizedBox(width: ui(8)),
              itemBuilder: (context, index) {
                final s = scores[index];
                return _NoteChip(index: index + 1, score: s);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBadge extends StatelessWidget {
  const _NoteBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.background,
    required this.width,
  });

  final String label;
  final int count;
  final Color color;
  final Color background;
  final double width;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(width),
      height: ui(14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ui(3)),
      ),
      child: Text(
        '$label $count',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: ui(9),
          color: color,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1,
        ),
      ),
    );
  }
}

class _NoteChip extends StatelessWidget {
  const _NoteChip({required this.index, required this.score});

  final int index;
  final KtvNoteScore score;

  /// 每档等级的 (描边/文字色, 背景色)。
  static (Color, Color) _palette(String level) {
    switch (level) {
      case 'perfect':
        return (const Color(0xFF40C06C), const Color(0x3340C06C));
      case 'good':
        return (const Color(0xFF5EA9FF), const Color(0x335EA9FF));
      case 'ok':
        return (const Color(0xFF8741FF), const Color(0xFFE7D9FF));
      default:
        return (const Color(0xFFFF386B), const Color(0xFFFEE4E8));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (color, background) = _palette(score.hitLevel);
    final centsLabel = score.cents.isFinite
        ? '${score.cents > 0 ? '+' : ''}${score.cents.round()}c'
        : '--';
    return Container(
      width: ui(52),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: color, width: ui(0.6)),
        borderRadius: BorderRadius.circular(ui(7)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '#$index ${PitchUtils.midiToNoteName(score.refMidi)}',
            style: TextStyle(
              fontSize: ui(9),
              color: Colors.black,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
          SizedBox(height: ui(5)),
          Text(
            centsLabel,
            style: TextStyle(
              fontSize: ui(9),
              color: color,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(5)),
          Text(
            '${score.points}',
            style: TextStyle(
              fontSize: ui(9),
              color: color,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeTrackView extends StatelessWidget {
  const _PracticeTrackView({
    required this.track,
    required this.playbackMs,
    required this.userPoints,
    required this.currentUserMidi,
    required this.currentUserAmplitude,
    required this.scoreSightReadingMode,
    required this.scoringStandardCents,
    this.musicXmlContent,
    this.musicXmlCursorOnsetMs = const <int>[],
  });

  final PitchTrack track;
  final int playbackMs;
  final List<UserPitchPoint> userPoints;
  final double currentUserMidi;
  final double currentUserAmplitude;
  final bool scoreSightReadingMode;
  final double scoringStandardCents;
  final String? musicXmlContent;
  final List<int> musicXmlCursorOnsetMs;

  @override
  Widget build(BuildContext context) {
    final scoreTrack = ScoreSightReadingTrack(
      track: track,
      playbackMs: playbackMs,
      userPoints: userPoints,
      currentUserMidi: currentUserMidi,
      currentUserAmplitude: currentUserAmplitude,
      scoringStandardCents: scoringStandardCents,
    );

    final karaokeTrack = KaraokePitchTrack(
      track: track,
      playbackMs: playbackMs,
      userPoints: userPoints,
      currentUserMidi: currentUserMidi,
      currentUserAmplitude: currentUserAmplitude,
      scoringStandardCents: scoringStandardCents,
    );

    final xml = musicXmlContent?.trim() ?? '';
    final Widget scorePane;
    if (xml.isNotEmpty) {
      // OSMD 光标含延音线后续音头；KTV/打分轨仍用合并后的 track.notes。
      final onsetMs = musicXmlCursorOnsetMs.isNotEmpty
          ? musicXmlCursorOnsetMs
          : <int>[for (final event in track.notes) event.startMs];
      scorePane = OsmdScoreViewer(
        musicXml: xml,
        playbackMs: playbackMs,
        onsetMs: onsetMs,
        fallback: scoreTrack,
      );
    } else {
      scorePane = scoreTrack;
    }

    // 双视图常驻 Offstage：切换时不销毁子树；隐藏侧不参与绘制，避免 iOS 白闪。
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: !scoreSightReadingMode,
          child: TickerMode(enabled: scoreSightReadingMode, child: scorePane),
        ),
        Offstage(
          offstage: scoreSightReadingMode,
          child: TickerMode(enabled: !scoreSightReadingMode, child: karaokeTrack),
        ),
      ],
    );
  }
}

class _AnalyzingHint extends StatelessWidget {
  const _AnalyzingHint({required this.state});
  final SightSingingState state;
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final name = state.audioName?.trim();
    final headline = name != null && name.isNotEmpty
        ? '正在解析「$name」…'
        : '正在加载教材详情…';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLoadingIndicator(),
          SizedBox(height: ui(18)),
          Text(
            headline,
            style: TextStyle(
              fontSize: ui(15),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(6)),
          Text(
            '准备跟唱界面，请稍候…',
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF788698),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBoard extends StatelessWidget {
  const _ScoreBoard({required this.state, required this.controller});
  final SightSingingState state;
  final SmartSightSingingController controller;

  /// 相邻标题文字之间的固定间距（设计稿 px）。
  static const _titleGap = 36.0;
  static const _valueBoxWidth = 62.0;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final ref = state.track?.sampleAt(state.playbackMs);
    final refName = ref != null ? PitchUtils.midiToNoteName(ref.midi) : '- -';
    final currentCents = state.currentUserMidi >= 0 && ref != null
        ? PitchUtils.octaveNormalizedCents(state.currentUserMidi, ref.midi)
        : double.nan;
    final isUserPickingUp = state.currentUserMidi < 0 &&
        state.currentUserAmplitude >
            SmartSightSingingViewConfig.pickupLabelMinAmplitude;
    final userName = state.currentUserMidi >= 0
        ? PitchUtils.midiToNoteName(state.currentUserMidi)
        : '- -';
    final centsLabel = currentCents.isFinite
        ? '${currentCents > 0 ? '+' : ''}${currentCents.round()}c'
        : '- -';
    final hitRate = state.scoredCount == 0
        ? '- -'
        : '${(100 * state.hitCount / state.scoredCount).round()}%';

    final examLocked =
        state.isPreviewPlaying ||
        state.stage == SightSingingStage.singing ||
        state.stage == SightSingingStage.preparing ||
        state.stage == SightSingingStage.countdown;

    final metrics = <_ScoreMetricEntry>[
      _ScoreMetricEntry(
        label: '得分',
        value: '${state.currentScore}',
        valueColor: const Color(0xFF8741FF),
      ),
      _ScoreMetricEntry(label: '连击', value: '${state.combo}'),
      _ScoreMetricEntry(label: '命中率', value: hitRate),
      _ScoreMetricEntry(label: '标准音', value: refName),
      _ScoreMetricEntry(
        label: '你的音',
        value: userName,
        valueColor: isUserPickingUp
            ? const Color(0xFF8741FF)
            : const Color(0xFF0B081A),
      ),
      _ScoreMetricEntry(label: '偏差值', value: centsLabel),
    ];

    return Container(
      height: ui(88),
      padding: EdgeInsets.symmetric(horizontal: ui(24)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _ScoreMetricsStrip(ui: ui, metrics: metrics)),
          if (!state.debugPanelVisible) ...[
            SizedBox(width: ui(16)),
            Text(
              '考试模式',
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
            SizedBox(width: ui(12)),
            _ExamModeSwitch(
              value: state.visualOnlyMode,
              onChanged: examLocked ? null : controller.setVisualOnlyMode,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreMetricEntry {
  const _ScoreMetricEntry({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF0B081A),
  });

  final String label;
  final String value;
  final Color valueColor;
}

/// 标题行：文字 + 36px + 文字；数值行在布局后按真实标题左缘对齐。
class _ScoreMetricsStrip extends StatefulWidget {
  const _ScoreMetricsStrip({required this.ui, required this.metrics});

  final double Function(double) ui;
  final List<_ScoreMetricEntry> metrics;

  @override
  State<_ScoreMetricsStrip> createState() => _ScoreMetricsStripState();
}

class _ScoreMetricsStripState extends State<_ScoreMetricsStrip> {
  final _valueRowKey = GlobalKey();
  late List<GlobalKey> _labelKeys;
  List<double> _valueLefts = const [];
  double _contentWidth = 0;

  @override
  void initState() {
    super.initState();
    _labelKeys = _newLabelKeys();
  }

  @override
  void didUpdateWidget(covariant _ScoreMetricsStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metrics.length != widget.metrics.length) {
      _labelKeys = _newLabelKeys();
      _valueLefts = const [];
      _contentWidth = 0;
    }
    _scheduleSync();
  }

  List<GlobalKey> _newLabelKeys() {
    return List<GlobalKey>.generate(widget.metrics.length, (_) => GlobalKey());
  }

  TextStyle _labelStyle() {
    return TextStyle(
      fontSize: widget.ui(14),
      color: const Color(0xFFB6B5BB),
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w400,
      height: 1,
    );
  }

  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncValuePositions());
  }

  void _syncValuePositions() {
    if (!mounted) return;
    final valueRowBox =
        _valueRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (valueRowBox == null) {
      _scheduleSync();
      return;
    }

    final valueBoxW = widget.ui(_ScoreBoard._valueBoxWidth);
    final rowOrigin = valueRowBox.localToGlobal(Offset.zero);
    final lefts = <double>[];
    var maxRight = 0.0;

    for (final key in _labelKeys) {
      final labelBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (labelBox == null) {
        _scheduleSync();
        return;
      }
      final left = labelBox.localToGlobal(Offset.zero).dx - rowOrigin.dx;
      lefts.add(left);
      final right = left + valueBoxW;
      if (right > maxRight) maxRight = right;
    }

    final changed = lefts.length != _valueLefts.length ||
        _contentWidth != maxRight ||
        !_offsetsEqual(lefts, _valueLefts);
    if (changed) {
      setState(() {
        _valueLefts = lefts;
        _contentWidth = maxRight;
      });
    }
  }

  bool _offsetsEqual(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.5) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSync();

    final gap = widget.ui(_ScoreBoard._titleGap);
    final valueBoxH = widget.ui(32);
    final valueBoxW = widget.ui(_ScoreBoard._valueBoxWidth);
    final fallbackWidth = widget.metrics.isEmpty
        ? 0.0
        : widget.metrics.length * valueBoxW +
            (widget.metrics.length - 1) * gap;
    final contentWidth = _contentWidth > 0 ? _contentWidth : fallbackWidth;
    final ready = _valueLefts.length == widget.metrics.length;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.metrics.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Text(
                key: _labelKeys[i],
                widget.metrics[i].label,
                maxLines: 1,
                style: _labelStyle(),
              ),
            ],
          ],
        ),
        SizedBox(height: widget.ui(8)),
        SizedBox(
          key: _valueRowKey,
          width: contentWidth,
          height: valueBoxH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < widget.metrics.length; i++)
                Positioned(
                  left: ready ? _valueLefts[i] : 0,
                  top: 0,
                  child: Opacity(
                    opacity: ready ? 1 : 0,
                    child: _ScoreValueBox(
                      ui: widget.ui,
                      value: widget.metrics[i].value,
                      valueColor: widget.metrics[i].valueColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreValueBox extends StatelessWidget {
  const _ScoreValueBox({
    required this.ui,
    required this.value,
    this.valueColor = const Color(0xFF0B081A),
  });

  final double Function(double) ui;
  final String value;
  final Color valueColor;

  /// 数值行默认 Manrope；含中文（如「识别中」）时改 PingFang，避免回退字体显得偏大。
  static bool _usesPingFang(String value) {
    return value.runes.any((code) => code > 0x7F);
  }

  @override
  Widget build(BuildContext context) {
    final pingFang = _usesPingFang(value);
    return Container(
      width: ui(_ScoreBoard._valueBoxWidth),
      height: ui(32),
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(right: ui(6)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(6)),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(18),
          color: valueColor,
          fontFamily: pingFang ? 'PingFang SC' : 'Manrope',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

/// 设计稿「考试模式」开关：44×24 轨道，开启 #A773FF，关闭浅灰。
class _ExamModeSwitch extends StatelessWidget {
  const _ExamModeSwitch({required this.value, required this.onChanged});

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

/// 用户点击「开始跟唱」后、倒计时前的麦克风/会话准备态。
class _PreparingOverlay extends StatelessWidget {
  const _PreparingOverlay();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Positioned.fill(
      child: Center(
        child: Container(
          width: ui(160),
          padding: EdgeInsets.symmetric(vertical: ui(24), horizontal: ui(16)),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(ui(16)),
            border: Border.all(color: Colors.white, width: ui(2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLoadingIndicator(),
              SizedBox(height: ui(14)),
              Text(
                '正在准备麦克风…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(13),
                  color: const Color(0xFF1A1A1A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                ),
              ),
              SizedBox(height: ui(6)),
              Text(
                '请稍候',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(12),
                  color: const Color(0xFFB6B5BB),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Positioned.fill(
      child: Center(
        child: Container(
          width: ui(128),
          height: ui(128),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(ui(16)),
            border: Border.all(color: Colors.white, width: ui(2)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$seconds',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(80),
                    fontWeight: AppFont.w600,
                    color: const Color(0xFF8741FF),
                    fontFamily: 'Barlow',
                    height: 50 / 80,
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -ui(8)),
                  child: Text(
                    '准备跟唱...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: const Color(0xFFB6B5BB),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部播放条：封面 + 标题/副标题 + 进度条 + 时间 + 试听/跟唱按钮（右侧）。
///
/// 进度数据来源：MusicXML/MIDI 解析成参考音高轨（[PitchTrack]）后由播放调度器
/// 驱动。「总时长 = track.totalMs（旋律）」；MusicXML 预备段（标准音 + 节拍器）
/// 不计入进度条，当前进度 = max(0, playbackMs - playbackLeadInMs)。
class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.controller});
  final SightSingingState state;
  final SmartSightSingingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final track = state.track;
    final totalMs = track?.totalMs ?? 0;
    final preparingOrCountdown =
        state.stage == SightSingingStage.preparing ||
        state.stage == SightSingingStage.countdown;
    final progressPlaybackMs =
        preparingOrCountdown ? 0 : state.playbackMs;
    final currentMs = (progressPlaybackMs - state.playbackLeadInMs).clamp(
      0,
      totalMs == 0 ? 0 : totalMs,
    );
    final ratio = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;

    final title = (state.audioName?.trim().isNotEmpty ?? false)
        ? state.audioName!.trim()
        : '智能视唱';
    final subtitle = state.shortText1?.trim() ?? '';

    return Container(
      height: ui(72),
      padding: EdgeInsets.fromLTRB(ui(12), 0, ui(22), 0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: ui(170),
            child: Row(
              children: [
                Container(
                  width: ui(48),
                  height: ui(48),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(ui(4)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/home/feng.png',
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: ui(12)),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF0B081A),
                          fontSize: ui(15),
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 1,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        SizedBox(height: ui(6)),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFB6B5BB),
                            fontSize: ui(12),
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(16)),
          Expanded(
            child: Transform.translate(
              offset: Offset(-ui(20), 0),
              child: _SightProgressTrack(
                ratio: ratio,
                currentMs: currentMs,
                totalMs: totalMs,
              ),
            ),
          ),
          SizedBox(width: ui(16)),
          SizedBox(
            width: SightSingingImageActionButton.readyControlsSlotWidth(ui),
            child: _ControlButtons(state: state, controller: controller),
          ),
        ],
      ),
    );
  }
}

/// 播放条右侧按钮组：倒计时显示「取消」、跟唱中显示「停止」，
/// 其余状态显示「试听旋律 + 开始跟唱」图片按钮。
class _ControlButtons extends StatelessWidget {
  const _ControlButtons({required this.state, required this.controller});
  final SightSingingState state;
  final SmartSightSingingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final singing = state.stage == SightSingingStage.singing;
    final cancelable =
        state.stage == SightSingingStage.preparing ||
        state.stage == SightSingingStage.countdown;

    Widget buttons;
    if (cancelable) {
      buttons = SightSingingImageActionButton(
        asset: AppAssets.smartSightSingingCancelBtn,
        onTap: () => controller.cancelPreparingOrCountdown(),
      );
    } else if (singing) {
      buttons = SightSingingImageActionButton(
        asset: AppAssets.smartSightSingingStopBtn,
        onTap: state.isStoppingSinging ? null : () => controller.stopSinging(),
      );
    } else {
      buttons = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PreviewMelodyButton(controller: controller),
          SizedBox(width: ui(SightSingingImageActionButton.readyControlsGap)),
          _StartSingingButton(controller: controller),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: buttons,
      ),
    );
  }
}

/// 仅试听按钮随播放态切换切图；与「开始跟唱」解耦。
class _PreviewMelodyButton extends ConsumerWidget {
  const _PreviewMelodyButton({required this.controller});

  final SmartSightSingingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(
      smartSightSingingControllerProvider.select(
        (s) => (s.isPreviewPlaying, s.controlsLocked),
      ),
    );
    final locked = preview.$2;
    return SightSingingToggleImageActionButton(
      primaryAsset: AppAssets.smartSightSingingPreviewBtn,
      alternateAsset: AppAssets.smartSightSingingPreviewPauseBtn,
      showAlternate: preview.$1,
      onTap: locked ? null : () => controller.previewMelody(),
    );
  }
}

/// 就绪态「开始跟唱」：点击后立即进入 preparing 遮罩。
class _StartSingingButton extends ConsumerWidget {
  const _StartSingingButton({required this.controller});

  final SmartSightSingingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(
      smartSightSingingControllerProvider.select((s) => s.controlsLocked),
    );
    return SightSingingImageActionButton(
      asset: AppAssets.smartSightSingingStartBtn,
      onTap: locked ? null : () => controller.startSinging(),
    );
  }
}

/// 只读进度条 + 时间标签（`当前/总时长`）。样式对齐 musicPlay 的
/// 紫色渐变进度条，但不接收手势（视唱不支持任意 seek）。
class _SightProgressTrack extends StatelessWidget {
  const _SightProgressTrack({
    required this.ratio,
    required this.currentMs,
    required this.totalMs,
  });

  final double ratio;
  final int currentMs;
  final int totalMs;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hitHeight = ui(20);
    final trackHeight = ui(4);
    final thumbSize = ui(12);
    final labelStyle = TextStyle(
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w500,
      fontSize: ui(12),
      height: 1,
    );

    return SizedBox(
      height: hitHeight,
      child: Transform.translate(
        offset: Offset(0, ui(2)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final clamped = ratio.clamp(0.0, 1.0);
                  final fillWidth = width * clamped;
                  final thumbLeft = (width - thumbSize) * clamped;
                  return Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: trackHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1E2E5),
                          borderRadius: BorderRadius.circular(ui(23)),
                        ),
                      ),
                      Container(
                        height: trackHeight,
                        width: fillWidth,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFE2D0FF), Color(0xFF8741FF)],
                          ),
                          borderRadius: BorderRadius.circular(ui(23)),
                        ),
                      ),
                      Positioned(
                        left: thumbLeft,
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8741FF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                offset: const Offset(0, 4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              right: 0,
              bottom: ui(14),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _formatMs(currentMs),
                      style: labelStyle.copyWith(
                        color: const Color(0xFF0B081A),
                      ),
                    ),
                    TextSpan(
                      text: '/${_formatMs(totalMs)}',
                      style: labelStyle.copyWith(
                        color: const Color(0xFFB6B5BB),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatMs(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(32),
        height: ui(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        child: Center(
          child: Icon(icon, size: ui(16), color: const Color(0xFF1C274C)),
        ),
      ),
    );
  }
}

class _GlassImageButton extends StatelessWidget {
  const _GlassImageButton({
    required this.asset,
    required this.onTap,
    this.active = false,
  });

  final String asset;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(32),
        height: ui(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(
            color: active ? const Color(0xFF8741FF) : const Color(0xFFF3F2F3),
          ),
        ),
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          asset,
          width: ui(32),
          height: ui(32),
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}

/// 与 [MusicPlayPage] 右上角 `_SegmentSwitch` 同款样式，尺寸 157×32。
class _ScoreModeSegmentSwitch extends StatelessWidget {
  const _ScoreModeSegmentSwitch({
    required this.selectedIndex,
    required this.onLeftTap,
    required this.onRightTap,
  });

  final int selectedIndex;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;

  static const _switchWidth = 157.0;
  static const _switchHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onLeftTap == null && onRightTap == null;
    final outerW = ui(_switchWidth);
    final outerH = ui(_switchHeight);
    final pad = ui(2);
    final segmentW = (outerW - pad * 2) / 2;

    return RepaintBoundary(
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: SizedBox(
          width: outerW,
          height: outerH,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4FF),
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    left: selectedIndex * segmentW,
                    top: 0,
                    bottom: 0,
                    width: segmentW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF8741FF),
                        borderRadius: BorderRadius.circular(ui(6)),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ScoreModeSegmentSwitchItem(
                          label: '谱例视唱',
                          selected: selectedIndex == 0,
                          onTap: onLeftTap,
                        ),
                      ),
                      Expanded(
                        child: _ScoreModeSegmentSwitchItem(
                          label: '无谱视唱',
                          selected: selectedIndex == 1,
                          onTap: onRightTap,
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
  }
}

class _ScoreModeSegmentSwitchItem extends StatelessWidget {
  const _ScoreModeSegmentSwitchItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontSize: ui(13),
              fontFamily: 'PingFang SC',
              fontWeight: selected ? AppFont.w500 : AppFont.w400,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
