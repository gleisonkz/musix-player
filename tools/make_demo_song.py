"""Generate a synthetic multitrack demo song for Musix Player.

Output: demo/DemoMusix/{click,guide,drums,bass,pad,keys}.m4a (ALAC, mono, 44.1 kHz)
plus song.json manifest. Everything is synthesized, so it is free to redistribute.

Usage (from repo root):
    powershell -File tools/make_tts.ps1        # once, creates tools/tts/*.wav
    python tools/make_demo_song.py
Requires numpy, scipy and ffmpeg on PATH.
"""
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT
ROOT = Path(__file__).resolve().parent.parent
TTS = ROOT / "tools" / "tts"
OUT = ROOT / "demo" / "DemoMusix"

# (name, bars, layers)
SECTIONS = [
    ("Intro", 4, {"pad", "keys"}),
    ("Verso", 8, {"pad", "keys", "drums", "bass"}),
    ("Refrão", 8, {"pad", "keys", "drums", "bass", "hats16"}),
    ("Ponte", 4, {"pad", "bass"}),
    ("Refrão", 8, {"pad", "keys", "drums", "bass", "hats16"}),
    ("Final", 1, {"pad", "keys", "bass", "crash"}),
]
CUE_FILES = {"Intro": "intro", "Verso": "verso", "Refrão": "refrao", "Ponte": "ponte", "Final": "final"}
# C G Am F as MIDI root + triad
CHORDS = [(48, [60, 64, 67]), (43, [59, 62, 67]), (45, [60, 64, 69]), (41, [60, 65, 69])]

COUNT_IN_BARS = 1
TOTAL_BARS = COUNT_IN_BARS + sum(s[1] for s in SECTIONS) + 1  # +1 tail for ring-out
N = int(TOTAL_BARS * BAR * SR)


def hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def t_of(bar: float, beat: float = 0) -> float:
    return bar * BAR + beat * BEAT


def add(track: np.ndarray, sound: np.ndarray, at: float) -> None:
    i = int(round(at * SR))
    end = min(N, i + len(sound))
    if i < N:
        track[i:end] += sound[: end - i]


def env(n: int, attack: float, release: float) -> np.ndarray:
    e = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    b, a = butter(2, cutoff / (SR / 2), "low")
    return lfilter(b, a, x)


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    b, a = butter(2, cutoff / (SR / 2), "high")
    return lfilter(b, a, x)


def click_sound(accent: bool) -> np.ndarray:
    n = int(0.03 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * (1600 if accent else 1000) * t) * np.exp(-t * 150) * 0.9


def kick() -> np.ndarray:
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 50 + 100 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * 0.9


def snare(rng: np.random.Generator) -> np.ndarray:
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    noise = highpass(rng.standard_normal(n), 1500) * np.exp(-t * 22) * 0.45
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.4
    return noise + tone


def hat(rng: np.random.Generator, length: float = 0.05) -> np.ndarray:
    n = int(length * SR)
    t = np.arange(n) / SR
    return highpass(rng.standard_normal(n), 7000) * np.exp(-t * 60) * 0.25


def crash(rng: np.random.Generator) -> np.ndarray:
    n = int(2.5 * SR)
    t = np.arange(n) / SR
    return highpass(rng.standard_normal(n), 4000) * np.exp(-t * 2) * 0.3


def bass_note(midi: int, length: float) -> np.ndarray:
    n = int(length * SR)
    t = np.arange(n) / SR
    saw = 2 * ((t * hz(midi)) % 1) - 1
    return lowpass(saw, 600) * env(n, 0.005, 0.03) * 0.5


def pad_chord(notes: list[int], length: float) -> np.ndarray:
    n = int(length * SR)
    t = np.arange(n) / SR
    x = sum(np.sin(2 * np.pi * hz(m) * t) + 0.3 * np.sin(2 * np.pi * hz(m) * 1.003 * t) for m in notes)
    return x * env(n, 0.4, 0.4) * 0.12


def pluck(midi: int) -> np.ndarray:
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * hz(midi) * t) + 0.4 * np.sin(2 * np.pi * hz(midi) * 2 * t)
    return x * np.exp(-t * 8) * env(n, 0.002, 0.02) * 0.25


