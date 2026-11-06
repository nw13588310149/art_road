import 'dart:typed_data';

/// 解析后的 MIDI 音符。
class ParsedMidiNote {
  const ParsedMidiNote({
    required this.trackIndex,
    required this.channel,
    required this.pitch,
    required this.velocity,
    required this.startTick,
    required this.endTick,
    required this.startMs,
    required this.endMs,
  });

  final int trackIndex;
  final int channel;
  final int pitch;
  final int velocity;
  final int startTick;
  final int endTick;
  final double startMs;
  final double endMs;
}

/// Standard MIDI File 解析结果。
class ParsedMidiFile {
  const ParsedMidiFile({
    required this.format,
    required this.ticksPerQuarter,
    required this.tracks,
    required this.notes,
    required this.totalMs,
  });

  final int format;
  final int ticksPerQuarter;
  final int tracks;
  final List<ParsedMidiNote> notes;
  final double totalMs;

  List<ParsedMidiNote> notesOnTrack(int trackIndex) {
    return notes
        .where((n) => n.trackIndex == trackIndex)
        .toList(growable: false);
  }
}

class MidiParseException implements Exception {
  MidiParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract final class MidiFileParser {
  static const int _metaTempo = 0x51;

  static ParsedMidiFile parse(Uint8List bytes) {
    if (bytes.length < 14 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'MThd') {
      throw MidiParseException('不是有效的 Standard MIDI File。');
    }

    final view = ByteData.sublistView(bytes);
    final headerLen = view.getUint32(4, Endian.big);
    if (headerLen < 6 || bytes.length < 8 + headerLen) {
      throw MidiParseException('MIDI 文件头不完整。');
    }

    final format = view.getUint16(8, Endian.big);
    final trackCount = view.getUint16(10, Endian.big);
    final division = view.getUint16(12, Endian.big);
    if (division == 0) {
      throw MidiParseException('不支持的 MIDI division=0。');
    }

    var offset = 8 + headerLen;
    final trackEvents = <_ParsedTrackEvents>[];
    var trackIndex = 0;

    while (offset + 8 <= bytes.length && trackIndex < trackCount) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkLen = view.getUint32(offset + 4, Endian.big);
      final chunkStart = offset + 8;
      final chunkEnd = chunkStart + chunkLen;
      if (chunkEnd > bytes.length) {
        throw MidiParseException('MIDI track 数据不完整。');
      }

      if (chunkId == 'MTrk') {
        trackIndex += 1;
        trackEvents.add(
          _ParsedTrackEvents(
            trackIndex: trackIndex,
            events: _parseTrackEvents(bytes.sublist(chunkStart, chunkEnd)),
          ),
        );
      }

      offset = chunkEnd;
      // 标准 SMF 在奇数长度 chunk 后可能有 1 字节对齐填充；
      // 部分文件（含 demo.mid）下一轨 MTrk 紧接其后，不能再 blindly +1。
      if (chunkLen.isOdd && offset < bytes.length) {
        final nextId = offset + 4 <= bytes.length
            ? String.fromCharCodes(bytes.sublist(offset, offset + 4))
            : '';
        if (nextId != 'MTrk' && nextId != 'MThd') {
          offset += 1;
        }
      }
    }

    final tempos = _globalTempoMap(trackEvents);
    final allNotes = <ParsedMidiNote>[];
    for (final track in trackEvents) {
      allNotes.addAll(
        _pairNotes(
          events: track.events,
          trackIndex: track.trackIndex,
          ticksPerQuarter: division,
          tempos: tempos,
        ),
      );
    }

    final totalMs = allNotes.isEmpty
        ? 0.0
        : allNotes.map((n) => n.endMs).reduce((a, b) => a > b ? a : b);

    return ParsedMidiFile(
      format: format,
      ticksPerQuarter: division,
      tracks: trackCount,
      notes: allNotes,
      totalMs: totalMs,
    );
  }

  static List<_TimedEvent> _parseTrackEvents(Uint8List trackData) {
    final events = <_TimedEvent>[];
    var offset = 0;
    var tick = 0;
    int? runningStatus;

    while (offset < trackData.length) {
      final deltaResult = _readVarLen(trackData, offset);
      tick += deltaResult.value;
      offset = deltaResult.nextOffset;
      if (offset >= trackData.length) break;

      var status = trackData[offset];
      if (status < 0x80) {
        if (runningStatus == null) break;
        status = runningStatus;
      } else {
        offset += 1;
        if (status < 0xF0) {
          runningStatus = status;
        }
      }

      if (status == 0xFF) {
        if (offset >= trackData.length) break;
        final metaType = trackData[offset];
        offset += 1;
        final lenResult = _readVarLen(trackData, offset);
        final len = lenResult.value;
        offset = lenResult.nextOffset;
        final dataEnd = offset + len;
        if (dataEnd > trackData.length) break;
        if (metaType == _metaTempo && len == 3) {
          final uspq =
              (trackData[offset] << 16) |
              (trackData[offset + 1] << 8) |
              trackData[offset + 2];
          events.add(_TimedEvent.tempo(tick: tick, usPerQuarter: uspq));
        }
        offset = dataEnd;
        continue;
      }

      if (status == 0xF0 || status == 0xF7) {
        if (offset >= trackData.length) break;
        final lenResult = _readVarLen(trackData, offset);
        offset = lenResult.nextOffset + lenResult.value;
        continue;
      }

      final high = status & 0xF0;
      if (high == 0x90 || high == 0x80) {
        if (offset + 1 >= trackData.length) break;
        final pitch = trackData[offset];
        final velocity = trackData[offset + 1];
        offset += 2;
        final channel = status & 0x0F;
        final isOn = high == 0x90 && velocity > 0;
        events.add(
          isOn
              ? _TimedEvent.noteOn(
                  tick: tick,
                  channel: channel,
                  pitch: pitch,
                  velocity: velocity,
                )
              : _TimedEvent.noteOff(tick: tick, channel: channel, pitch: pitch),
        );
        continue;
      }

      if (high == 0xA0 ||
          high == 0xB0 ||
          high == 0xE0 ||
          status == 0xC0 ||
          status == 0xD0) {
        final paramCount = (status == 0xC0 || status == 0xD0) ? 1 : 2;
        offset += paramCount;
        continue;
      }

      offset += 1;
    }

    return events;
  }

