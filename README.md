# qui_workflows

Automation workflows for [qui](https://github.com/TRaSH-Guides/qui) — a qBittorrent automation manager. These workflows manage the complete torrent lifecycle: tagging, maintenance, share limits, and cleanup.

21 automations organized by function, designed for a hardlink-aware setup with cross-seed support.

## Requirements

- [qui](https://github.com/TRaSH-Guides/qui) instance with API access
- qBittorrent with hardlink detection enabled
- `curl` and `python3` (for the export script)

## Quick Start

### Import

Import individual JSON files through the qui web UI, or use the API:

```bash
curl -X POST http://your-qui:7474/api/instances/1/automations \
  -H "X-API-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d @tagging/Tag\ -\ tracker\ name.json
```

### Export (update from live instance)

```bash
# Set your qui URL and API key
export QUI_URL="http://your-qui:7474"
export QUI_API_KEY="your-api-key"

# Run the export script
./scripts/export.sh
```

The export script fetches all automations from the API, strips instance-specific fields (`instanceId`, `createdAt`, `updatedAt`), and writes individual JSON files to the categorized directories.

## Structure

```
qui_workflows/
├── tagging/           # Tracker name, noHL, stalledDL, tracker issue
├── maintenance/       # Resume, delete unregistered, recheck missing
├── limits/            # Share limits and speed limits by category
├── cleanup/           # Delete rules by category with guards
├── scripts/
│   └── export.sh      # Export automations from live instance
└── README.md
```

## Automations

### Tagging (sort 1-6)

| Sort | Name | Interval | Action |
|------|------|----------|--------|
| 1 | Tag: tracker name | 30min | Auto-tag with tracker display name |
| 4 | Tag: noHL | 6h | Tag `noHL` when no external hardlinks (excludes MAM, cross-seeds) |
| 5 | Tag: stalledDL | 30min | Tag `stalledDL` for stalled downloads |
| 6 | Tag: tracker issue | 30min | Tag `issue` for errored/down/missing files |

### Maintenance (sort 2-8)

| Sort | Name | Interval | Action |
|------|------|----------|--------|
| 2 | Resume Incomplete | 6h | Resume stopped torrents that aren't complete |
| 3 | Resume: min seed failsafe | 30min | Resume stoppedUP torrents seeding < 15 days |
| 7 | Delete: unregistered | 15min | Delete unregistered torrents (90min age guard) |
| 8 | Recheck: missing files | default | Force recheck on missing files |

### Limits (sort 9-20)

| Sort | Name | Ratio | Seed Time | Upload Cap |
|------|------|-------|-----------|------------|
| 9 | HL-remove-limits | unlimited | unlimited | — |
| 10 | noHL-movies-limits | 33 | 15 days | — |
| 12 | noHL-tv-limits | unlimited | 21 days | — |
| 14 | TL-limits | unlimited | 365 days | 25 MB/s |
| 16 | TLnoHL-limits | unlimited | 15 days | 25 MB/s |
| 18 | noHL-catchall-limits | 15 | 35 days | — |
| 20 | noHL-xseed-limits | unlimited | 15 days | — |

### Cleanup (sort 11-21)

| Sort | Name | Guard | Delete Trigger |
|------|------|-------|----------------|
| 11 | noHL-movies-cleanup | seed >= 15d | ratio >= 33 OR seed >= 15d |
| 13 | noHL-tv-cleanup | seed >= 15d | ratio >= 3 OR seed >= 21d |
| 15 | TL-cleanup | — | seed >= 365d |
| 17 | TLnoHL-cleanup | seed >= 15d | ratio >= 1.25 OR seed >= 12d |
| 19 | noHL-catchall-cleanup | seed >= 15d | ratio >= 15 OR seed >= 35d |
| 21 | noHL-xseed-cleanup | — | seed >= 15d |

## Execution Model

### Sort Order & Last-One-Wins

All matching automations fire in `sortOrder` sequence. For conflicting share limits, **the last matching automation wins** — earlier limits get overwritten by later ones.

This is why limits are ordered from most specific to least specific:
1. HL-remove-limits (hardlinked → unlimited)
2. Category-specific limits (movies, TV, TL)
3. Catchall (everything else)

### Delete Isolation

Delete automations **cannot combine** with other actions. Each delete rule is a separate automation. Share limits + speed limits **can** combine in a single automation.

### Category Routing

Torrents are routed to rule groups based on conditions:

| Condition | Group |
|-----------|-------|
| Hardlinked + not TL + not cross-seed | HL (remove limits, seed forever) |
| `CATEGORY CONTAINS movie` + noHL | Movies |
| `CATEGORY CONTAINS tv` + noHL | TV |
| `TAGS CONTAINS TorrentLeech` + hardlinked | TL |
| `TAGS CONTAINS TorrentLeech` + noHL | TLnoHL |
| `CATEGORY CONTAINS cross` + noHL | Cross-seed |
| Everything else (noHL, not MAM/TL) | Catchall |

### Special Handling

- **MyAnonamouse (MAM)**: Excluded from noHL tagging and catchall — seeds forever
- **TorrentLeech (TL)**: Speed-limited to 25 MB/s upload, separate HL/noHL rules
- **Cross-seeds**: Dedicated rules — seed 15 days then delete. Cross-seeds with hardlinks are naturally exempt (treated as hardlinked)
- **All deletes**: Use `deleteWithFilesPreserveCrossSeeds` mode (except unregistered which uses `deleteWithFiles`)

### Resume Failsafe

The "Resume: min seed failsafe" (sort 3) catches torrents that get paused prematurely. It resumes any stoppedUP torrent that has been seeding less than 15 days.

**Important**: Cleanup guards should be <= the failsafe threshold to prevent stuck torrents in the gap between guard and failsafe.

## Time Reference

| Value | Human |
|-------|-------|
| 900 | 15 minutes |
| 1800 | 30 minutes |
| 5400 | 90 minutes |
| 21600 | 6 hours |
| 86400 | 1 day |
| 1036800 | 12 days |
| 1296000 | 15 days |
| 1814400 | 21 days |
| 3024000 | 35 days |
| 31536000 | 365 days |

Note: `shareLimits.seedingTimeMinutes` uses **minutes**, while condition `SEEDING_TIME` values are in **seconds**.

## Known Differences from TRaSH Workflows

This setup uses **category-based routing** (movies/tv/TL/catchall) while [TRaSH's workflows](https://github.com/TRaSH-Guides/qui_workflows) use **tracker-tier-based routing** (Tier 1/2/3). Neither approach is wrong — they reflect different philosophies.

Key differences:
- **No tier system**: We route by category + tracker tag rather than tracker tier
- **No upload speed throttling for non-TL**: TRaSH throttles Tier 2 (2 MB/s) and Tier 3 (1 MB/s) after ratio > 2.0. We only throttle TL at 25 MB/s
- **No stalled download cleanup**: TRaSH deletes stalled downloads < 9.5% progress after 4h
- **No problem cross-seed detection**: TRaSH tags and deletes cross-seeds that are stalled/missing after 24h

## Improvement Candidates

Issues identified during review (documented, not yet applied):

1. **noHL-movies-cleanup redundant OR**: Guard `seed >= 15d` + trigger `ratio >= 33 OR seed >= 15d` — the seed branch is always true when the guard passes, making ratio irrelevant. Every noHL movie deletes at exactly 15d.

2. **TLnoHL-cleanup guard/trigger mismatch**: Guard is `seed >= 15d` but OR fallback is `seed >= 12d`. The 12d branch can never fire because the 15d guard blocks it. Guard should be `seed >= 12d` to match.

3. Consider adding stalled download cleanup and problem cross-seed detection per TRaSH patterns.

## Related

- [baker-scripts/StarrScripts](https://github.com/baker-scripts/StarrScripts) — includes `qui-xseed.sh` for cross-seed automation
- [TRaSH-Guides/qui_workflows](https://github.com/TRaSH-Guides/qui_workflows) — TRaSH's tier-based reference implementation

## License

[MIT](LICENSE)
