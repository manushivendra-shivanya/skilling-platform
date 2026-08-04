const { readFileSync } = require('node:fs');
const { spawnSync } = require('node:child_process');

const manifestPath =
  process.argv[2] || 'ops/cloudflare/micro_lessons_upload_manifest.json';
const bucketName =
  process.env.CLOUDFLARE_R2_BUCKET || process.argv[3] || 'flora-micro-lessons';

const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));

for (const item of manifest.items) {
  const destination = `${bucketName}/${item.cloudflareObjectKey}`;
  const args = [
    'wrangler@latest',
    'r2',
    'object',
    'put',
    destination,
    '--file',
    item.localAssetPath,
    '--content-type',
    item.contentType,
    '--cache-control',
    item.cacheControl,
  ];

  console.log(`Uploading ${item.clipId} -> ${destination}`);
  const result = spawnSync('npx', args, {
    stdio: 'inherit',
    env: process.env,
  });

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

console.log(`Uploaded ${manifest.items.length} micro-lesson clips to ${bucketName}.`);
