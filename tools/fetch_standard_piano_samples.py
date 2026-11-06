#!/usr/bin/env python3
"""Download FluidR3 MusyngKite grand-piano samples and export app-ready WAVs.

Source: https://github.com/gleitz/midi-js-soundfonts (MusyngKite / acoustic_grand_piano)
License: MIT (soundfont data from FluidR3 GM via midi-js-soundfonts distribution)
"""

from __future__ import annotations

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = REPO_ROOT / "assets" / "audio" / "smart_dictation" / "piano"
BASE_URL = (
    "https://raw.githubusercontent.com/gleitz/midi-js-soundfonts/"
    "gh-pages/MusyngKite/acoustic_grand_piano-mp3"
)

SHARP_TO_FLAT = {
    "C#": "Db",
    "D#": "Eb",
    "F#": "Gb",
    "G#": "Ab",
    "A#": "Bb",
}


def note_catalog() -> list[tuple[str, str]]:
    """Return (app_note, gleitz_mp3_stem) for C2..C7 chromatic."""
    pairs: list[tuple[str, str]] = []
    for octave in range(2, 8):
        for name in ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"):
            if octave == 7 and name != "C":
                continue
            stem = name
            if "#" in name:
                stem = SHARP_TO_FLAT[name] + str(octave)
            else:
                stem = name + str(octave)
            pairs.append((f"{name}{octave}", stem))
    return pairs


def asset_filename(app_note: str) -> str:
    """C#4 -> Cs4.wav (avoid '#' in filenames for web tooling)."""
    if "#" in app_note:
        return app_note.replace("#", "s") + ".wav"
    return app_note + ".wav"


def ffmpeg_exe() -> str:
    try:
        import imageio_ffmpeg  # type: ignore

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return "ffmpeg"


def download_mp3(stem: str, cache_dir: Path) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    target = cache_dir / f"{stem}.mp3"
    if target.exists() and target.stat().st_size > 1000:
        return target
    url = f"{BASE_URL}/{stem}.mp3"
    last_error: Exception | None = None
    for attempt in range(6):
        try:
            print(f"download {url} (attempt {attempt + 1})")
            urllib.request.urlretrieve(url, target)
            if target.stat().st_size > 1000:
                return target
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last_error = error
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Failed to download {url}") from last_error


def convert_to_wav(mp3: Path, wav: Path, ffmpeg: str) -> None:
    wav.parent.mkdir(parents=True, exist_ok=True)
    # Mono 44.1kHz 16-bit.
    #
    # 不做 silenceremove：它会删除钢琴衰减里低于阈值的小段，把波形在非零点
    # 拼接，造成爆音。改为保留自然延音，并只在两端做处理：
    #   - 起音 4ms 线性淡入：消除样本开头的瞬态咔哒声；
    #   - 结尾 0.6s 淡出，并让淡出正好结束在文件末尾 → EOF 处振幅为 0，
    #     自然播放结束不会有关闭爆音。
    total = 3.6
    fade_out_start = total - 0.6
    cmd = [
        ffmpeg,
        "-y",
        "-i",
        str(mp3),
        "-t",
        str(total),
        "-af",
        f"afade=t=in:st=0:d=0.004,afade=t=out:st={fade_out_start}:d=0.6",
        "-ac",
        "1",
        "-ar",
        "44100",
        "-sample_fmt",
        "s16",
        str(wav),
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> int:
    ffmpeg = ffmpeg_exe()
    cache = REPO_ROOT / "build" / "piano_sample_cache"
    pairs = note_catalog()
    manifest: dict[str, str] = {}

    for app_note, stem in pairs:
        out_name = asset_filename(app_note)
        wav = OUT_DIR / out_name
        if wav.exists() and wav.stat().st_size > 1000:
            manifest[app_note] = f"assets/audio/smart_dictation/piano/{out_name}"
            continue
        mp3 = download_mp3(stem, cache)
        convert_to_wav(mp3, wav, ffmpeg)
        manifest[app_note] = f"assets/audio/smart_dictation/piano/{out_name}"
        print(f"ok {app_note} <- {stem}.mp3 -> {out_name}")

    manifest_path = OUT_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    removed = remove_legacy_obfuscated_samples()
    print(f"wrote {len(manifest)} samples to {OUT_DIR}")
    print(f"removed {removed} legacy aNN/bNN wav files")
    print(f"manifest: {manifest_path}")
    return 0


def remove_legacy_obfuscated_samples() -> int:
    """Delete old a49/b49-style files without touching note-named samples."""
    removed = 0
    for path in OUT_DIR.glob("*.wav"):
        stem = path.stem
        if len(stem) >= 2 and stem[0] in "ab" and stem[1:].isdigit():
            path.unlink()
            removed += 1
    return removed


if __name__ == "__main__":
    sys.exit(main())
