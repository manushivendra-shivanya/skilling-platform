# Push This Documentation Package with Codex

Target repository:
`https://github.com/manushivendra-shivanya/skilling-platform`

## Recommended commands
```bash
git clone https://github.com/manushivendra-shivanya/skilling-platform.git
cd skilling-platform
# Copy all files from this package into the repository root.
git add README.md docs .github CODEX_PUSH_INSTRUCTIONS.md
git commit -m "docs: establish complete product and engineering blueprint"
git push origin main
```

If branch protection is enabled:
```bash
git checkout -b agent/product-blueprint
git add README.md docs .github CODEX_PUSH_INSTRUCTIONS.md
git commit -m "docs: establish complete product and engineering blueprint"
git push -u origin agent/product-blueprint
# Open a pull request into main.
```

## Codex command
```text
Read README.md and all documents under docs. Confirm there are no contradictions, broken relative links, or missing headings. Do not change product scope. Commit the documentation as "docs: establish complete product and engineering blueprint" and push it to the skilling-platform repository. If direct push to main is blocked, create agent/product-blueprint and open a draft pull request.
```
