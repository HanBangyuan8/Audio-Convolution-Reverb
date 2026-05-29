# Changelog

## v1.1.1 - 2026-05-30

Patch release.

- Refined the macOS studio interface with a compact top bar, native sidebar cleanup, aligned buttons, and full-width detail layout.
- Fixed clipped right-side content by removing hard minimum detail widths and fitting panels to the available column width.
- Removed duplicate picker labels in the playback and export controls.
- Improved app packaging reliability by retrying final bundle metadata cleanup before signature verification.

## v1.1.0 - 2026-05-29

Major release.

- Added automatic light/dark appearance using the system color scheme.
- Added in-app playback for dry, rendered, and impulse response files with A/B switching.
- Added preview rendering for short near-real-time auditioning.
- Added waveform, frequency response, decay, and level visualizations.
- Rebuilt the studio layout with a native macOS sidebar, compact top bar, full-width main workspace, aligned controls, and reliable vertical scrolling.
- Added drag-and-drop import for dry audio and impulse response files.
- Added AVFoundation-based WAV, AIFF, CAF, and M4A input plus WAV, AIFF, and CAF export.
- Added render progress, cancellation, and clearer error recovery.
- Expanded SQLite history and preset management with search, rename, delete, reveal, import, and export.
- Added professional reverb controls for gain staging, IR trim, fades, stereo width, wet normalization, latency compensation, and tail length.
- Added About and Preferences windows, Resources-based app icon support, DMG packaging with an Applications shortcut, and broader regression tests.

## v1.0.0 - 2026-05-29

Initial public release.

- Added native SwiftUI macOS app with polished studio interface.
- Added Swift FFT convolution engine, WAV import/export, and custom impulse response generation.
- Added SQLite render history and preset database.
- Added Swift CLI and Swift unit tests for DSP, WAV conversion, and database persistence.
- Extracted both original notebook analysis images into `assets/early-test-results`.
- Removed the notebook file from the repository so GitHub no longer classifies the project as Jupyter Notebook.
- Preserved the original notebook algorithm in `src/audio_convolution_reverb/original_notebook.py`.
