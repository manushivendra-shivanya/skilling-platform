# Cloudflare micro-lesson video hosting

This folder contains the upload manifest for warehouse micro-lesson MP4 assets.

## Target shape

- Recommended bucket: `flora-micro-lessons`
- Object key prefix: `micro-lessons/warehouse/v1/`
- Public app configuration: `MICRO_LESSON_CDN_BASE_URL`
- Manifest: `ops/cloudflare/micro_lessons_upload_manifest.json`

The Flutter catalogue keeps local `asset://` URLs as development fallback. When
`MICRO_LESSON_CDN_BASE_URL` is supplied at build time, the app resolves each
clip to:

```text
<MICRO_LESSON_CDN_BASE_URL>/<cloudflareVideoPath>
```

## Upload using Wrangler / R2

After creating the bucket and public domain in Cloudflare, upload each object
from the manifest with the listed `cloudflareObjectKey`.

Example:

```bash
wrangler r2 object put \
  flora-micro-lessons/micro-lessons/warehouse/v1/inward/01-clip_receiving_supplier_001/receiving_wrong_supplier_stop_v2.mp4 \
  --file apps/candidate-mobile/assets/micro_lessons/videos/receiving_wrong_supplier_stop_v2.mp4 \
  --content-type video/mp4 \
  --cache-control "public, max-age=31536000, immutable"
```

Build the candidate app with the public CDN base URL:

```bash
flutter build apk --debug \
  --dart-define=MICRO_LESSON_CDN_BASE_URL=https://cdn.example.com
```

Do not commit Cloudflare API tokens or account identifiers here.

## Upload using GitHub Actions

Cloudflare GitHub access lets Cloudflare read/deploy the repository, but R2
object upload still needs GitHub Actions credentials.

Add these repository secrets:

```text
CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_API_TOKEN
```

The API token should be scoped narrowly for R2 object writes on the target
account/bucket.

Then run the manual GitHub workflow:

```text
Upload Micro Lessons to Cloudflare R2
```

Use the bucket input:

```text
flora-micro-lessons
```

## Build APK against Cloudflare CDN

Add this GitHub repository variable after the bucket has a public URL or custom
domain:

```text
MICRO_LESSON_CDN_BASE_URL=https://your-public-r2-or-cdn-domain
```

The existing `Build Candidate Mobile APK` workflow passes this public value as a
Dart define. If the variable is absent, the app keeps using bundled local asset
URLs.
