---
description: Build the latest candidate-mobile APK on the Mac runner and publish it as a downloadable GitHub Release, for when you're away from home Wi-Fi.
---

Use this when the user is **away from the Mac's Wi-Fi** — on mobile data or a different network, so direct `adb install` from the Mac can't reach the phone. This flow publishes a real, downloadable link instead: the one thing that works from anywhere, since it doesn't depend on adb reaching the phone at all.

1. **Sync `main`.** Same as `/seekh`: `git fetch origin main && git checkout main && git merge --ff-only origin/main`. Surface any uncommitted/unmerged work rather than silently dropping it from the build.

2. **Pick a release tag.** Look at the most recent `vX.Y.Z-*` tag (`mcp__github__list_tags`) and bump it sensibly — patch bump for a small fix batch, minor bump for a real feature batch — with a short slug describing what's in it (matches this repo's existing tag convention, e.g. `v0.9.0-shift-localization`). Don't reuse an existing tag.

3. **Trigger the build with that tag**, `workflow_dispatch` on `build-apk.yml`, ref `main`:
   ```
   mcp__github__actions_run_trigger run_workflow build-apk.yml on main,
     inputs: { release_tag: "<the tag>", release_name: "<short human title>" }
   ```

4. **Poll until the run completes AND the release-publish step succeeds** (`actions_list list_workflow_jobs` — the "Publish APK as a release asset" step specifically, not just the overall job). If the build itself passes but publishing fails, that's still a failure to report, not a silent partial success.

5. **On success, hand the user the direct download + the exact install steps** for their situation:
   - **Download URL:** `https://github.com/manushivendra-shivanya/skilling-platform/releases/download/<tag>/flora-candidate-app-<tag>.apk`
   - **On the phone itself** (no Mac at all reachable): open that link in the phone's browser, download it, tap the downloaded file, allow "install unknown apps" for the browser if prompted, install.
   - **If the Mac becomes reachable later** (back on home Wi-Fi, or via the Tailscale/SSH setup): the usual `curl` + `adb install` pair works too — give it as a fallback, not the headline, since the point of this command is not needing that.

6. **Tell them what changed** — same one-line summary of what's actually in this build as `/seekh`, pulled from the real commit range.

Same rule as `/seekh`: don't pause for permission between these steps, only for a real failure or a genuinely undecidable state. The difference between the two commands is entirely the distribution mechanism (local adb vs. a published Release) — everything else about how a build gets triggered and verified is identical.
