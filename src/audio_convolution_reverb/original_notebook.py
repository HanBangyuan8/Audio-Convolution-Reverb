"""Original notebook functions, preserved as project source.

This file keeps the portfolio notebook algorithm in Python form. The app adds
production code around it, but these functions intentionally mirror the original
notebook names and formulas.
"""

import matplotlib.pyplot as plt
import numpy as np
import scipy.signal as signal
import soundfile as sf


def generate_log_sweep(duration=10, sample_rate=44100, f_start=20, f_end=20000):
    """Generate logarithmic sine sweep for recording"""
    t = np.linspace(0, duration, int(sample_rate * duration))
    sweep = np.sin(
        2
        * np.pi
        * f_start
        * duration
        / np.log(f_end / f_start)
        * (np.exp(t * np.log(f_end / f_start) / duration) - 1)
    )
    return sweep / np.max(np.abs(sweep))


def extract_impulse_response(recorded_file, original_sweep_file, ir_length=10.0):
    """Extract impulse response from recorded sweep"""
    recorded, sr = sf.read(recorded_file)
    original, sr_orig = sf.read(original_sweep_file)

    inverse_sweep = original[::-1]
    impulse_response = signal.convolve(recorded, inverse_sweep, mode="full")

    peak_idx = np.argmax(np.abs(impulse_response))
    ir_samples = int(ir_length * sr)
    final_ir = impulse_response[peak_idx : peak_idx + ir_samples]

    return final_ir / np.max(np.abs(final_ir)), sr


def apply_convolution_reverb(dry_audio_file, impulse_response, output_file, wet_level=0.5, dry_level=0.5):
    """Apply convolution reverb to audio file"""
    dry_audio, sr = sf.read(dry_audio_file)

    wet_audio = signal.convolve(dry_audio, impulse_response, mode="full")

    min_length = min(len(dry_audio), len(wet_audio))
    mixed_audio = dry_level * dry_audio[:min_length] + wet_level * wet_audio[:min_length]

    mixed_audio = mixed_audio / np.max(np.abs(mixed_audio)) * 0.95
    sf.write(output_file, mixed_audio, samplerate=sr)
    print(f"Reverb applied and saved to {output_file}")


def analyze_impulse_response(impulse_response, sample_rate, space_name):
    """Analyze and plot impulse response"""
    t = np.arange(len(impulse_response)) / sample_rate

    plt.figure(figsize=(12, 6))

    plt.subplot(2, 2, 1)
    plt.plot(t, impulse_response)
    plt.title(f"{space_name} - Impulse Response")
    plt.xlabel("Time (s)")
    plt.ylabel("Amplitude")
    plt.grid(True)

    plt.subplot(2, 2, 2)
    envelope = np.abs(impulse_response)
    plt.plot(t, envelope)
    plt.yscale("log")
    plt.title(f"{space_name} - Decay")
    plt.xlabel("Time (s)")
    plt.ylabel("Amplitude (log)")
    plt.grid(True)

    plt.subplot(2, 2, 3)
    freqs, h = signal.freqz(impulse_response, worN=8000, fs=sample_rate)
    plt.plot(freqs, 20 * np.log10(np.abs(h)))
    plt.title(f"{space_name} - Frequency Response")
    plt.xlabel("Frequency (Hz)")
    plt.ylabel("Magnitude (dB)")
    plt.grid(True)
    plt.xscale("log")

    plt.subplot(2, 2, 4)
    energy = np.cumsum(impulse_response[::-1] ** 2)[::-1]
    energy_db = 10 * np.log10(energy / np.max(energy))
    plt.plot(t, energy_db)
    plt.title(f"{space_name} - Energy Decay")
    plt.xlabel("Time (s)")
    plt.ylabel("Energy (dB)")
    plt.grid(True)

    plt.tight_layout()
    plt.show()
