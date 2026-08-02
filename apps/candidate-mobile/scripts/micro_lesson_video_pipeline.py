#!/usr/bin/env python3
"""Micro-lesson video asset pipeline.

Validates every clip under assets/micro_lessons/videos/ against the
naming and compression rules below, then generates a thumbnail and a
low-bandwidth transcode for each. Run this whenever a new clip is added
to the catalogue, before wiring it into warehouse_clips.json.

Naming rule:
    snake_case, .mp4 extension, e.g. "receiving_frozen_check.mp4".
    (Not required to exactly equal the clip id in warehouse_clips.json --
    ids are namespaced/versioned ("clip_receiving_frozen_001"), filenames
    just need to be readable and consistent.)

Compression check:
    - Duration must be 10s (+/- 0.5s) -- the catalogue's contract, see
      MicroLessonClipValidator.
    - Flags (warns, does not fail) any bundled clip over 3MB: these ship
      inside the app binary, not streamed, so size directly affects app
      download size for every candidate, not just those who watch this
      specific clip.

Low-bandwidth variant:
    480px-wide (matching the clips' 9:16 orientation), ~600kbps video +
    64kbps audio -- roughly a 3x size reduction from the bundled master.
    Written to assets/micro_lessons/videos_lowbandwidth/, deliberately
    NOT registered in pubspec.yaml: these aren't meant to be bundled into
    the app binary at all. They're prepared here for the eventual
    "upload to remote storage, serve the low-bandwidth variant on poor
    connections" step -- see docs/generated/current-state.md for that
    plan. Bundling both variants into the app would defeat the point.

Thumbnail:
    A single frame at t=1s, written to assets/micro_lessons/thumbnails/
    as <clip-filename-stem>.jpg. These ARE meant to be bundled (small,
    genuinely useful for the clip list UI) -- see pubspec.yaml.

Requires ffmpeg + ffprobe on PATH (`brew install ffmpeg` on macOS).
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VIDEOS_DIR = ROOT / "assets/micro_lessons/videos"
THUMBNAILS_DIR = ROOT / "assets/micro_lessons/thumbnails"
LOWBANDWIDTH_DIR = ROOT / "assets/micro_lessons/videos_lowbandwidth"

NAME_PATTERN = re.compile(r"^[a-z][a-z0-9]*(_[a-z0-9]+)+\.mp4$")
MAX_BUNDLED_SIZE_BYTES = 3 * 1024 * 1024
EXPECTED_DURATION_SECONDS = 10.0
DURATION_TOLERANCE_SECONDS = 0.5

THUMBNAIL_AT_SECONDS = 1.0
LOWBANDWIDTH_HEIGHT = 854
LOWBANDWIDTH_VIDEO_BITRATE = "600k"
LOWBANDWIDTH_AUDIO_BITRATE = "64k"


def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


def ffprobe_json(path: Path) -> dict:
    result = run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=size,duration",
            "-of",
            "json",
            str(path),
        ]
    )
    return json.loads(result.stdout)


def check_naming(path: Path, errors: list[str]) -> None:
    if not NAME_PATTERN.match(path.name):
        errors.append(
            f"{path.name}: filename must be snake_case, e.g. "
            "'receiving_frozen_check.mp4'"
        )


def check_compression(
    path: Path, probe: dict, errors: list[str], warnings: list[str]
) -> None:
    size = int(probe["format"]["size"])
    duration = float(probe["format"]["duration"])
    if abs(duration - EXPECTED_DURATION_SECONDS) > DURATION_TOLERANCE_SECONDS:
        errors.append(
            f"{path.name}: duration {duration:.1f}s, expected "
            f"{EXPECTED_DURATION_SECONDS:.0f}s "
            f"(+/- {DURATION_TOLERANCE_SECONDS}s)"
        )
    if size > MAX_BUNDLED_SIZE_BYTES:
        warnings.append(
            f"{path.name}: {size / 1024 / 1024:.2f}MB exceeds the "
            f"{MAX_BUNDLED_SIZE_BYTES / 1024 / 1024:.0f}MB bundled-clip "
            "budget -- re-encode before shipping"
        )


def generate_thumbnail(path: Path) -> Path:
    THUMBNAILS_DIR.mkdir(parents=True, exist_ok=True)
    out = THUMBNAILS_DIR / f"{path.stem}.jpg"
    run(
        [
            "ffmpeg",
            "-y",
            "-ss",
            str(THUMBNAIL_AT_SECONDS),
            "-i",
            str(path),
            "-frames:v",
            "1",
            "-q:v",
            "3",
            str(out),
        ]
    )
    return out


def generate_lowbandwidth(path: Path) -> Path:
    LOWBANDWIDTH_DIR.mkdir(parents=True, exist_ok=True)
    out = LOWBANDWIDTH_DIR / path.name
    run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(path),
            "-vf",
            f"scale=-2:{LOWBANDWIDTH_HEIGHT}",
            "-c:v",
            "libx264",
            "-b:v",
            LOWBANDWIDTH_VIDEO_BITRATE,
            "-c:a",
            "aac",
            "-b:a",
            LOWBANDWIDTH_AUDIO_BITRATE,
            str(out),
        ]
    )
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Validate naming/compression only; skip generating "
        "thumbnails and low-bandwidth variants.",
    )
    args = parser.parse_args()

    if not VIDEOS_DIR.exists():
        print(f"No videos directory at {VIDEOS_DIR}", file=sys.stderr)
        sys.exit(1)

    clips = sorted(VIDEOS_DIR.glob("*.mp4"))
    if not clips:
        print("No .mp4 clips found under assets/micro_lessons/videos/.")
        return

    errors: list[str] = []
    warnings: list[str] = []
    probes: dict[Path, dict] = {}
    for clip in clips:
        check_naming(clip, errors)
        probe = ffprobe_json(clip)
        probes[clip] = probe
        check_compression(clip, probe, errors, warnings)

    for warning in warnings:
        print(f"WARNING: {warning}")
    for error in errors:
        print(f"ERROR: {error}")

    if not args.check_only:
        for clip in clips:
            thumbnail = generate_thumbnail(clip)
            lowbandwidth = generate_lowbandwidth(clip)
            original_kb = int(probes[clip]["format"]["size"]) / 1024
            lowbandwidth_kb = lowbandwidth.stat().st_size / 1024
            print(
                f"{clip.name}: {original_kb:.0f}KB -> "
                f"thumbnail {thumbnail.relative_to(ROOT)}, "
                f"low-bandwidth {lowbandwidth.relative_to(ROOT)} "
                f"({lowbandwidth_kb:.0f}KB, "
                f"{100 - (lowbandwidth_kb / original_kb * 100):.0f}% smaller)"
            )

    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
