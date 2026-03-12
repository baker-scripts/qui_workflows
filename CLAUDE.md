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
