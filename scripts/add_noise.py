#!/usr/bin/env python3
"""Mix deterministic white noise into a 16-bit mono WAV at a given signal-to-noise ratio.

Usage: add_noise.py <in.wav> <out.wav> [snr_db]
"""
import math
import random
import struct
import sys
import wave


def main(source: str, target: str, snr_db: float) -> None:
    with wave.open(source, "rb") as reader:
        params = reader.getparams()
        frames = reader.readframes(reader.getnframes())
    if params.sampwidth != 2 or params.nchannels != 1:
        sys.exit("expected 16-bit mono WAV")

    samples = struct.unpack(f"<{len(frames) // 2}h", frames)
    power = sum(sample * sample for sample in samples) / len(samples)
    sigma = math.sqrt(power / (10 ** (snr_db / 10)))
    rng = random.Random(1234)
    noisy = [max(-32768, min(32767, int(sample + rng.gauss(0, sigma)))) for sample in samples]

    with wave.open(target, "wb") as writer:
        writer.setparams(params)
        writer.writeframes(struct.pack(f"<{len(noisy)}h", *noisy))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 15.0)
