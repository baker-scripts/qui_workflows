# qui_workflows

QUI automation workflows for qBittorrent torrent lifecycle management.

## Structure
- `tagging/` — tracker name, noHL, stalledDL, tracker issue tagging
- `maintenance/` — resume, delete unregistered, recheck missing
- `limits/` — share limits and speed limits by category
- `cleanup/` — delete rules by category with guards

## Rules
- JSON files are qui automation exports (strip `instanceId`, `createdAt`, `updatedAt`)
- Filenames match automation names
- Sort order in filenames reflects execution order
- No PII — tracker names (myanonamouse, TorrentLeech) are public well-known names
- Conventional commits

## Live Instance

- Container: `qui.internal` (ghcr.io/hotio/qui) on hetzner, port 7476
- Auth: OIDC-only (`QUI__OIDC_DISABLE_BUILT_IN_LOGIN=true`) — no built-in username/password login; API keys are still generated via the UI (see below)
- Export script (`scripts/export.sh`) requires `QUI_API_KEY`; generate one via qui Settings → API Keys
- FILE_MAP IDs in export.sh match the live instance (verified 2026-06-21)
- Predecessor repo `bakerboy448/qui-automations` is archived; this repo is canonical

## Known Live Drift (as of 2026-06-21)

Live instance predates some repo improvements. Two automations differ:

1. **HL-remove-limits** — live has `intervalSeconds: null` (explicit null); repo omits the field (equivalent — both mean "use qui default interval"). No action needed.
2. **Recheck: missing files** — live has an old-style explicit `forceRecheck` condition (`STATE = missingFiles`); repo has intentionally empty conditions (the correct newer form per qui's built-in recheck action). Live instance should be updated to match repo when convenient.
