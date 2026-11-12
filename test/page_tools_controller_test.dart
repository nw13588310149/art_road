import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_catalog.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/state/page_tools_controller.dart';

void main() {
  test(
    'countdown uses elapsed wall time and ends after background suspension',
    () {
      var now = DateTime(2026, 11, 12, 10);
      final c = PageToolsController(now: () => now);
      addTearDown(c.dispose);
      c.select(ArtTool.quickSketch);
      c.setDuration(30);
      c.start();
      now = now.add(const Duration(seconds: 12));
      c.tick();
      expect(c.state.seconds, 18);
      c.pause();
      now = now.add(const Duration(minutes: 2));
      c.start();
      expect(c.state.seconds, 18);
      now = now.add(const Duration(minutes: 1));
      c.tick();
      expect(c.state.seconds, 0);
      expect(c.state.running, false);
      c.start();
      expect(c.state.seconds, 30);
      c.end();
      expect(c.state.tool, isNull);
      expect(c.state.running, false);
    },
  );
  test(
    'measurement stays inside page and palette is deduplicated and bounded',
    () {
      final c = PageToolsController();
      addTearDown(c.dispose);
      c.movePoint(0, const Offset(-1, 2));
      expect(c.state.points[0], const Offset(.02, .98));
      for (var i = 0; i < 8; i++) {
        c.sample(Color(0xff000000 + i));
        c.saveColor();
      }
      c.saveColor();
      expect(c.state.palette.length, 6);
      expect(c.state.hex, '#000007');
      c.select(ArtTool.grid);
      c.grid(6);
      c.select(ArtTool.color);
      c.select(ArtTool.grid);
      expect(c.state.grid, 6);
    },
  );
}
