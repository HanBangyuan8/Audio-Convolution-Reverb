from __future__ import annotations

import argparse
from pathlib import Path

from .core import (
    analyze_impulse_response,
    apply_convolution_reverb,
    extract_impulse_response,
    load_impulse_response,
    save_sweep,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="audio-reverb",
        description="Generate, extract, analyze, and apply convolution reverb.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    sweep = subparsers.add_parser("generate-sweep", help="Create a log sine sweep WAV.")
    sweep.add_argument("output")
    sweep.add_argument("--duration", type=float, default=10)
    sweep.add_argument("--sample-rate", type=int, default=44100)
    sweep.add_argument("--f-start", type=float, default=20)
    sweep.add_argument("--f-end", type=float, default=20000)

    extract = subparsers.add_parser("extract-ir", help="Extract an impulse response.")
    extract.add_argument("recorded")
    extract.add_argument("sweep")
    extract.add_argument("output")
    extract.add_argument("--length", type=float, default=10.0)

    apply = subparsers.add_parser("apply", help="Apply an impulse response to dry audio.")
    apply.add_argument("dry_audio")
    apply.add_argument("impulse_response")
    apply.add_argument("output")
    apply.add_argument("--wet", type=float, default=0.5)
    apply.add_argument("--dry", type=float, default=0.5)

    analyze = subparsers.add_parser("analyze", help="Plot an impulse response analysis.")
    analyze.add_argument("impulse_response")
    analyze.add_argument("--name", default="Space")
    analyze.add_argument("--output")
    analyze.add_argument("--no-show", action="store_true")

    subparsers.add_parser("demo", help="Render the bundled piano and vocal examples.")
    return parser


def main(argv: list[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "generate-sweep":
        save_sweep(args.output, args.duration, args.sample_rate, args.f_start, args.f_end)
        print(f"Generated sweep: {args.output}")
        return

    if args.command == "extract-ir":
        extract_impulse_response(args.recorded, args.sweep, args.length, args.output)
        print(f"Extracted impulse response: {args.output}")
        return

    if args.command == "apply":
        impulse_response, impulse_sample_rate = load_impulse_response(args.impulse_response)
        apply_convolution_reverb(
            args.dry_audio,
            impulse_response,
            args.output,
            wet_level=args.wet,
            dry_level=args.dry,
            impulse_sample_rate=impulse_sample_rate,
        )
        print(f"Reverb applied and saved to {args.output}")
        return

    if args.command == "analyze":
        impulse_response, sample_rate = load_impulse_response(args.impulse_response)
        analyze_impulse_response(
            impulse_response,
            sample_rate,
            args.name,
            output_file=args.output,
            show=not args.no_show,
        )
        if args.output:
            print(f"Saved analysis plot: {args.output}")
        return

    if args.command == "demo":
        examples = Path("examples/audio")
        output = Path("output")
        output.mkdir(exist_ok=True)
        bedroom_ir, bedroom_sr = load_impulse_response(examples / "bedroom_ir.wav")
        bathroom_ir, bathroom_sr = load_impulse_response(examples / "bathroom_ir.wav")
        apply_convolution_reverb(
            examples / "dry_piano.wav",
            bedroom_ir,
            output / "piano_bedroom_reverb.wav",
            impulse_sample_rate=bedroom_sr,
        )
        apply_convolution_reverb(
            examples / "dry_vocal.wav",
            bathroom_ir,
            output / "vocal_bathroom_reverb.wav",
            impulse_sample_rate=bathroom_sr,
        )
        print(f"Demo files written to {output.resolve()}")
