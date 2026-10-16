"""Gera assets/audio/sfx/rain_loop.ogg: chuva caindo no CHÃO (terra, grama, folhas), sintetizada, em loop perfeito.

Por que sintetizado (2026-10-10): a gravação usada antes (Ylmir, "Rain (loopable)") soava, nas palavras do usuário,
como "água caindo na água". O que distingue gota na água de gota no chão é a BOLHA: na água cada gota tem um "plic"
TONAL (ressonância de bolha com o tom variando). No chão o impacto é um estalo curto de ruído, sem tom. Então aqui:
- chiado de fundo: ruído rosa entre ~400 Hz e ~8 kHz (a massa de gotas distantes);
- "tamborilar": milhares de impactos curtos (1–4 ms de decaimento) de ruído filtrado em faixas de 1–6,5 kHz, com
  intensidade aleatória e posição estéreo própria — nenhum é tonal;
- gotas próximas, mais raras e um pouco mais graves (o "plac" na terra/folha);
- tudo em linha do tempo CIRCULAR (eventos que passam do fim continuam no começo; filtragem por FFT circular), então
  o loop emenda sem crossfade e sem clique. O script confere a emenda e a ausência de tom.

Uso: python tools/audio/generate_rain_loop.py  (requer numpy e ffmpeg no PATH)
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SAMPLE_RATE = 44100
LOOP_SECONDS = 45
SEED = 20261011
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "sfx", "rain_loop.ogg")

PATTER_RATE = 520.0       # impactos por segundo (chuva moderada)
CLOSE_DROP_RATE = 14.0    # gotas próximas por segundo
PATTER_BANDS = [1100.0, 1600.0, 2300.0, 3200.0, 4300.0, 5400.0, 6500.0]
CLOSE_BANDS = [700.0, 1000.0, 1400.0]
HISS_LEVEL = 0.35         # chiado relativo ao tamborilar (o tamborilar domina: é o "batendo no chão")
TARGET_RMS_DB = -21.0


def bandpassed_noise(rng: np.random.Generator, n: int, center: float, octaves: float) -> np.ndarray:
    freqs = np.fft.rfftfreq(n, 1.0 / SAMPLE_RATE)
    distance = np.log2(np.maximum(freqs, 1.0) / center)
    response = np.exp(-0.5 * (distance / (octaves * 0.5)) ** 2)
    response[0] = 0.0
    out = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * response, n)
    return out / (np.sqrt(np.mean(out ** 2)) + 1e-12)


def pink_hiss(rng: np.random.Generator, n: int) -> np.ndarray:
    freqs = np.fft.rfftfreq(n, 1.0 / SAMPLE_RATE)
    shape = 1.0 / np.sqrt(np.maximum(freqs, 1.0))  # rosa
    shape *= 1.0 / (1.0 + (400.0 / np.maximum(freqs, 1.0)) ** 4)  # passa-alta ~400 Hz
    shape *= 1.0 / (1.0 + (np.maximum(freqs, 1.0) / 8000.0) ** 4)  # passa-baixa ~8 kHz
    shape[0] = 0.0
    out = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * shape, n)  # circular: periódico no loop
    return out / (np.sqrt(np.mean(out ** 2)) + 1e-12)


def add_impacts(rng, out, n, rate, bands, octaves, decay_ms, gain_db_range):
    banks = [bandpassed_noise(rng, SAMPLE_RATE, c, octaves) for c in bands]
    count = rng.poisson(rate * LOOP_SECONDS)
    starts = rng.integers(0, n, count)
    for start in starts:
        bank = banks[rng.integers(0, len(banks))]
        tau = rng.uniform(*decay_ms) / 1000.0 * SAMPLE_RATE
        length = int(tau * 6.0)
        offset = rng.integers(0, SAMPLE_RATE - length)
        t = np.arange(length)
        envelope = np.exp(-t / tau) * np.minimum(1.0, t / 8.0)  # ataque de ~0,2 ms (sem clique)
        burst = bank[offset:offset + length] * envelope * 10.0 ** (rng.uniform(*gain_db_range) / 20.0)
        pan = rng.uniform(0.0, 1.0)
        idx = (start + t) % n  # linha do tempo circular: o loop emenda
        out[idx, 0] += burst * np.cos(pan * np.pi / 2.0)
        out[idx, 1] += burst * np.sin(pan * np.pi / 2.0)


def tonality(mono: np.ndarray) -> float:
    kernel = np.ones(61) / 61.0
    ratios = []
    for i in range(0, len(mono) - 8192, 8192):
        power = np.abs(np.fft.rfft(mono[i:i + 8192] * np.hanning(8192))) ** 2
        band = power[20:800]
        ratios.append(np.max(band / (np.convolve(band, kernel, mode="same") + 1e-12)))
    return float(np.median(ratios))


def main() -> int:
    rng = np.random.default_rng(SEED)
    n = SAMPLE_RATE * LOOP_SECONDS
    out = np.zeros((n, 2))
    add_impacts(rng, out, n, PATTER_RATE, PATTER_BANDS, 0.9, (1.0, 4.0), (-24.0, 0.0))
    add_impacts(rng, out, n, CLOSE_DROP_RATE, CLOSE_BANDS, 1.1, (3.0, 9.0), (-6.0, 6.0))
    patter_rms = np.sqrt(np.mean(out ** 2))
    out[:, 0] += pink_hiss(rng, n) * patter_rms * HISS_LEVEL
    out[:, 1] += pink_hiss(rng, n) * patter_rms * HISS_LEVEL
    out *= (10.0 ** (TARGET_RMS_DB / 20.0)) / np.sqrt(np.mean(out ** 2))
    peak = np.max(np.abs(out))
    if peak > 0.97:
        out *= 0.97 / peak

    tone = tonality(out[:, 0])
    print(f"tonalidade (pico/media local): {tone:.1f}  (ruido ~7-8; musica/bolha 30+)")
    if tone > 15.0:
        print("ERRO: o som ficou tonal", file=sys.stderr)
        return 1

    pcm = (np.clip(out, -1.0, 1.0) * 32767.0).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "rain.wav")
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
