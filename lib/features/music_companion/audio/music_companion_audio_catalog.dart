import '../../../core/audio/ios_playback_volume.dart';
import '../../../core/audio/piano_note_assets.dart';

enum MusicCompanionMetronomeCue {
  tone1Accent,
  tone1Regular,
  tone2Accent,
  tone2Regular,
  tone2Special,
  tone3Beat1,
  tone3Beat2,
  tone3Beat3,
  tone3Beat4,
  tone3Beat5,
  tone3Beat6,
  tone3Beat7,
  tone3Beat8,
  tone3Beat9,
  tone3Beat10,
  tone3Beat11,
  tone3Beat12,
}

/// 音乐伴侣 / 智能视唱共用的播放增益。
///
/// iOS：软件层恒为 1.0，响度完全跟随系统音量键。
/// 其它平台：节拍器弱拍可略低以区分重音。
abstract final class MusicCompanionPlaybackVolume {
  static const double piano = 1.0;
  static const double metronomeAccent = 1.0;
  static const double metronomeWeak = 0.92;

  static double metronomeVolumeForCue(MusicCompanionMetronomeCue cue) {
    if (IosPlaybackVolume.isIosNative) {
      return 1.0;
    }
    switch (cue) {
      case MusicCompanionMetronomeCue.tone1Accent:
      case MusicCompanionMetronomeCue.tone2Accent:
        return metronomeAccent;
      default:
        return metronomeWeak;
    }
  }

  static double metronomeVolumeForBeat(int beatIndex) {
    if (IosPlaybackVolume.isIosNative) {
      return 1.0;
    }
    return beatIndex == 0 ? metronomeAccent : metronomeWeak;
  }
}

/// Shared piano map for music companion, music play, smart sight singing, etc.
const Map<String, String> kMusicCompanionPianoAssetByNote = kPianoNoteAssetByNote;

const Map<MusicCompanionMetronomeCue, String>
kMusicCompanionMetronomeAssetByCue = <MusicCompanionMetronomeCue, String>{
  MusicCompanionMetronomeCue.tone1Accent:
      'assets/audio/music_companion/metronome/beat0/audio1.wav',
  MusicCompanionMetronomeCue.tone1Regular:
      'assets/audio/music_companion/metronome/beat0/audio2.wav',
  MusicCompanionMetronomeCue.tone2Accent:
      'assets/audio/music_companion/metronome/beat2/2.wav',
  MusicCompanionMetronomeCue.tone2Regular:
      'assets/audio/music_companion/metronome/beat2/3.wav',
  MusicCompanionMetronomeCue.tone2Special:
      'assets/audio/music_companion/metronome/beat2/4.wav',
  MusicCompanionMetronomeCue.tone3Beat1:
      'assets/audio/music_companion/metronome/beat3/01.wav',
  MusicCompanionMetronomeCue.tone3Beat2:
      'assets/audio/music_companion/metronome/beat3/02.wav',
  MusicCompanionMetronomeCue.tone3Beat3:
      'assets/audio/music_companion/metronome/beat3/03.wav',
  MusicCompanionMetronomeCue.tone3Beat4:
      'assets/audio/music_companion/metronome/beat3/04.wav',
  MusicCompanionMetronomeCue.tone3Beat5:
      'assets/audio/music_companion/metronome/beat3/05.wav',
  MusicCompanionMetronomeCue.tone3Beat6:
      'assets/audio/music_companion/metronome/beat3/06.wav',
  MusicCompanionMetronomeCue.tone3Beat7:
      'assets/audio/music_companion/metronome/beat3/07.wav',
  MusicCompanionMetronomeCue.tone3Beat8:
      'assets/audio/music_companion/metronome/beat3/08.wav',
  MusicCompanionMetronomeCue.tone3Beat9:
      'assets/audio/music_companion/metronome/beat3/09.wav',
  MusicCompanionMetronomeCue.tone3Beat10:
      'assets/audio/music_companion/metronome/beat3/10.wav',
  MusicCompanionMetronomeCue.tone3Beat11:
      'assets/audio/music_companion/metronome/beat3/11.wav',
  MusicCompanionMetronomeCue.tone3Beat12:
      'assets/audio/music_companion/metronome/beat3/12.wav',
};
