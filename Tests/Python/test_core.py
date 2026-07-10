from pathlib import Path

import numpy as np

from audio_convolution_reverb.core import (
    apply_convolution_reverb,
    extract_impulse_response,
    generate_log_sweep,
    save_audio,
)


def test_generate_log_sweep_is_normalized() -> None:
    sweep = generate_log_sweep(duration=0.1, sample_rate=1000, f_start=20, f_end=200)
    assert len(sweep) == 100
    assert np.max(np.abs(sweep)) <= 1.0


def test_apply_convolution_reverb_writes_output(tmp_path: Path) -> None:
    dry = np.zeros(64)
    dry[0] = 1.0
    ir = np.array([1.0, 0.5, 0.25])
    dry_path = tmp_path / "dry.wav"
    output_path = tmp_path / "out.wav"

    save_audio(dry_path, dry, 8000)
    rendered = apply_convolution_reverb(dry_path, ir, output_path, wet_level=1.0, dry_level=0.0)

    assert output_path.exists()
    assert rendered.shape[0] == dry.shape[0]
    assert rendered[0] > rendered[1] > rendered[2]


def test_extract_impulse_response_writes_output(tmp_path: Path) -> None:
    sweep = generate_log_sweep(duration=0.1, sample_rate=1000, f_start=20, f_end=200)
    recorded = np.concatenate([np.zeros(10), sweep * 0.8, np.zeros(50)])
    sweep_path = tmp_path / "sweep.wav"
    recorded_path = tmp_path / "recorded.wav"
    output_path = tmp_path / "ir.wav"

    save_audio(sweep_path, sweep, 1000)
    save_audio(recorded_path, recorded, 1000)
    impulse_response, sample_rate = extract_impulse_response(recorded_path, sweep_path, 0.02, output_path)

    assert sample_rate == 1000
    assert output_path.exists()
    assert len(impulse_response) == 20
