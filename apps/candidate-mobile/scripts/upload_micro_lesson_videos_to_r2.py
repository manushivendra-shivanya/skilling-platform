#!/usr/bin/env python3
"""Upload micro-lesson video variants to Cloudflare R2.

R2 was chosen over Supabase Storage specifically to avoid Supabase's
free-tier storage/egress limits as the clip catalogue grows -- R2 gives
10GB storage free and, more importantly, zero egress/bandwidth fees ever,
which matters far more than storage once clips are actually being
streamed by candidates.

This is a deliberately separate, opt-in step from
micro_lesson_video_pipeline.py: that script prepares local files
(thumbnails bundled into the app, low-bandwidth variants generated but
NOT bundled); this script is what actually gets a variant off the local
disk and onto a URL `MicroLessonPlayerScreen` can stream from. It does
NOT rewrite warehouse_clips.json automatically -- moving a specific clip
from a bundled asset:// URL to a remote https:// one is a deliberate,
per-clip content decision, not something to do silently as a side effect
of an upload.

Setup (do this in the Cloudflare dashboard, not by pasting secrets into
a chat or committing them to git):
    1. R2 -> Manage R2 API Tokens -> Create API Token (this is a
       different page from the general "API Tokens" settings -- a plain
       Cloudflare API token cannot authenticate S3-compatible requests).
    2. Export the resulting credentials as environment variables in your
       own shell -- never as literals in this file or any committed file:
           export R2_ACCOUNT_ID=...
           export R2_ACCESS_KEY_ID=...
           export R2_SECRET_ACCESS_KEY=...
           export R2_BUCKET_NAME=...
           export R2_PUBLIC_BASE_URL=...   # see note below
    3. Public serving: Cloudflare explicitly discourages relying on the
       default *.r2.dev bucket URL for production traffic (unpredictable
       rate limiting). Attach a custom domain to the bucket (R2 ->
       bucket -> Settings -> Custom Domains, free, just a CNAME) and set
       R2_PUBLIC_BASE_URL to that, e.g. https://videos.example.com.
       Without it, this script still uploads fine but prints a warning
       instead of a usable public URL.

Usage:
    python3 scripts/upload_micro_lesson_videos_to_r2.py [--dry-run] [--include-masters]

    --dry-run          List what would be uploaded without uploading.
    --include-masters  Also upload the full-quality masters from
                        assets/micro_lessons/videos/, not just the
                        low-bandwidth variants. Off by default -- masters
                        are large and the whole point of this step is
                        usually just getting the low-bandwidth variant
                        somewhere streamable.

Requires boto3 (`pip3 install boto3`).
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOWBANDWIDTH_DIR = ROOT / "assets/micro_lessons/videos_lowbandwidth"
MASTERS_DIR = ROOT / "assets/micro_lessons/videos"

REQUIRED_ENV_VARS = [
    "R2_ACCOUNT_ID",
    "R2_ACCESS_KEY_ID",
    "R2_SECRET_ACCESS_KEY",
    "R2_BUCKET_NAME",
]


def require_env() -> dict[str, str]:
    values = {name: os.environ.get(name) for name in REQUIRED_ENV_VARS}
    missing = [name for name, value in values.items() if not value]
    if missing:
        print(
            "Missing required environment variables: " + ", ".join(missing),
            file=sys.stderr,
        )
        print(
            "Set these in your own shell first -- see the module "
            "docstring for where to generate them. Never pass secrets "
            "as command-line arguments (they end up in shell history).",
            file=sys.stderr,
        )
        sys.exit(1)
    return values  # type: ignore[return-value]


def upload_dir(client, bucket: str, local_dir: Path, key_prefix: str, dry_run: bool):
    if not local_dir.exists():
        print(f"Skipping {local_dir} (does not exist).")
        return []
    uploaded = []
    for path in sorted(local_dir.glob("*.mp4")):
        key = f"{key_prefix}/{path.name}"
        size_kb = path.stat().st_size / 1024
        if dry_run:
            print(f"[dry-run] would upload {path.relative_to(ROOT)} -> {key} ({size_kb:.0f}KB)")
        else:
            client.upload_file(str(path), bucket, key)
            print(f"uploaded {path.relative_to(ROOT)} -> {key} ({size_kb:.0f}KB)")
        uploaded.append(key)
    return uploaded


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--include-masters", action="store_true")
    args = parser.parse_args()

    env = require_env()

    try:
        import boto3
    except ImportError:
        print("boto3 is required: pip3 install boto3", file=sys.stderr)
        sys.exit(1)

    client = boto3.client(
        "s3",
        endpoint_url=f"https://{env['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com",
        aws_access_key_id=env["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=env["R2_SECRET_ACCESS_KEY"],
        region_name="auto",
    )

    bucket = env["R2_BUCKET_NAME"]
    uploaded_keys: list[str] = []
    uploaded_keys += upload_dir(
        client, bucket, LOWBANDWIDTH_DIR, "micro-lessons/videos_lowbandwidth", args.dry_run
    )
    if args.include_masters:
        uploaded_keys += upload_dir(
            client, bucket, MASTERS_DIR, "micro-lessons/videos", args.dry_run
        )

    if not uploaded_keys:
        print("Nothing to upload -- run micro_lesson_video_pipeline.py first.")
        return

    public_base = os.environ.get("R2_PUBLIC_BASE_URL")
    if not public_base:
        verb = "would be uploaded" if args.dry_run else "uploaded"
        print(
            f"\nNo R2_PUBLIC_BASE_URL set -- files {verb}, but you don't "
            "have a usable public URL yet. Attach a custom domain to the "
            "bucket in the R2 dashboard, then set R2_PUBLIC_BASE_URL and "
            "re-run to see the resulting URLs."
        )
        return

    print("\nPublic URLs (update warehouse_clips.json's videoUrl by hand for any clip you're moving off-bundle):")
    for key in uploaded_keys:
        print(f"  {public_base.rstrip('/')}/{key}")


if __name__ == "__main__":
    main()
