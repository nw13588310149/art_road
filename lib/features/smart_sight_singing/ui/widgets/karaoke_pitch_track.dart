import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/smart_sight_singing_config.dart';
import '../../audio/pitch_track.dart';
import '../../state/smart_sight_singing_state.dart';

/// KTV 风格音高滚动轨道（demo 中性浅色）：
/// - 横轴时间：Now 线左侧半窗历史，参考条向右预绘至曲末并随播放连续左移。
/// - 纵轴 MIDI，按 [PitchTrack.minMidi] / [PitchTrack.maxMidi] 自适应。
/// - 参考音高用横向胶囊段绘制；用户演唱音高沿时间轴留下拖尾。
class KaraokePitchTrack extends StatelessWidget {
  const KaraokePitchTrack({
    required this.track,
    required this.playbackMs,
    required this.userPoints,
    required this.currentUserMidi,
    required this.scoringStandardCents,
    this.currentUserAmplitude = 0,
    this.windowMs = SmartSightSingingViewConfig.karaokeWindowMs,
    super.key,
  });

  final PitchTrack track;
  final int playbackMs;
  final List<UserPitchPoint> userPoints;
  final double currentUserMidi;
  final double scoringStandardCents;
  final double currentUserAmplitude;
  final int windowMs;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _KaraokePainter(
              track: track,
              playbackMs: playbackMs,
              userPoints: userPoints,
              currentUserMidi: currentUserMidi,
              currentUserAmplitude: currentUserAmplitude,
              scoringStandardCents: scoringStandardCents,
              windowMs: windowMs,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _KaraokePainter extends CustomPainter {
  _KaraokePainter({
    required this.track,
    required this.playbackMs,
    required this.userPoints,
    required this.currentUserMidi,
    required this.currentUserAmplitude,
    required this.scoringStandardCents,
    required this.windowMs,
  });

  final PitchTrack track;
  final int playbackMs;
  final List<UserPitchPoint> userPoints;
  final double currentUserMidi;
  final double currentUserAmplitude;
  final double scoringStandardCents;
  final int windowMs;

  static const _bg = Color(0xFFF5F6F8);
  static const _grid = Color(0xFFD8DCE3);
  static const _label = Color(0xFF788698);
  static const _accent = Color(0xFF8741FF);
  static const _refFill = Color(0x268741FF);
  static const _refStroke = _accent;
  static const _nowLine = _accent;
  static const _userNear = Color(0xFF9CA3AF);
  /// 拖尾：命中 / 接近 / 偏离（紫色系 + 灰，对齐当前视觉规范）。
  static const _trailGood = _accent;
  static const _trailOk = Color(0xFFA773FF);
  static const _trailMiss = Color(0xFFC4C9D1);

  /// 参考音符条高度（设计稿 20px）。
  static const _noteBarHeight = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Offset.zero & size;
    canvas.drawRect(bgRect, Paint()..color = _bg);

    final minMidi = track.minMidi;
    final maxMidi = track.maxMidi;
    final midiRange = (maxMidi - minMidi).clamp(6, 60).toDouble();
    final rangeCenter = (minMidi + maxMidi) / 2;

    final centerX =
        size.width * SmartSightSingingViewConfig.karaokeNowLineFraction;
    final pxPerMs = size.width / windowMs;

    double xFromTime(int ms) => centerX + (ms - playbackMs) * pxPerMs;
    double yFromMidi(double midi) {
      final t = (midi - minMidi) / midiRange;
      return size.height * (1 - t.clamp(0, 1));
    }

    // 用户演唱可能跨八度（男生唱女高音谱、童声唱男低音谱…），原始 MIDI
    // 会落在显示音域之外被钉到顶/底。这里把用户音高沿八度方向"折叠"到
    // 离参考音（或音域中心）最近的同名八度，再交给 yFromMidi 绘制；
    // 与 octaveNormalizedCents 评分逻辑保持一致。
    double octaveSnap(double midi, double target) {
      if (midi < 0 || !midi.isFinite) return midi;
      final delta = midi - target;
      final octaves = (delta / 12).round();
      return midi - octaves * 12;
    }

    double displayMidiAt(double midi, int timeMs) {
      if (midi < 0 || !midi.isFinite) return midi;
      final ref = track.sampleAt(timeMs);
      final target = (ref != null && ref.pitched) ? ref.midi : rangeCenter;
      return octaveSnap(midi, target);
    }

    final gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = 0.5;
    for (var m = minMidi.ceil(); m <= maxMidi.floor(); m++) {
      final y = yFromMidi(m.toDouble());
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      if (((m % 12) + 12) % 12 == 0) {
        final name = PitchUtils.midiToNoteName(m.toDouble());
        final tp = TextPainter(
          text: TextSpan(
            text: name,
            style: const TextStyle(
              color: _label,
              fontSize: 11,
              fontFamily: 'Inter',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(4, y - tp.height - 1));
      }
    }

    final refPaint = Paint()
      ..color = _refFill
      ..style = PaintingStyle.fill;
    final refOutline = Paint()
      ..color = _refStroke
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final visibleStartMs = playbackMs - windowMs ~/ 2;
    // 参考条预绘至曲末：音符时间轴与 playbackMs 对齐（含 MusicXML 预备段偏移）。
    // track.totalMs 仅表示旋律时长（供进度条），不能用作绘制终点。
    final notes = track.notes;
    final refDrawEndMs = notes.isEmpty
        ? track.totalMs
        : notes.fold<int>(
            0,
            (maxEnd, note) => math.max(maxEnd, note.endMs),
          );
    if (notes.isNotEmpty) {
      for (final note in notes) {
        if (note.isRest) continue;
        if (note.endMs < visibleStartMs || note.startMs > refDrawEndMs) {
          continue;
        }
        final x0 = xFromTime(note.startMs);
        final x1 = xFromTime(note.endMs);
        final y = yFromMidi(note.midi);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x0, y - _noteBarHeight / 2, x1, y + _noteBarHeight / 2),
          const Radius.circular(_noteBarHeight / 2),
        );
        canvas.drawRRect(rect, refPaint);
        canvas.drawRRect(rect, refOutline);
      }
    } else {
      final frames = track.frames;
      final stepMs = track.frameStepMs <= 0
          ? SmartSightSingingMidiConfig.referenceFrameStepMs
          : track.frameStepMs;
      final startIdx = ((visibleStartMs - 2 * stepMs) / stepMs).floor().clamp(
        0,
        frames.length - 1,
      );
      final endIdx = ((refDrawEndMs + 2 * stepMs) / stepMs).ceil().clamp(
        0,
        frames.length - 1,
      );

      for (var i = startIdx; i <= endIdx; i++) {
        final f = frames[i];
        if (!f.pitched) continue;
        final x0 = xFromTime(f.timeMs - stepMs ~/ 2);
        final x1 = xFromTime(f.timeMs + stepMs ~/ 2);
        final y = yFromMidi(f.midi);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x0, y - _noteBarHeight / 2, x1, y + _noteBarHeight / 2),
          const Radius.circular(_noteBarHeight / 2),
        );
        canvas.drawRRect(rect, refPaint);
        canvas.drawRRect(rect, refOutline);
      }
    }

