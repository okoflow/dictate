#!/usr/bin/env python3
"""Print the peak level of a 16-bit mono WAV; exit 1 if it is below --min-peak (0..1).

Usage: audio-level.py <file.wav> [--min-peak 0.1]
"""
import argparse
import struct
import sys
import wave


def peak(path: str) -> float:
    with wave.open(path, "rb") as reader:
        if reader.getsampwidth() != 2 or reader.getnchannels() != 1:
            sys.exit(f"{path}: expected 16-bit mono WAV")
        frames = reader.readframes(reader.getnframes())
    samples = struct.unpack(f"<{len(frames) // 2}h", frames)
    return max((abs(sample) for sample in samples), default=0) / 32768


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("path")
    parser.add_argument("--min-peak", type=float, default=0.0)
    args = parser.parse_args()
    level = peak(args.path)
    print(f"{args.path}: peak {level:.3f}")
    sys.exit(0 if level >= args.min_peak else 1)


if __name__ == "__main__":
    main()