  static List<ParsedMidiNote> _pairNotes({
    required List<_TimedEvent> events,
    required int trackIndex,
    required int ticksPerQuarter,
    required List<(int tick, int usPerQuarter)> tempos,
  }) {
    double tickToMs(int tick) {
      var ms = 0.0;
      var prevTick = 0;
      var uspq = tempos.first.$2;
      for (final tempo in tempos) {
        if (tempo.$1 >= tick) break;
        ms += (tempo.$1 - prevTick) * uspq / ticksPerQuarter / 1000.0;
        prevTick = tempo.$1;
        uspq = tempo.$2;
      }
      ms += (tick - prevTick) * uspq / ticksPerQuarter / 1000.0;
      return ms;
    }

    final active = <String, ({int startTick, int velocity})>{};
    final notes = <ParsedMidiNote>[];

    for (final event in events) {
      switch (event.kind) {
        case _TimedEventKind.noteOn:
          final key = '${event.channel}:${event.pitch}';
          active[key] = (startTick: event.tick, velocity: event.velocity!);
        case _TimedEventKind.noteOff:
          final key = '${event.channel}:${event.pitch}';
          final started = active.remove(key);
          if (started == null || event.tick <= started.startTick) {
            continue;
          }
          notes.add(
            ParsedMidiNote(
              trackIndex: trackIndex,
              channel: event.channel!,
              pitch: event.pitch!,
              velocity: started.velocity,
              startTick: started.startTick,
              endTick: event.tick,
              startMs: tickToMs(started.startTick),
              endMs: tickToMs(event.tick),
            ),
          );
        case _TimedEventKind.tempo:
          break;
      }
    }

    return notes;
  }

  static List<(int tick, int usPerQuarter)> _globalTempoMap(
    List<_ParsedTrackEvents> tracks,
  ) {
    final tempos = <(int tick, int usPerQuarter)>[(0, 500000)];
    for (final track in tracks) {
      for (final event in track.events) {
        if (event.kind == _TimedEventKind.tempo) {
          tempos.add((event.tick, event.usPerQuarter!));
        }
      }
    }
    tempos.sort((a, b) => a.$1.compareTo(b.$1));
    return tempos;
  }

  static _VarLenResult _readVarLen(Uint8List data, int offset) {
    var value = 0;
    var i = offset;
    while (i < data.length) {
      final byte = data[i];
      i += 1;
      value = (value << 7) | (byte & 0x7F);
      if ((byte & 0x80) == 0) {
        return _VarLenResult(value: value, nextOffset: i);
      }
    }
    return _VarLenResult(value: value, nextOffset: i);
  }
}

class _VarLenResult {
  const _VarLenResult({required this.value, required this.nextOffset});
  final int value;
  final int nextOffset;
}

class _ParsedTrackEvents {
  const _ParsedTrackEvents({required this.trackIndex, required this.events});

  final int trackIndex;
  final List<_TimedEvent> events;
}

enum _TimedEventKind { tempo, noteOn, noteOff }

class _TimedEvent {
  const _TimedEvent._({
    required this.kind,
    required this.tick,
    this.usPerQuarter,
    this.channel,
    this.pitch,
    this.velocity,
  });

  factory _TimedEvent.tempo({required int tick, required int usPerQuarter}) {
    return _TimedEvent._(
      kind: _TimedEventKind.tempo,
      tick: tick,
      usPerQuarter: usPerQuarter,
    );
  }

  factory _TimedEvent.noteOn({
    required int tick,
    required int channel,
    required int pitch,
    required int velocity,
  }) {
    return _TimedEvent._(
      kind: _TimedEventKind.noteOn,
      tick: tick,
      channel: channel,
      pitch: pitch,
      velocity: velocity,
    );
  }

  factory _TimedEvent.noteOff({
    required int tick,
    required int channel,
    required int pitch,
  }) {
    return _TimedEvent._(
      kind: _TimedEventKind.noteOff,
      tick: tick,
      channel: channel,
      pitch: pitch,
    );
  }

  final _TimedEventKind kind;
  final int tick;
  final int? usPerQuarter;
  final int? channel;
  final int? pitch;
  final int? velocity;
}
