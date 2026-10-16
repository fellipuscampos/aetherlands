"""Gera assets/audio/sfx/snow_wind_loop.ogg: vento de inverno sintetizado, em loop perfeito.

Por que sintetizado (2026-10-10): o primeiro "som de neve" foi um arquivo CC0 chamado "Winter Wind" que, na verdade,
era uma música (o usuário ouviu "música natalina"; a análise espectral confirmou picos tonais ~890x a mediana, contra
~20x da chuva). Vento é fisicamente ruído filtrado com rajadas — a síntese soa natural, não depende de título de
arquivo de terceiros e não tem licença a creditar.

Como:
- ruído branco estéreo (dois canais decorrelacionados) filtrado por FFT em CINCO faixas (graves a sibilo);
- cada faixa tem a própria rajada: envelope lento feito de senoides com número INTEIRO de ciclos no loop, então todas
  as modulações fecham exatamente no fim;
- a filtragem por FFT num buffer do tamanho do loop é circular, então o ruído filtrado também é periódico: o loop
  emenda sem crossfade e sem clique (o script confere a continuidade da emenda);
- normalizado para ~-16 LUFS aproximado (RMS), convertido para OGG Vorbis pelo ffmpeg.

Uso: python tools/audio/generate_wind_loop.py  (requer numpy e ffmpeg no PATH)
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SAMPLE_RATE = 44100
LOOP_SECONDS = 60
SEED = 20261010
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "sfx", "snow_wind_loop.ogg")

# (centro Hz, largura em oitavas, peso) — do ronco grave ao assobio agudo do vento.
BANDS = [
    (110.0, 1.2, 1.00),
    (240.0, 1.0, 0.85),
    (480.0, 0.9, 0.60),
    (900.0, 0.8, 0.35),
    (1700.0, 0.7, 0.16),
]
# Rajadas: ciclos inteiros por loop (60 s): períodos de ~6 a 30 s.
GUST_CYCLES = (2, 3, 5, 7, 9)
TARGET_RMS_DB = -20.0


def band_filter(n: int, center: float, octaves: float) -> np.ndarray:
    freqs = np.fft.rfftfreq(n, 1.0 / SAMPLE_RATE)
    with np.errstate(divide="ignore"):
        distance = np.log2(np.maximum(freqs, 1.0) / center)
    response = np.exp(-0.5 * (distance / (octaves * 0.5)) ** 2)
    response[0] = 0.0
    return response


def periodic_envelope(rng: np.random.Generator, n: int) -> np.ndarray:
    t = np.arange(n) / n  # 0..1 ao longo do loop
    env = np.zeros(n)
    for cycles in GUST_CYCLES:
        env += rng.uniform(0.4, 1.0) / cycles ** 0.5 * np.sin(2.0 * np.pi * cycles * t + rng.uniform(0.0, 2.0 * np.pi))
    env = (env - env.min()) / (env.max() - env.min())  # 0..1
    return 0.35 + 0.65 * env ** 1.6  # rajadas: vales calmos, picos marcados


def channel(rng: np.random.Generator, n: int) -> np.ndarray:
    out = np.zeros(n)
    for center, octaves, weight in BANDS:
        spectrum = np.fft.rfft(rng.standard_normal(n))
        band = np.fft.irfft(spectrum * band_filter(n, center, octaves), n)
        band /= np.sqrt(np.mean(band ** 2)) + 1e-12
        out += weight * band * periodic_envelope(rng, n)
    return out


def main() -> int:
    rng = np.random.default_rng(SEED)
    n = SAMPLE_RATE * LOOP_SECONDS
    left = channel(rng, n)
    right = 0.75 * left + 0.25 * channel(rng, n)  # estéreo largo mas coerente
    stereo = np.stack([left, right], axis=1)
    rms = np.sqrt(np.mean(stereo ** 2))
    stereo *= (10.0 ** (TARGET_RMS_DB / 20.0)) / rms
    peak = np.max(np.abs(stereo))
    if peak > 0.97:
        stereo *= 0.97 / peak

    # Emenda: o último e o primeiro quadro precisam ser vizinhos (filtragem circular -> sinal periódico).
    seam_jump = np.max(np.abs(stereo[0] - stereo[-1]))
    typical_step = np.median(np.abs(np.diff(stereo[:, 0])))
    print(f"emenda: salto {seam_jump:.5f} (passo típico {typical_step:.5f})")
    if seam_jump > typical_step * 20.0:
        print("ERRO: a emenda do loop não é contínua", file=sys.stderr)
        return 1

    pcm = (np.clip(stereo, -1.0, 1.0) * 32767.0).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "wind.wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SAMPLE_RATE)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", wav_path,
                        "-c:a", "libvorbis", "-q:a", "5", os.path.abspath(OUT)], check=True)
    print(f"ok: {os.path.abspath(OUT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
