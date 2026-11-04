"""Trilha de fundo procedural, calma e corporativa, sem direitos autorais.

    uv run --with numpy python music.py --duration 38 --seed meu-fluxo --out out/x.wav

Pad suave (ondas senoidais levemente desafinadas, com ataque e liberação lentos), arpejo
em colcheias com decaimento curto e baixo na fundamental. A semente escolhe tom, andamento
(84–96 BPM) e uma de algumas progressões pop clássicas, para cada fluxo soar diferente e
cada fluxo soar sempre igual entre execuções.
"""

import argparse
import hashlib
import wave

import numpy as np

SR = 44100
# Graus da escala maior em semitons; progressões em graus (0 = I).
MAJOR = [0, 2, 4, 5, 7, 9, 11]
PROGRESSIONS = [
    [0, 4, 5, 3],  # I–V–vi–IV
    [0, 5, 3, 4],  # I–vi–IV–V
    [5, 3, 0, 4],  # vi–IV–I–V
    [0, 3, 5, 4],  # I–IV–vi–V
]
# Tônicas confortáveis para pad (MIDI): C, D, Eb, F, G, A.
KEYS = [48, 50, 51, 53, 55, 45]


def midi_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def triad(key, degree):
    """Tríade diatônica do grau, em MIDI (fundamental, terça, quinta)."""
    idx = [degree, degree + 2, degree + 4]
    return [key + MAJOR[i % 7] + 12 * (i // 7) for i in idx]


def envelope(n, attack, release):
    env = np.ones(n)
    a, r = min(int(attack * SR), n // 2), min(int(release * SR), n // 2)
    if a:
        env[:a] = np.linspace(0, 1, a)
    if r:
        env[-r:] *= np.linspace(1, 0, r)
    return env


def lowpass(x, cutoff):
    """Filtro de um polo: arredonda o pad sem precisar de scipy."""
    alpha = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):  # ~2 M amostras por minuto; aceitável para trilhas curtas
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def render(duration, seed):
    rng = np.random.default_rng(int(hashlib.sha256(seed.encode()).hexdigest()[:8], 16))
    key = int(rng.choice(KEYS))
    bpm = int(rng.integers(84, 97))
    prog = PROGRESSIONS[int(rng.integers(len(PROGRESSIONS)))]
    beat = 60 / bpm
    bar = 4 * beat
    total = int(duration * SR)
    pad = np.zeros(total)
    arp = np.zeros(total)
    bass = np.zeros(total)

    n_bars = int(np.ceil(duration / bar)) + 1
    for b in range(n_bars):
        chord = triad(key, prog[b % len(prog)])
        start = int(b * bar * SR)
        if start >= total:
            break
        # Pad: o acorde dura um compasso e se sobrepõe ao próximo pela liberação.
        length = min(int(bar * 1.25 * SR), total - start)
        t = np.arange(length) / SR
        env = envelope(length, 0.6, 0.9)
        for note in chord + [chord[0] + 12]:
            f = midi_hz(note)
            for detune in (-0.12, 0.12):
                pad[start:start + length] += np.sin(2 * np.pi * f * (1 + detune / 100) * t) * env

        # Baixo: fundamental uma oitava abaixo, em mínimas.
        for half in range(2):
            s = start + int(half * 2 * beat * SR)
            ln = min(int(2 * beat * SR), total - s)
            if ln <= 0:
                continue
            t = np.arange(ln) / SR
            bass[s:s + ln] += np.sin(2 * np.pi * midi_hz(chord[0] - 12) * t) * envelope(ln, 0.02, 0.4)

        # Arpejo: colcheias subindo e descendo pelo acorde, uma oitava acima do pad.
        pattern = [0, 1, 2, 3, 2, 1, 0, 1]
        tones = [n + 12 for n in chord] + [chord[0] + 24]
        for k, p in enumerate(pattern):
            s = start + int(k * beat / 2 * SR)
            ln = min(int(beat * 1.2 * SR), total - s)
            if ln <= 0:
                continue
            t = np.arange(ln) / SR
            f = midi_hz(tones[p])
            tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)
            vel = 0.8 + 0.2 * rng.random()
            arp[s:s + ln] += tone * np.exp(-t * 6) * envelope(ln, 0.005, 0.05) * vel

    pad = lowpass(pad, 1200)
    mix = 0.30 * pad / 8 + 0.22 * arp + 0.35 * bass
    # Eco simples no arpejo para dar ar sem reverberação de verdade.
    delay = int(beat * 0.75 * SR)
    echo = np.zeros(total)
    echo[delay:] = 0.22 * arp[:-delay] * 0.22
    mix += echo

    fade_in, fade_out = min(2.0, duration / 4), min(3.0, duration / 4)
    mix *= envelope(total, fade_in, fade_out)
    mix /= max(np.max(np.abs(mix)), 1e-9)
    mix *= 10 ** (-1 / 20)  # pico em -1 dBFS; o nível final se ajusta na mixagem
    stereo = np.stack([mix, np.roll(mix, int(0.012 * SR))], axis=1)  # leve largura
    return stereo, {"key": key, "bpm": bpm, "progression": prog}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--duration", type=float, required=True)
    ap.add_argument("--seed", default="tutorial")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    audio, info = render(a.duration, a.seed)
    with wave.open(a.out, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((audio * 32767).astype("<i2").tobytes())
    print(f"ok: {a.out} {a.duration:.1f}s tom={info['key']} bpm={info['bpm']} prog={info['progression']}")


if __name__ == "__main__":
    main()