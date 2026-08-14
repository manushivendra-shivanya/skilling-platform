---
description: Build the latest candidate-mobile APK on the Mac runner and install it straight to the phone over local Wi-Fi (adb, no download).
---

Use this when the user's Mac and phone are on the **same Wi-Fi network**. No GitHub Release, no download — the APK is built and installed straight from the runner's own disk.

1. **Sync `main`.** `git fetch origin main && git checkout main && git merge --ff-only origin/main`. If there's uncommitted or unmerged work in flight, finish and merge it first (or ask whether to include it) — don't silently leave it out of the build.

2. **Trigger the build**, `workflow_dispatch` on `build-apk.yml`, ref `main`. Leave `release_tag` **blank** — this flow never touches GitHub Releases, so there's nothing to publish.
   ```
   mcp__github__actions_run_trigger run_workflow build-apk.yml on main, no inputs
   ```

3. **Confirm the self-hosted Mac runner actually picked it up** (check the run's `labels`/`runner_name` via `actions_list list_workflow_jobs`) — if it's queued on a different runner or stuck, say so rather than silently waiting.

4. **Poll until the run completes** (`actions_list list_workflow_jobs`, checking `status`/`conclusion`). Don't guess or fabricate progress — check for real, and report if it fails (pull the failing step's log via `actions_get get_job_logs` and diagnose before handing back to the user).

5. **On success, hand the user exactly one command** — the local install, using the runner's own checkout path (repo checked out twice-nested under `_work` is standard GitHub Actions runner layout):
   ```bash
   adb install -r "$HOME/actions-runners/skilling-platform/_work/skilling-platform/skilling-platform/apps/candidate-mobile/build/app/outputs/flutter-apk/app-debug.apk"
   ```
   If `adb devices` shows nothing, the one extra step is reconnecting wireless debugging (`adb connect <phone-ip>:<port>` from the phone's Developer Options → Wireless debugging screen) — mention it only if they report the install command failing, don't front-load it every time.

6. **Tell them what changed** — a one-line summary of what's in this build (pull it from the commits merged since the last build/tag, not from memory), so they know what to actually go test.

Don't ask permission between these steps once invoked — that's the point of the command. Only stop to report a real failure (build red, runner offline, merge conflict) or to ask something genuinely undecidable (e.g. uncommitted work in an ambiguous state).
