import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/smart_sight_singing/audio/music_xml_sight_singing_service.dart';

void main() {
  const tiedXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Music</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>5</octave></pitch>
        <duration>4</duration>
        <tie type="start"/>
        <voice>1</voice>
        <type>half</type>
      </note>
      <note>
        <pitch><step>C</step><octave>5</octave></pitch>
        <duration>1</duration>
        <tie type="stop"/>
        <voice>1</voice>
        <type>eighth</type>
      </note>
      <note>
        <rest/>
        <duration>1</duration>
        <voice>1</voice>
        <type>eighth</type>
      </note>
      <note>
        <rest/>
        <duration>2</duration>
        <voice>1</voice>
        <type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>
''';

  const repeatXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Music</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>1</divisions></attributes>
      <barline location="left"><repeat direction="forward"/></barline>
      <note>
        <pitch><step>C</step><octave>5</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
    </measure>
    <measure number="2">
      <barline location="right"><repeat direction="backward"/></barline>
      <note>
        <pitch><step>D</step><octave>5</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>
''';

  test('repeat barlines expand playback and cursor onsets', () {
    final preview = MusicXmlSightSingingService.parseXml(repeatXml);
    final bundle = MusicXmlSightSingingService.buildBundle(
      preview.document,
      preview.suggestedPartIndex,
      rawXml: repeatXml,
    );

    final pitched = bundle.track.notes.where((n) => !n.isRest).toList();
    expect(pitched.length, 4);
    expect(bundle.cursorOnsetMs.length, 4);
    expect(pitched[0].midi, closeTo(72, 0.1));
    expect(pitched[1].midi, closeTo(74, 0.1));
    expect(pitched[2].midi, closeTo(72, 0.1));
    expect(pitched[3].midi, closeTo(74, 0.1));
    expect(pitched[2].startMs, greaterThan(pitched[1].endMs - 5));
  });

  test('tie stop note appears in OSMD cursor onsets but not KTV track', () {
    final preview = MusicXmlSightSingingService.parseXml(tiedXml);
    final bundle = MusicXmlSightSingingService.buildBundle(
      preview.document,
      preview.suggestedPartIndex,
    );

    final pitched = bundle.track.notes.where((n) => !n.isRest).toList();
    expect(pitched.length, 1);
    expect(pitched.single.endMs, greaterThan(pitched.single.startMs + 500));

    // OSMD: tie start, tie stop, rest, rest = 4 cursor steps.
    expect(bundle.cursorOnsetMs.length, bundle.track.notes.length + 1);
    final tieStopOnset = bundle.cursorOnsetMs[1];
    expect(tieStopOnset, greaterThan(pitched.single.startMs));
    expect(tieStopOnset, lessThan(pitched.single.endMs));
  });
}
