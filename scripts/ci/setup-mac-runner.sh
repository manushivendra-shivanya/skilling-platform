#!/usr/bin/env bash
# Registers this Mac as a self-hosted GitHub Actions runner for this repo,
# and installs it as a launchd service so it keeps running across reboots
# and logouts (not just while a terminal stays open).
#
# Why: the account's included GitHub Actions minutes are fully exhausted
# for this billing cycle (resets 2026-09-01). A self-hosted runner's time
# is never billed against that quota -- GitHub only meters its own hosted
# runners -- so this is how build-apk.yml keeps working until the reset
# without paying for overage. .github/workflows/build-apk.yml already
# targets `runs-on: [self-hosted, macOS]`; this script is what makes a
# matching runner actually exist.
#
# What this does NOT do: generate the registration token. That token is
# short-lived (about an hour) and tied to your GitHub login, so it has to
# come from you clicking through the GitHub UI right before running this,
# not from a script committed to the repo. See the printed instructions
# below, or:
#   https://github.com/manushivendra-shivanya/skilling-platform/settings/actions/runners/new
#   -> Runner image: macOS -> copy the --token value from the "Configure"
#      command GitHub shows you there.
#
# Usage:
#   ./scripts/ci/setup-mac-runner.sh <registration-token>
#
# Re-running this script is safe: it skips the download if the runner is
# already installed at $RUNNER_DIR, and `config.sh` refuses to
# double-register the same machine under the same name without --replace.

set -euo pipefail

REPO_URL="https://github.com/manushivendra-shivanya/skilling-platform"
RUNNER_DIR="$HOME/actions-runners/skilling-platform"
RUNNER_NAME="$(scutil --get ComputerName 2>/dev/null || hostname -s)-skilling-platform"
LABELS="self-hosted,macOS,skilling-platform"

if [ $# -ne 1 ] || [ -z "${1:-}" ]; then
  cat >&2 <<'EOF'
Missing registration token.

Get one from:
  https://github.com/manushivendra-shivanya/skilling-platform/settings/actions/runners/new
  -> choose "macOS", pick your Mac's architecture (Apple Silicon: ARM64,
     Intel: X64) -> GitHub shows a `./config.sh --url ... --token TOKEN`
     command -> copy just the --token value (starts with something like
     "A2X...", not the whole command).

It expires in about an hour, so generate it right before running this
script, not ahead of time.

Usage: ./scripts/ci/setup-mac-runner.sh <registration-token>
EOF
  exit 1
fi

TOKEN="$1"

echo "==> Checking prerequisites"

# Homebrew is the path of least resistance for `gh` -- the release-publish
# step in build-apk.yml shells out to it, and unlike GitHub-hosted runners
# a fresh Mac has no reason to already have it.
if ! command -v gh >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing gh (GitHub CLI) via Homebrew..."
    brew install gh
  else
    echo "::warning:: 'gh' not found and Homebrew isn't installed either." >&2
    echo "  Install Homebrew (https://brew.sh) then 'brew install gh', or" >&2
    echo "  install gh some other way -- the release-publish step in" >&2
    echo "  build-apk.yml needs it. The runner will still register and" >&2
    echo "  handle ordinary (non-publishing) builds without it." >&2
  fi
fi

# flutter build apk needs an Android SDK with its command-line tools and
# accepted licenses. This repo currently targets compileSdk/targetSdk 36
# with AGP 9.0.1 (apps/candidate-mobile/android/app/build.gradle.kts,
# settings.gradle.kts) -- both recent enough that Gradle's own SDK
# auto-download (sdk.dir pointed at a valid root with cmdline-tools present
# + licenses accepted) can pull down whichever exact build-tools/NDK
# version it wants at build time, so this doesn't hardcode those versions
# and doesn't need to be kept in sync with them by hand.
ANDROID_SDK_PATH="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$ANDROID_SDK_PATH" ] && [ -d "$HOME/Library/Android/sdk" ]; then
  ANDROID_SDK_PATH="$HOME/Library/Android/sdk"
  echo "Found an existing Android SDK at the default Android Studio location: $ANDROID_SDK_PATH"
fi

if [ -z "$ANDROID_SDK_PATH" ]; then
  if command -v brew >/dev/null 2>&1; then
    echo "No Android SDK found -- installing command-line tools via Homebrew (this pulls ~1-2 GB)..."
    brew install --cask android-commandlinetools
    # The cask installs into a Homebrew-prefix-relative path that differs
    # between Apple Silicon and Intel; ask Homebrew where it actually put
    # it instead of guessing.
    ANDROID_SDK_PATH="$(brew --prefix)/share/android-commandlinetools"
  else
    echo "::warning:: No Android SDK found and Homebrew isn't installed." >&2
    echo "  'flutter build apk' will fail on this runner until one exists." >&2
    echo "  Install Homebrew (https://brew.sh) and re-run this script, or" >&2
    echo "  install Android Studio / the command-line tools manually and" >&2
    echo "  export ANDROID_HOME before re-running." >&2
  fi
fi

