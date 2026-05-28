# Audio Convolution Reverb

A complete portfolio-ready convolution reverb tool based on the original notebook code.

The project turns a recorded sine sweep into an impulse response, analyzes the room response, and applies convolution reverb to any dry audio file. It includes a command line app, a small desktop GUI, sample audio, tests, and release packaging.

## Features

- Generate logarithmic sine sweeps for room recording
- Extract impulse responses from recorded sweeps
- Apply convolution reverb to dry audio
- Mix dry and wet levels
- Plot waveform, decay, frequency response, and energy decay
- Run from CLI or a lightweight desktop GUI
- Works with common audio files supported by `soundfile`

## Project Layout

```text
src/audio_convolution_reverb/   Python package and app code
examples/audio/                 Example dry audio, recordings, and impulse responses
notebooks/                      Original notebook source
tests/                          Regression tests
scripts/                        Release helper scripts
```

## Install

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

## Use the GUI

```bash
audio-reverb-gui
```

Choose a dry audio file, choose an impulse response file, set dry/wet levels, then render a new WAV file.

## Use the CLI

Generate a sweep:

```bash
audio-reverb generate-sweep examples/audio/test_sweep.wav --duration 10 --sample-rate 48000
```

Extract an impulse response:

```bash
audio-reverb extract-ir examples/audio/bedroom_recorded.wav examples/audio/test_sweep.wav examples/audio/bedroom_ir.wav
```

Apply reverb:

```bash
audio-reverb apply examples/audio/dry_piano.wav examples/audio/bedroom_ir.wav output/piano_bedroom_reverb.wav --wet 0.5 --dry 0.5
```

Analyze an impulse response:

```bash
audio-reverb analyze examples/audio/bedroom_ir.wav --name Bedroom --output output/bedroom_analysis.png
```

Run the bundled demo:

```bash
audio-reverb demo
```

## Original Work

The original notebook is kept at `notebooks/original_convolution_reverb.ipynb`. The reusable Python module keeps the same core function names and formulas from that notebook:

- `generate_log_sweep`
- `extract_impulse_response`
- `apply_convolution_reverb`
- `analyze_impulse_response`

Small production improvements were added around those functions: path handling, sample-rate matching, stereo support, CLI/GUI entry points, and safer output normalization.

## Test

```bash
pytest
```

## Build a Release Package

```bash
scripts/package_release.sh
```

This creates a source distribution and a Git archive zip in `dist/`.
