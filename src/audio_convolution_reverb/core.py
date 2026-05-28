from __future__ import annotations

from pathlib import Path
from typing import Iterable

import numpy as np
import scipy.signal as signal
import soundfile as sf


AudioPath = str | Path


def generate_log_sweep(
    duration: float = 10,
    sample_rate: int = 44100,
    f_start: float = 20,
    f_end: float = 20000,
) -> np.ndarray:
    """Generate logarithmic sine sweep for recording."""
    t = np.linspace(0, duration, int(sample_rate * duration))
    sweep = np.sin(
        2
        * np.pi
        * f_start
        * duration
        / np.log(f_end / f_start)
        * (np.exp(t * np.log(f_end / f_start) / duration) - 1)
    )
    return _normalize_peak(sweep)


def extract_impulse_response(
    recorded_file: AudioPath,
    original_sweep_file: AudioPath,
    ir_length: float = 10.0,
    output_file: AudioPath | None = None,
) -> tuple[np.ndarray, int]:
    """Extract impulse response from recorded sweep."""
    recorded, sr = load_audio(recorded_file)
    original, sr_orig = load_audio(original_sweep_file)

    recorded = _to_mono(recorded)
    original = _to_mono(original)
    if sr_orig != sr:
        original = _resample(original, sr_orig, sr)

    # Create inverse filter (time-reversed sweep).
    inverse_sweep = original[::-1]

    # Deconvolve by convolving with inverse.
    impulse_response = signal.convolve(recorded, inverse_sweep, mode="full")

    # Find peak and extract IR.
    peak_idx = int(np.argmax(np.abs(impulse_response)))
    ir_samples = int(ir_length * sr)
    final_ir = impulse_response[peak_idx : peak_idx + ir_samples]

    final_ir = _normalize_peak(final_ir)
    if output_file is not None:
        save_audio(output_file, final_ir, sr)
    return final_ir, sr


def apply_convolution_reverb(
    dry_audio_file: AudioPath,
    impulse_response: np.ndarray,
    output_file: AudioPath,
    wet_level: float = 0.5,
    dry_level: float = 0.5,
    impulse_sample_rate: int | None = None,
) -> np.ndarray:
    """Apply convolution reverb to audio file."""
    dry_audio, sr = load_audio(dry_audio_file)
    ir = np.asarray(impulse_response, dtype=np.float64)
    ir = _to_mono(ir)

    if impulse_sample_rate is not None and impulse_sample_rate != sr:
        ir = _resample(ir, impulse_sample_rate, sr)

    if dry_audio.ndim == 1:
        mixed_audio = _mix_channel(dry_audio, ir, wet_level, dry_level)
    else:
        channels = [
            _mix_channel(dry_audio[:, channel], ir, wet_level, dry_level)
            for channel in range(dry_audio.shape[1])
        ]
        mixed_audio = np.column_stack(channels)

    mixed_audio = _normalize_peak(mixed_audio, peak=0.95)
    save_audio(output_file, mixed_audio, sr)
    return mixed_audio


def analyze_impulse_response(
    impulse_response: np.ndarray,
    sample_rate: int,
    space_name: str,
    output_file: AudioPath | None = None,
    show: bool = True,
) -> None:
    """Analyze and plot impulse response."""
    import matplotlib.pyplot as plt

    impulse_response = _to_mono(np.asarray(impulse_response, dtype=np.float64))
    t = np.arange(len(impulse_response)) / sample_rate

    plt.figure(figsize=(12, 6))

    # Waveform.
    plt.subplot(2, 2, 1)
    plt.plot(t, impulse_response)
    plt.title(f"{space_name} - Impulse Response")
    plt.xlabel("Time (s)")
    plt.ylabel("Amplitude")
    plt.grid(True)

    # Decay envelope.
    plt.subplot(2, 2, 2)
    envelope = np.abs(impulse_response)
    plt.plot(t, np.maximum(envelope, 1e-12))
    plt.yscale("log")
    plt.title(f"{space_name} - Decay")
    plt.xlabel("Time (s)")
    plt.ylabel("Amplitude (log)")
    plt.grid(True)

    # Frequency response.
    plt.subplot(2, 2, 3)
    freqs, h = signal.freqz(impulse_response, worN=8000, fs=sample_rate)
    plt.plot(freqs, 20 * np.log10(np.maximum(np.abs(h), 1e-12)))
    plt.title(f"{space_name} - Frequency Response")
    plt.xlabel("Frequency (Hz)")
    plt.ylabel("Magnitude (dB)")
    plt.grid(True)
    plt.xscale("log")

    # RT60-style energy decay estimate.
    plt.subplot(2, 2, 4)
    energy = np.cumsum(impulse_response[::-1] ** 2)[::-1]
    energy_db = 10 * np.log10(np.maximum(energy / np.max(energy), 1e-12))
    plt.plot(t, energy_db)
    plt.title(f"{space_name} - Energy Decay")
    plt.xlabel("Time (s)")
    plt.ylabel("Energy (dB)")
    plt.grid(True)

    plt.tight_layout()
    if output_file is not None:
        Path(output_file).parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(output_file, dpi=160)
    if show:
        plt.show()
    else:
        plt.close()


def load_audio(path: AudioPath) -> tuple[np.ndarray, int]:
    audio, sample_rate = sf.read(path)
    return np.asarray(audio, dtype=np.float64), int(sample_rate)


def save_audio(path: AudioPath, audio: np.ndarray, sample_rate: int) -> None:
    output_path = Path(path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(output_path, audio, samplerate=sample_rate)


def load_impulse_response(path: AudioPath) -> tuple[np.ndarray, int]:
    impulse_response, sample_rate = load_audio(path)
    return _to_mono(impulse_response), sample_rate


def save_sweep(
    output_file: AudioPath,
    duration: float = 10,
    sample_rate: int = 44100,
    f_start: float = 20,
    f_end: float = 20000,
) -> np.ndarray:
    sweep = generate_log_sweep(duration, sample_rate, f_start, f_end)
    save_audio(output_file, sweep, sample_rate)
    return sweep


def _mix_channel(
    dry_audio: np.ndarray,
    impulse_response: np.ndarray,
    wet_level: float,
    dry_level: float,
) -> np.ndarray:
    wet_audio = signal.convolve(dry_audio, impulse_response, mode="full")
    min_length = min(len(dry_audio), len(wet_audio))
    return dry_level * dry_audio[:min_length] + wet_level * wet_audio[:min_length]


def _to_mono(audio: np.ndarray) -> np.ndarray:
    if audio.ndim == 1:
        return audio
    return np.mean(audio, axis=1)


def _normalize_peak(audio: np.ndarray, peak: float = 1.0) -> np.ndarray:
    max_value = float(np.max(np.abs(audio))) if audio.size else 0.0
    if max_value == 0:
        return audio
    return audio / max_value * peak


def _resample(audio: np.ndarray, source_rate: int, target_rate: int) -> np.ndarray:
    gcd = np.gcd(source_rate, target_rate)
    up = target_rate // gcd
    down = source_rate // gcd
    if audio.ndim == 1:
        return signal.resample_poly(audio, up, down)
    channels: Iterable[np.ndarray] = (
        signal.resample_poly(audio[:, channel], up, down)
        for channel in range(audio.shape[1])
    )
    return np.column_stack(list(channels))