if [ -n "$ANDROID_SDK_PATH" ]; then
  SDKMANAGER="$(find "$ANDROID_SDK_PATH/cmdline-tools" -name sdkmanager -type f 2>/dev/null | sort -r | head -1)"
  if [ -n "$SDKMANAGER" ]; then
    echo "Accepting Android SDK licenses (required for Gradle's own auto-download to work headlessly)..."
    yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
    # Best-effort pre-warm so the very first real build doesn't spend its
    # whole 30-minute timeout downloading the SDK -- not fatal if the exact
    # package names below have moved on by the time this runs; Gradle's
    # own auto-download at build time is the real safety net regardless.
    "$SDKMANAGER" --install "platform-tools" "platforms;android-36" >/dev/null 2>&1 || true
  else
    echo "::warning:: Found $ANDROID_SDK_PATH but no cmdline-tools/sdkmanager inside it." >&2
    echo "  Gradle's SDK auto-download needs those to accept licenses" >&2
    echo "  headlessly. Open Android Studio -> SDK Manager -> SDK Tools ->" >&2
    echo "  check 'Android SDK Command-line Tools', or re-run this script" >&2
    echo "  after installing Homebrew so it can fetch them for you." >&2
  fi
fi

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [ ! -f ./config.sh ]; then
  echo "==> Downloading the GitHub Actions runner"
  ARCH="$(uname -m)"
  case "$ARCH" in
    arm64) RUNNER_ARCH="osx-arm64" ;;
    x86_64) RUNNER_ARCH="osx-x64" ;;
    *) echo "Unrecognized architecture: $ARCH" >&2; exit 1 ;;
  esac

  # Ask GitHub's API for the current release tag instead of hardcoding a
  # version here, so this script doesn't quietly fall behind and start
  # registering an EOL runner months from now.
  LATEST_TAG="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | \
    grep -m1 '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')"
  if [ -z "$LATEST_TAG" ]; then
    echo "Could not determine the latest actions/runner release -- check" >&2
    echo "https://github.com/actions/runner/releases and download manually." >&2
    exit 1
  fi

  TARBALL="actions-runner-${RUNNER_ARCH}-${LATEST_TAG}.tar.gz"
  URL="https://github.com/actions/runner/releases/download/v${LATEST_TAG}/${TARBALL}"
  echo "Downloading $URL"
  curl -fsSL -o "$TARBALL" "$URL"
  tar xzf "$TARBALL"
  rm "$TARBALL"
else
  echo "==> Runner already downloaded at $RUNNER_DIR, skipping"
fi

echo "==> Registering with $REPO_URL as '$RUNNER_NAME' (labels: $LABELS)"
./config.sh \
  --url "$REPO_URL" \
  --token "$TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$LABELS" \
  --work "_work" \
  --unattended \
  --replace

# launchd services don't load your shell profile (.zshrc/.bash_profile),
# so an ANDROID_HOME exported there is invisible to the runner process --
# a real, easy-to-miss gap, not a hypothetical one. .env is the
# actions-runner's own supported mechanism for this and gets loaded on
# every job automatically once the service is (re)started, which is why
# this is written before ./svc.sh start below, not after.
if [ -n "$ANDROID_SDK_PATH" ]; then
  if ! grep -q '^ANDROID_HOME=' .env 2>/dev/null; then
    echo "ANDROID_HOME=$ANDROID_SDK_PATH" >> .env
  fi
  if ! grep -q '^ANDROID_SDK_ROOT=' .env 2>/dev/null; then
    echo "ANDROID_SDK_ROOT=$ANDROID_SDK_PATH" >> .env
  fi
  echo "Wrote ANDROID_HOME/ANDROID_SDK_ROOT=$ANDROID_SDK_PATH to $RUNNER_DIR/.env"
fi

echo "==> Installing as a launchd service (survives reboots and logouts)"
./svc.sh install
./svc.sh start

cat <<EOF

==> Done. Runner '$RUNNER_NAME' is registered and running as a background service.

Check it shows up (green dot, Idle) at:
  ${REPO_URL}/settings/actions/runners

Useful commands from $RUNNER_DIR:
  ./svc.sh status   # is it running
  ./svc.sh stop      # stop it
  ./svc.sh uninstall # remove the launchd service entirely (config.sh
                      # --url/--token registration stays; re-run ./svc.sh
                      # install to bring it back)

EOF
if [ -z "$ANDROID_SDK_PATH" ]; then
  cat <<EOF
No Android SDK was found or installed above (see the warning), so
'flutter build apk' will fail on this runner until one exists. Once you
have one, set it manually:
  echo "ANDROID_HOME=/path/to/sdk" >> $RUNNER_DIR/.env
  echo "ANDROID_SDK_ROOT=/path/to/sdk" >> $RUNNER_DIR/.env
  cd $RUNNER_DIR && ./svc.sh stop && ./svc.sh start

EOF
fi
cat <<EOF
Once the Actions minutes quota resets on 2026-09-01 (or whenever
GitHub-hosted builds are affordable again), either leave the runner
running (it costs nothing extra to keep registered) or:
  ./svc.sh uninstall && ./config.sh remove --token <a-new-removal-token>
and revert .github/workflows/build-apk.yml's runs-on back to
'ubuntu-latest' (the original value is left in a comment there).
EOF
