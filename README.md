# Audio Convolution Reverb

![macOS](https://img.shields.io/badge/macOS-10.15%2B-blue?style=flat)
![Python](https://img.shields.io/badge/Python-3.10%2B-147EFB?style=flat)
![SciPy](https://img.shields.io/badge/SciPy-1.10%2B-orange?style=flat)
![GitHub release](https://img.shields.io/github/v/release/HanBangyuan8/Audio-Convolution-Reverb?style=flat)
![GitHub Downloads](https://img.shields.io/github/downloads/HanBangyuan8/Audio-Convolution-Reverb/total?style=flat)
![GitHub Repo stars](https://img.shields.io/github/stars/HanBangyuan8/Audio-Convolution-Reverb?style=flat)

A desktop and command line convolution reverb tool built from the original portfolio notebook.

## Features

- Generate logarithmic sine sweeps for room recording
- Extract impulse responses from recorded sweeps
- Apply convolution reverb to dry audio
- Mix dry and wet levels
- Plot waveform, decay, frequency response, and energy decay
- Run from CLI or a lightweight desktop GUI
- Works with common audio files supported by `soundfile`

## Requirements

### Latest Version

- macOS 10.15+ for the included Tkinter desktop GUI
- Python 3.10+
- NumPy, SciPy, SoundFile, and Matplotlib
- Example audio files are included for demo rendering and impulse-response extraction

## Install

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

## Run

Launch the desktop GUI:

```bash
audio-reverb-gui
```

Use the CLI:

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

Run the bundled example render:

```bash
audio-reverb demo
```

## Build

```bash
python3 -m py_compile src/audio_convolution_reverb/*.py tests/*.py
pytest
```

## Package

```bash
./scripts/package_release.sh
open dist/Audio-Convolution-Reverb-v1.0.0.zip
```

## Original Work

The original notebook is kept at `notebooks/original_convolution_reverb.ipynb`. The reusable Python module keeps the same core function names and formulas:

- `generate_log_sweep`
- `extract_impulse_response`
- `apply_convolution_reverb`
- `analyze_impulse_response`

Production improvements were added around those functions: path handling, sample-rate matching, stereo support, CLI/GUI entry points, and safer output normalization.

## Release

Download v1.0.0 and newer source packages from [GitHub Releases](https://github.com/HanBangyuan8/Audio-Convolution-Reverb/releases).

Release notes are maintained in `CHANGELOG.md`.

## License

MIT License. See [LICENSE](LICENSE).

## Star History

<a href="https://www.star-history.com/?type=date&repos=HanBangyuan8%2FAudio-Convolution-Reverb">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=HanBangyuan8/Audio-Convolution-Reverb&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=HanBangyuan8/Audio-Convolution-Reverb&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=HanBangyuan8/Audio-Convolution-Reverb&type=date&legend=top-left" />
 </picture>
</a>
