#!/usr/bin/env bash
# Builds a release APK with every dart-define the app actually reads (see
# lib/core/config/app_environment.dart's AppConfig.fromDartDefines()).
#
# Reading these from .env.local (copy .env.local.example, fill in real
# values -- already gitignored) rather than a hand-typed command is the
# whole point of this script: a manually-retyped command silently drops a
# define with no error, which is exactly how MICRO_LESSON_CDN_BASE_URL got
# left out of every build for most of a session, leaving 18 of 39
# micro-lesson clips showing "video not yet available" with nothing in the
# build log to say why. GOOGLE_WEB_CLIENT_ID is the one genuinely optional
# value (Google Sign-In is just unavailable without it) -- every other var
# is required and the build refuses to start without it.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ -f .env.local ]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

missing=()
for var in SUPABASE_URL SUPABASE_PUBLISHABLE_KEY API_BASE_URL; do
  if [ -z "${!var:-}" ]; then
    missing+=("$var")
  fi
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing required env var(s): ${missing[*]}" >&2
  echo "Copy .env.local.example to .env.local and fill in real values, or export them directly." >&2
  exit 1
fi

if [ -z "${GOOGLE_WEB_CLIENT_ID:-}" ]; then
  echo "Note: GOOGLE_WEB_CLIENT_ID is unset -- Google Sign-In will be unavailable in this build." >&2
fi
if [ -z "${MICRO_LESSON_CDN_BASE_URL:-}" ]; then
  echo "Note: MICRO_LESSON_CDN_BASE_URL is unset -- any clip without a bundled local video will show 'video not yet available'." >&2
fi

flutter build apk --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-}" \
  --dart-define=MICRO_LESSON_CDN_BASE_URL="${MICRO_LESSON_CDN_BASE_URL:-}"

echo "Built build/app/outputs/flutter-apk/app-release.apk"
