# qui_workflows

QUI automation workflows for qBittorrent torrent lifecycle management.

## Structure
- `qbit/` — all 21 automations (tagging, maintenance, limits, cleanup), published by qui-sync

## Rules
- JSON files are qui automation exports (strip `instanceId`, `createdAt`, `updatedAt`)
- Filenames match automation names
- Sort order in filenames reflects execution order
- No PII — tracker names (myanonamouse, TorrentLeech) are public well-known names
- Conventional commits

## Live Instance

- Container: `qui.internal` (ghcr.io/hotio/qui) on hetzner, port 7476
- Auth: OIDC-only (`QUI__OIDC_DISABLE_BUILT_IN_LOGIN=true`) — no built-in username/password login; API keys are still generated via the UI (see below)
- Published by a running [qui-sync](https://github.com/ProphetSe7en/qui-sync) instance (`qui-sync.internal` on hetzner, 127.0.0.1:6070 only, no public vhost) — not a manual script. `scripts/export.sh` is retired (removed 2026-07-17).
- Predecessor repo `bakerboy448/qui-automations` is archived; this repo is canonical

## Known Live Drift (as of 2026-06-21)

Live instance predates some repo improvements. Two automations differ:

1. **HL-remove-limits** — live has `intervalSeconds: null` (explicit null); repo omits the field (equivalent — both mean "use qui default interval"). No action needed.
2. **Recheck: missing files** — live has an old-style explicit `forceRecheck` condition (`STATE = missingFiles`); repo has intentionally empty conditions (the correct newer form per qui's built-in recheck action). Live instance should be updated to match repo when convenient.
