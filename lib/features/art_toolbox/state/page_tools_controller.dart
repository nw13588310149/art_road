import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/toolbox_catalog.dart';

final pageToolsProvider =
    StateNotifierProvider.autoDispose<PageToolsController, PageToolsState>(
      (ref) => PageToolsController(),
    );

class PageToolsState {
  const PageToolsState({
    this.tool,
    this.grid = 3,
    this.opacity = .65,
    this.lightLines = false,
    this.mirrorX = true,
    this.mirrorY = false,
    this.original = false,
    this.points = const [
      Offset(.23, .32),
      Offset(.55, .32),
      Offset(.23, .48),
      Offset(.45, .66),
    ],
    this.color,
    this.palette = const [],
    this.seconds = 60,
    this.duration = 60,
    this.running = false,
  });
  final ArtTool? tool;
  final int grid;
  final double opacity;
  final bool lightLines, mirrorX, mirrorY, original;
  final List<Offset> points;
  final Color? color;
  final List<Color> palette;
  final int seconds, duration;
  final bool running;
  String get clock =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  String get hex => color == null
      ? '点击页面取色'
      : '#${(color!.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  PageToolsState copy({
    ArtTool? tool,
    bool clearTool = false,
    int? grid,
    double? opacity,
    bool? lightLines,
    bool? mirrorX,
    bool? mirrorY,
    bool? original,
    List<Offset>? points,
    Color? color,
    List<Color>? palette,
    int? seconds,
    int? duration,
    bool? running,
  }) => PageToolsState(
    tool: clearTool ? null : tool ?? this.tool,
    grid: grid ?? this.grid,
    opacity: opacity ?? this.opacity,
    lightLines: lightLines ?? this.lightLines,
    mirrorX: mirrorX ?? this.mirrorX,
    mirrorY: mirrorY ?? this.mirrorY,
    original: original ?? this.original,
    points: points ?? this.points,
    color: color ?? this.color,
    palette: palette ?? this.palette,
    seconds: seconds ?? this.seconds,
    duration: duration ?? this.duration,
    running: running ?? this.running,
  );
}

class PageToolsController extends StateNotifier<PageToolsState> {
  PageToolsController({DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const PageToolsState());
  final DateTime Function() _now;
  DateTime? _deadline;
  Timer? _timer;
  void select(ArtTool tool) {
    pause();
    state = state.copy(tool: tool, original: false);
  }

  void end() {
    pause();
    state = state.copy(clearTool: true, original: false);
  }

  void grid(int value) => state = state.copy(grid: value);
  void opacity(double value) =>
      state = state.copy(opacity: value.clamp(.15, 1));
  void lightLines(bool value) => state = state.copy(lightLines: value);
  void mirrorX(bool value) => state = state.copy(mirrorX: value);
  void mirrorY(bool value) => state = state.copy(mirrorY: value);
  void original(bool value) => state = state.copy(original: value);
  void movePoint(int index, Offset point) {
    final points = [...state.points];
    points[index] = Offset(point.dx.clamp(.02, .98), point.dy.clamp(.02, .98));
    state = state.copy(points: points);
  }

  void sample(Color color) => state = state.copy(color: color);
  void saveColor() {
    final color = state.color;
    if (color == null) return;
    state = state.copy(
      palette: [
        color,
        ...state.palette.where((c) => c != color),
      ].take(6).toList(),
    );
  }

  void setDuration(int seconds) {
    pause();
    state = state.copy(seconds: seconds, duration: seconds);
  }

  void start() {
    if (state.running) return;
    final seconds = state.seconds > 0 ? state.seconds : state.duration;
    _deadline = _now().add(Duration(seconds: seconds));
    state = state.copy(seconds: seconds, running: true);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => tick());
  }

  void tick() {
    if (_deadline == null) return;
    final seconds = math.max(
      0,
      (_deadline!.difference(_now()).inMilliseconds / 1000).ceil(),
    );
    if (seconds != state.seconds) state = state.copy(seconds: seconds);
    if (seconds == 0) pause();
  }

  void pause() {
    _timer?.cancel();
    _deadline = null;
    if (state.running) state = state.copy(running: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
