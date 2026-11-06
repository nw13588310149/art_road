import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
manifest = json.loads(
    (REPO / "assets/audio/smart_dictation/piano/manifest.json").read_text(encoding="utf-8")
)
lines = [
    "/// FluidR3 MusyngKite grand piano (C2-C7), one sample per semitone.",
    "/// Source: gleitz/midi-js-soundfonts (MIT).",
    "const Map<String, String> kPianoNoteAssetByNote = <String, String>{",
]
for key, value in manifest.items():
    lines.append(f"  '{key}': '{value}',")
lines.append("};")
lines.append("")
out = REPO / "lib/core/audio/piano_note_assets.dart"
out.write_text("\n".join(lines), encoding="utf-8")
print(f"wrote {out}")
