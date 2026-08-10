#!/bin/bash
#
# SessionStart hook for Claude Code on the web.
#
# Installs the toolchains the repository's required validation depends on
# (see AGENTS.md -> "Required validation"), so an agent session can run
# dart format / flutter analyze / flutter test and the apps/api build,
# lint and test commands without any manual setup.
#
# The Android SDK step is best-effort: it needs dl.google.com, which some
# egress policies refuse. When that happens the hook warns and continues, so
# a session still gets Flutter and the API toolchain. See the section below.
#
set -euo pipefail

# Only provision the hosted web container. Local machines keep their own
# toolchains, which are usually already set up and may differ deliberately.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REPO_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Keep in step with the stable channel used by .github/workflows/build-apk.yml.
# pubspec.yaml requires Dart ^3.12.2 and Flutter >=3.44.0; this release ships
# Dart 3.12.2. Bump this one line to move the whole team's sessions.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.9}"
FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/.flutter-sdk/$FLUTTER_VERSION}"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"

export FLUTTER_SUPPRESS_ANALYTICS=1
export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
export PATH="$FLUTTER_ROOT/bin:$PUB_CACHE/bin:$PATH"

log() { echo "[session-start] $*"; }

# --- Flutter SDK ------------------------------------------------------------
# Idempotent: a cached container replays this hook and should fall straight
# through. `flutter --version` is the readiness check rather than a directory
# test, so a half-extracted SDK from an interrupted run is repaired.
if [ -x "$FLUTTER_ROOT/bin/flutter" ] && "$FLUTTER_ROOT/bin/flutter" --version >/dev/null 2>&1; then
  log "Flutter $FLUTTER_VERSION already installed at $FLUTTER_ROOT"
else
  log "Installing Flutter $FLUTTER_VERSION to $FLUTTER_ROOT"
  rm -rf "$FLUTTER_ROOT"
  mkdir -p "$(dirname "$FLUTTER_ROOT")"

  tmp_archive="$(mktemp -d)/$FLUTTER_ARCHIVE"
  curl -fsSL --retry 3 --retry-delay 2 --retry-connrefused \
    -o "$tmp_archive" "$FLUTTER_URL"

  # The tarball unpacks to a top-level `flutter/` directory; land it on the
  # version-qualified path so several SDKs can coexist across bumps.
  tmp_extract="$(mktemp -d)"
  tar -xf "$tmp_archive" -C "$tmp_extract"
  mv "$tmp_extract/flutter" "$FLUTTER_ROOT"
  rm -rf "$tmp_archive" "$tmp_extract"
fi

# flutter_tools shells out to git for its version check and refuses to run
# from a directory git considers foreign.
git config --global --add safe.directory "$FLUTTER_ROOT" 2>/dev/null || true

# Pull the host build artifacts (flutter_tester, sky_engine) that
# `flutter test` and `flutter analyze` need. No-op once cached.
log "Precaching Flutter host artifacts"
flutter precache --universal

# --- apps/candidate-mobile (Flutter) ---------------------------------------
log "Resolving Dart packages for apps/candidate-mobile"
(cd "$REPO_DIR/apps/candidate-mobile" && flutter pub get)

# --- apps/api (NestJS) ------------------------------------------------------
# `npm install` rather than `npm ci` so a warm container reuses node_modules
# instead of deleting and refetching the tree on every session.
log "Installing npm dependencies for apps/api"
(cd "$REPO_DIR/apps/api" && npm install --no-audit --no-fund)

# --- Android SDK ------------------------------------------------------------
# Only `flutter build apk --debug` needs this. Every package is served from
# dl.google.com, which some egress policies refuse; treat failure as a
# degraded session rather than a broken one, so analyze/test still work.
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/.android-sdk}"
export ANDROID_HOME="$ANDROID_SDK_ROOT"

# Google publishes no version-less download URL, so the command-line tools
# bundle is pinned by build number. The SDK packages match the app's Gradle
# config: compileSdk/targetSdk 36 in android/app/build.gradle.kts.
ANDROID_CMDLINE_TOOLS_BUILD="${ANDROID_CMDLINE_TOOLS_BUILD:-13114758}"
ANDROID_PACKAGES=("platform-tools" "platforms;android-36" "build-tools;36.0.0")

install_android_sdk() {
  local sdkmanager="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"

  if [ ! -x "$sdkmanager" ]; then
    local tmp zip staging
    tmp="$(mktemp -d)"; zip="$tmp/cmdline-tools.zip"
    curl -fsSL --retry 2 --retry-delay 2 -o "$zip" \
      "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip" \
      || { rm -rf "$tmp"; return 1; }

    # The archive unpacks to cmdline-tools/, but sdkmanager only resolves the
    # SDK root when it lives at cmdline-tools/latest/.
    staging="$(mktemp -d)"
    unzip -q "$zip" -d "$staging"
    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
    rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
    mv "$staging/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
    rm -rf "$tmp" "$staging"
  fi

  # Licences must be accepted before any package will install; `yes` closes
  # the pipe early, which is not a failure.
  yes | "$sdkmanager" --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null 2>&1 || true
  "$sdkmanager" --sdk_root="$ANDROID_SDK_ROOT" "${ANDROID_PACKAGES[@]}" || return 1
  flutter config --android-sdk "$ANDROID_SDK_ROOT" >/dev/null 2>&1 || true
}

if install_android_sdk; then
  log "Android SDK ready at $ANDROID_SDK_ROOT"
  ANDROID_SDK_READY=1
else
  ANDROID_SDK_READY=0
  log "WARNING: Android SDK unavailable -- 'flutter build apk' will not run."
  log "  Its packages come from dl.google.com. If this environment's egress"
  log "  policy denies that host (403 on CONNECT), allowlist it in the"
  log "  environment's network settings, then start a fresh session."
  log "  Unaffected: dart format, flutter analyze, flutter test, apps/api."
  log "  .github/workflows/build-apk.yml still builds the APK in CI."
fi

# --- Persist environment for the session ------------------------------------
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export FLUTTER_ROOT=\"$FLUTTER_ROOT\""
    echo "export PUB_CACHE=\"$PUB_CACHE\""
    echo "export FLUTTER_SUPPRESS_ANALYTICS=1"
    echo "export PATH=\"$FLUTTER_ROOT/bin:$PUB_CACHE/bin:\$PATH\""
    if [ "$ANDROID_SDK_READY" = "1" ]; then
      echo "export ANDROID_SDK_ROOT=\"$ANDROID_SDK_ROOT\""
      echo "export ANDROID_HOME=\"$ANDROID_SDK_ROOT\""
    fi
  } >> "$CLAUDE_ENV_FILE"
fi

log "Ready. flutter $(flutter --version 2>/dev/null | head -1 | awk '{print $2}') | node $(node --version)"