    if (userPoints.isNotEmpty) {
      for (var i = 0; i < userPoints.length; i++) {
        final p = userPoints[i];
        if (!p.pitched) continue;
        // 「Now」竖线上的实时检测由光晕承担，避免与历史拖尾重复绘制。
        if (currentUserMidi >= 0 &&
            (p.timeMs - playbackMs).abs() <=
                SmartSightSingingViewConfig.karaokeNowLineSkipTrailMs) {
          continue;
        }
        final x = xFromTime(p.timeMs);
        if (x < -8 || x > size.width + 8) continue;
        final y = yFromMidi(displayMidiAt(p.midi, p.timeMs));
        final age = (playbackMs - p.timeMs).clamp(0, windowMs);
        final fade = 1 - age / windowMs;
        final alpha = (SmartSightSingingViewConfig.karaokeTrailMinAlpha +
                fade * (1 - SmartSightSingingViewConfig.karaokeTrailMinAlpha))
            .clamp(
              SmartSightSingingViewConfig.karaokeTrailMinAlpha,
              1.0,
            );
        final radius =
            (SmartSightSingingViewConfig.karaokeTrailMinRadius +
                    p.amplitude *
                        (SmartSightSingingViewConfig.karaokeTrailMaxRadius -
                            SmartSightSingingViewConfig.karaokeTrailMinRadius))
                .clamp(
                  SmartSightSingingViewConfig.karaokeTrailMinRadius,
                  SmartSightSingingViewConfig.karaokeTrailMaxRadius,
                );
        final baseColor = _trailColor(p.cents);
        canvas.drawCircle(
          Offset(x, y),
          radius,
          Paint()..color = baseColor.withValues(alpha: alpha),
        );
      }
    }

    final nowPaint = Paint()
      ..color = _nowLine.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX, 6),
      Offset(centerX, size.height - 6),
      nowPaint,
    );

    final glowY = currentUserMidi >= 0
        ? yFromMidi(displayMidiAt(currentUserMidi, playbackMs))
        : SmartSightSingingViewConfig.karaokeIdleGlowCenterY;
    _drawNowGlow(canvas, centerX, glowY, size.height);

    if (currentUserMidi < 0 &&
        currentUserAmplitude >
            SmartSightSingingViewConfig.micActivityIndicatorMinAmplitude) {
      // 有响度但未识别音高：在 Now 线底部显示麦克风活动指示。
      final barW = (8 + currentUserAmplitude * 40).clamp(8.0, 36.0);
      final barRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, size.height - 18),
          width: barW,
          height: 6,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        barRect,
        Paint()
          ..color = _userNear.withValues(
            alpha: 0.35 + currentUserAmplitude * 0.4,
          ),
      );
    }
  }

  Color _trailColor(double cents) {
    final absCents = cents.abs();
    if (!absCents.isFinite) return _trailMiss;
    final goodCents = SmartSightSingingScoringConfig.normalizeStandardCents(
      scoringStandardCents,
    );
    final okCents =
        goodCents *
        SmartSightSingingScoringConfig.okCentsAtDefault /
        SmartSightSingingScoringConfig.defaultStandardCents;
    if (absCents <= goodCents) return _trailGood;
    if (absCents <= okCents) return _trailOk;
    return _trailMiss;
  }

  /// 紫色竖线上的扩散圆：随实时检测音高在纵轴移动。
  void _drawNowGlow(Canvas canvas, double cx, double cy, double height) {
    const maxRadius = 11.0;
    final clampedY = cy.clamp(maxRadius + 6, height - maxRadius - 6);
    const layers = <(double, double)>[
      (11.0, 0.20),
      (8.045, 0.30),
      (5.085, 0.50),
      (2.13, 0.70),
      (1.175, 1.0),
    ];
    for (final (radius, alpha) in layers) {
      canvas.drawCircle(
        Offset(cx, clampedY),
        radius,
        Paint()..color = _accent.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KaraokePainter old) {
    return old.playbackMs != playbackMs ||
        old.track != track ||
        !identical(old.userPoints, userPoints) ||
        old.currentUserMidi != currentUserMidi ||
        old.currentUserAmplitude != currentUserAmplitude ||
        old.scoringStandardCents != scoringStandardCents ||
        old.windowMs != windowMs;
  }
}
