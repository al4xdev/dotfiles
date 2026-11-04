"""Monta o tutorial final: cartão de abertura + gravação + cartão de encerramento, legendas e música.

    uv run -q --with numpy python montage.py <fluxo> [--out-dir out] [--music-lufs -18] [--seed X]

Lê <out>/<fluxo>.raw.mp4, .captions.json e .meta.json (do recorder.mjs), gera a trilha com
music.py (semente = nome do fluxo) e escreve <out>/<fluxo>.mp4 (H.264 + AAC, faststart) e .ass.

Legendas em ASS (libass) em vez de drawtext: um arquivo só cobre abertura, encerramento e
rodapé, com caixa semitransparente (BorderStyle 3) e fade por evento, sem uma cadeia de
drawtext por legenda.

Textos dos cartões, do meta.json (vindos do fluxo ou do ambiente BRAND/SUBTITLE):
  abertura:     "<brand> — <title>"  /  "<subtitle>"
  encerramento: "<title>"            /  "<brand> · fim do tutorial"  (ou OUTRO_TEXT)
Ambiente: OUT_DIR, FONT ("Noto Sans"), FONT_DIR (/usr/share/fonts/truetype/noto),
CARD_BG (0x1d0b33), CARD_SECONDS (2).
"""

import argparse
import json
import os
import subprocess
import wave
from pathlib import Path

import music

FONT_DIR = os.environ.get("FONT_DIR", "/usr/share/fonts/truetype/noto")
FONT = os.environ.get("FONT", "Noto Sans")
FPS = 25
CARD = float(os.environ.get("CARD_SECONDS", "2"))
CARD_BG = os.environ.get("CARD_BG", "0x1d0b33")


def ass_head(w, h):
    # Tamanhos calibrados em 1280×800; escalam com a altura.
    k = h / 800
    cap, title, sub = round(30 * k), round(58 * k), round(28 * k)
    return f"""[Script Info]
ScriptType: v4.00+
PlayResX: {w}
PlayResY: {h}
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Caption,{FONT},{cap},&H00FFFFFF,&H00FFFFFF,&H30140A1E,&H30140A1E,1,0,0,0,100,100,0,0,3,14,0,2,{round(w * 0.094)},{round(w * 0.094)},{round(34 * k)},1
Style: Title,{FONT},{title},&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,1,0,0,0,100,100,0,0,1,0,0,5,80,80,0,1
Style: Sub,{FONT},{sub},&H00E6C8FF,&H00E6C8FF,&H00000000,&H00000000,0,0,0,0,100,100,1,0,1,0,0,5,80,80,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""


def ts(sec):
    sec = max(sec, 0)
    h, rem = divmod(sec, 3600)
    m, s = divmod(rem, 60)
    return f"{int(h)}:{int(m):02d}:{s:05.2f}"


def ass_text(text):
    return text.replace("\\", "\\\\").replace("{", "(").replace("}", ")").replace("\n", "\\N")


def build_ass(meta, captions, total, w, h):
    ev = []
    cx, ty, sy = w // 2, round(h * 0.4625), round(h * 0.556)

    def add(start, end, style, text, tags=""):
        ev.append(f"Dialogue: 0,{ts(start)},{ts(end)},{style},,0,0,0,,{tags}{ass_text(text)}")

    brand = meta.get("brand") or ""
    title = meta["title"]
    add(0.15, CARD, "Title", f"{brand} — {title}" if brand else title, rf"{{\fad(350,300)\pos({cx},{ty})}}")
    if meta.get("subtitle"):
        add(0.35, CARD, "Sub", meta["subtitle"], rf"{{\fad(350,300)\pos({cx},{sy})}}")
    # Legendas deslocadas pela abertura; cada uma termina pouco antes da seguinte para o fade
    # não sobrepor duas caixas no rodapé.
    for i, c in enumerate(captions):
        start = CARD + c["start"]
        nxt = CARD + captions[i + 1]["start"] if i + 1 < len(captions) else CARD + meta["duration"]
        end = max(start + 0.8, nxt - 0.08)
        add(start, end, "Caption", c["text"], r"{\fad(250,200)}")
    end0 = total - CARD
    outro = os.environ.get("OUTRO_TEXT") or (f"{brand} · fim do tutorial" if brand else "Fim do tutorial")
    add(end0 + 0.15, total, "Title", title, rf"{{\fad(300,350)\pos({cx},{ty})}}")
    add(end0 + 0.3, total, "Sub", outro, rf"{{\fad(300,350)\pos({cx},{sy})}}")
    return ass_head(w, h) + "\n".join(ev) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("flow")
    ap.add_argument("--out-dir", default=os.environ.get("OUT_DIR", "out"))
    ap.add_argument("--music-lufs", type=float, default=-18.0, help="sonoridade integrada da trilha")
    ap.add_argument("--seed", help="semente da trilha (padrão: nome do fluxo)")
    a = ap.parse_args()

    out = Path(a.out_dir).resolve()
    meta = json.loads((out / f"{a.flow}.meta.json").read_text())
    captions = json.loads((out / f"{a.flow}.captions.json").read_text())
    w, h = meta.get("width", 1280), meta.get("height", 800)
    dur = meta["duration"]
    total = CARD + dur + CARD

    wav = out / f"{a.flow}.music.wav"
    audio, info = music.render(total, a.seed or a.flow)
    with wave.open(str(wav), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(music.SR)
        wf.writeframes((audio * 32767).astype("<i2").tobytes())

    ass = out / f"{a.flow}.ass"
    ass.write_text(build_ass(meta, captions, total, w, h), encoding="utf-8")

    norm = f"fps={FPS},scale={w}:{h}:force_original_aspect_ratio=decrease,pad={w}:{h}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p"
    fc = (
        # A gravação pode terminar alguns quadros antes do relógio do recorder; congelar o
        # último quadro e cortar na duração medida mantém o encerramento no tempo das legendas.
        f"[0:v]{norm}[a];[1:v]{norm},tpad=stop_mode=clone:stop_duration=2,trim=duration={dur:.2f},setpts=PTS-STARTPTS[b];[2:v]{norm}[c];"
        f"[a][b][c]concat=n=3:v=1:a=0[cat];"
        f"[cat]ass=filename='{ass}':fontsdir='{FONT_DIR}',"
        f"fade=t=in:st=0:d=0.4,fade=t=out:st={total - 0.5:.2f}:d=0.5[v];"
        f"[3:a]atrim=0:{total:.2f},loudnorm=I={a.music_lufs}:TP=-2:LRA=7,"
        f"afade=t=out:st={total - 1.5:.2f}:d=1.5,aresample=48000[au]"
    )
    raw = out / meta["source"]
    mp4 = out / f"{a.flow}.mp4"
    card = f"color=c={CARD_BG}:s={w}x{h}:r={FPS}:d={CARD}"
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-f", "lavfi", "-i", card,
        "-t", f"{dur:.2f}", "-i", str(raw),
        "-f", "lavfi", "-i", card,
        "-i", str(wav),
        "-filter_complex", fc, "-map", "[v]", "-map", "[au]",
        "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-tune", "stillimage", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", "-shortest", str(mp4),
    ]
    subprocess.run(cmd, check=True)
    wav.unlink(missing_ok=True)
    print(f"ok: {mp4} ({total:.1f}s; trilha tom={info['key']} bpm={info['bpm']} prog={info['progression']})")


if __name__ == "__main__":
    main()