def load_cue(name: str) -> np.ndarray:
    sr, data = wavfile.read(TTS / f"{name}.wav")
    assert sr == SR, f"{name}.wav must be {SR} Hz"
    x = data.astype(np.float64) / 32768
    # trim leading silence so the word lands on the beat
    nz = np.flatnonzero(np.abs(x) > 0.02)
    return x[nz[0]:] * 0.9 if len(nz) else x


def build() -> tuple[dict[str, np.ndarray], list[dict]]:
    rng = np.random.default_rng(7)
    tr = {k: np.zeros(N) for k in ["click", "guide", "drums", "bass", "pad", "keys"]}

    # click on every beat of the whole song (accent on beat 1)
    for b in range(TOTAL_BARS - 1):
        for beat in range(4):
            add(tr["click"], click_sound(beat == 0), t_of(b, beat))

    # count-in voice
    for beat, word in enumerate(["um", "dois", "tres", "quatro"]):
        add(tr["guide"], load_cue(word), t_of(0, beat))

    markers = []
    bar = COUNT_IN_BARS
    for name, bars, layers in SECTIONS:
        markers.append({"name": name, "time": round(t_of(bar), 3)})
        if bar > COUNT_IN_BARS:  # announce on beat 3 of the previous bar
            add(tr["guide"], load_cue(CUE_FILES[name]), t_of(bar - 1, 2))
        for i in range(bars):
            b = bar + i
            root, triad = CHORDS[i % 4] if name != "Final" else CHORDS[0]
            last = name == "Final"
            if "pad" in layers:
                add(tr["pad"], pad_chord(triad, BAR * (2 if last else 1) + 0.4), t_of(b) - 0.2)
            if "keys" in layers:
                if last:
                    for m in triad:
                        add(tr["keys"], pluck(m + 12), t_of(b))
                else:
                    for step in range(8):
                        add(tr["keys"], pluck(triad[[0, 1, 2, 1][step % 4]] + 12), t_of(b, step / 2))
            if "bass" in layers:
                if last:
                    add(tr["bass"], bass_note(root, BAR * 1.5), t_of(b))
                else:
                    for step in range(8):
                        add(tr["bass"], bass_note(root, BEAT / 2 * 0.9), t_of(b, step / 2))
            if "drums" in layers:
                for beat in range(4):
                    if beat in (0, 2):
                        add(tr["drums"], kick(), t_of(b, beat))
                    else:
                        add(tr["drums"], snare(rng), t_of(b, beat))
                hats = 16 if "hats16" in layers else 8
                for step in range(hats):
                    add(tr["drums"], hat(rng), t_of(b, step * 4 / hats))
            if "crash" in layers:
                add(tr["drums"], kick(), t_of(b))
                add(tr["drums"], crash(rng), t_of(b))
        bar += bars

    for k, x in tr.items():
        peak = np.max(np.abs(x))
        if peak > 0.98:
            tr[k] = x * (0.98 / peak)
    return tr, markers


def main() -> None:
    tracks, markers = build()
    OUT.mkdir(parents=True, exist_ok=True)
    meta = [
        ("click", "Click", "click"),
        ("guide", "Guia", "guide"),
        ("drums", "Bateria", "band"),
        ("bass", "Baixo", "band"),
        ("pad", "Pad", "band"),
        ("keys", "Teclado", "band"),
    ]
    with tempfile.TemporaryDirectory() as tmp:
        for key, _, _ in meta:
            wav = Path(tmp) / f"{key}.wav"
            wavfile.write(wav, SR, (tracks[key] * 32767).astype(np.int16))
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "alac", str(OUT / f"{key}.m4a")],
                check=True,
            )
    manifest = {
        "title": "Demo Musix",
        "artist": "Musix Player",
        "bpm": BPM,
        "timeSignature": "4/4",
        "key": "C",
        "tracks": [{"name": name, "file": f"{key}.m4a", "role": role} for key, name, role in meta],
        "markers": markers,
    }
    (OUT / "song.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT} ({N / SR:.1f}s)")


if __name__ == "__main__":
    main()
