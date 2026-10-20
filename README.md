# qui_workflows

[![JSON Lint](https://github.com/baker-scripts/qui_workflows/actions/workflows/json-lint.yml/badge.svg)](https://github.com/baker-scripts/qui_workflows/actions/workflows/json-lint.yml)

21 [qui](https://github.com/autobrr/qui) automations for qBittorrent: tagging, maintenance, share limits, and cleanup. Built for a hardlink-aware setup with cross-seed support. The JSON files in `qbit/` are published by [qui-sync](https://github.com/ProphetSe7en/qui-sync).

These automations delete torrents and files. Read the conditions before you import them.

## Quick Start

Requirements:

- A [qui](https://github.com/autobrr/qui) instance.
- qBittorrent with hardlink detection (save path and hardlink target on the same filesystem).

Import with qui-sync's Sync feature, which loads someone else's automations repo into your qui instance. See the qui-sync [How-To Guide](https://github.com/ProphetSe7en/qui-sync/blob/main/docs/how-to.md#sync).

The `id` and instance fields of your own instance are not stored in these files. Each file carries `name`, `sortOrder`, `intervalSeconds` (where set), tracker scope, and `conditions`.

## Configuration

There is no configuration file. Behavior is set in each JSON file under `qbit/`.

| Field | Meaning |
|-------|---------|
| `sortOrder` | Execution order. Later matching automations win on conflicting share limits. |
| `intervalSeconds` | Run interval. Omitted means qui's default. |
| `conditions.schemaVersion` | Always `"1"`. |
| `conditions.<action>.condition` | Match tree for `tag`, `resume`, `shareLimits`, `speedLimits`, or `delete`. |

Condition fields use seconds (`SEEDING_TIME`, `ADDED_ON_AGE`, `COMPLETION_ON`). `shareLimits.seedingTimeMinutes` uses minutes. Mixing them up gives very wrong behavior.

| Seconds | Human | Minutes | Human |
|---------|-------|---------|-------|
| 900 | 15 minutes | 21600 | 15 days |
| 1800 | 30 minutes | 30240 | 21 days |
| 5400 | 90 minutes | 43200 | 30 days |
| 21600 | 6 hours | 50400 | 35 days |
| 1296000 | 15 days | 525600 | 365 days |
| 1814400 | 21 days | | |
| 2592000 | 30 days | | |
| 3024000 | 35 days | | |
| 31536000 | 365 days | | |

## Usage

### Automations

Files in `qbit/` match the automation names. Limits and cleanup are interleaved by sort order (limits at even positions, cleanup at odd), so each cleanup rule runs right after its limits rule. All limits and cleanup automations run every hour except HL-remove-limits, which uses qui's default interval.

Tagging and maintenance:

| Sort | Name | Interval | Action |
|------|------|----------|--------|
| 1 | Tag: tracker name | 30 min | Tag with the tracker display name |
| 2 | Resume Incomplete | 6 h | Resume stopped torrents with progress below 100% |
| 3 | Resume: min seed failsafe | 30 min | Resume torrents that are not downloading, active, uploading, or stalled uploading and have seeded under 15 days |
| 4 | noHL | 6 h | Tag `noHL` when there is no hardlink outside qBittorrent, the tracker is not MyAnonamouse, the torrent completed 90+ minutes ago, and it is not a cross-seed |
| 5 | Tag: stalledDL | 30 min | Tag `stalledDL` for stalled downloads |
| 6 | Tag: tracker issue | 30 min | Tag `issue` for errored, tracker-down, or missing-files states |
| 7 | Delete: unregistered | 15 min | Delete unregistered torrents when added 90+ minutes ago and the tracker is not down |
| 8 | Recheck: missing files | 1 h | Built-in qui recheck action. Empty conditions are intentional. |

Limits:

| Sort | Name | Ratio | Seed time | Upload cap |
|------|------|-------|-----------|------------|
| 9 | HL-remove-limits | unlimited | unlimited | none |
| 10 | noHL-movies-limits | unlimited | 30 days | none |
| 12 | noHL-tv-limits | unlimited | 21 days | none |
| 14 | TL-limits | unlimited | 365 days | 25390 KiB/s |
| 16 | TLnoHL-limits | unlimited | 30 days | 25390 KiB/s |
| 18 | noHL-catchall-limits | unlimited | 35 days | none |
| 20 | noHL-xseed-limits | unlimited | 15 days | none |

Cleanup. Each rule has a seed-time guard, then a delete trigger:

| Sort | Name | Guard | Delete trigger |
|------|------|-------|----------------|
| 11 | noHL-movies-cleanup | seed >= 15d | ratio >= 33 or seed >= 30d |
| 13 | noHL-tv-cleanup | seed >= 15d | ratio >= 3 or seed >= 21d |
| 15 | TL-cleanup | none | seed >= 365d |
| 17 | TLnoHL-cleanup | seed >= 15d | ratio >= 1.25 or seed >= 30d |
| 19 | noHL-catchall-cleanup | seed >= 15d | ratio >= 15 or seed >= 35d |
| 21 | noHL-xseed-cleanup | none | seed >= 15d |

### Execution model

- Matching automations fire in `sortOrder`. For conflicting share limits, the last match wins. Limits therefore run from most specific to least specific: HL, then movies, TV, and TL, then catchall.
- A delete action cannot combine with other actions, so each delete rule is its own automation. Share limits and speed limits can share one automation.
- Routing uses `HARDLINK_SCOPE` directly, not the `noHL` tag, so it applies without waiting for the 90-minute tagging grace period.
- The `tag` and `tags` fields in tagging automations hold identical conditions. qui requires both.
- Cleanup guards should be at or below the failsafe threshold (15 days). Otherwise torrents can sit in the gap between the guard and the failsafe.

| Condition | Group |
|-----------|-------|
| `HARDLINK_SCOPE = outside_qbittorrent`, not TL, not cross-seed | HL (remove limits) |
| `CATEGORY CONTAINS movie`, not hardlinked, not TL, not cross-seed | Movies |
| `CATEGORY CONTAINS tv`, not hardlinked, not TL, not cross-seed | TV |
| `TAGS CONTAINS TorrentLeech`, hardlinked, not cross-seed | TL |
| `TAGS CONTAINS TorrentLeech`, not hardlinked, not cross-seed | TLnoHL |
| `CATEGORY CONTAINS cross`, not hardlinked | Cross-seed |
| Not hardlinked, not MAM, not TL, not movie, not tv, not cross | Catchall |

Special cases:

- MyAnonamouse (MAM) is excluded from noHL tagging and from the catchall rules.
- TorrentLeech (TL) has separate hardlinked and non-hardlinked rules and an upload cap of 25390 KiB/s.
- Cross-seeds have dedicated rules: seed 15 days, then delete. Hardlinked cross-seeds match none of the rules.
- Every delete uses `deleteWithFilesPreserveCrossSeeds`, which keeps files that a cross-seed still references.

### Updating this repo

A running qui-sync instance publishes this repo. Open qui-sync's Export tab, review the diff, click Commit export, then Push to remote. See the [How-To Guide](https://github.com/ProphetSe7en/qui-sync/blob/main/docs/how-to.md#export).

## Differences from TRaSH workflows

[TRaSH's workflows](https://github.com/TRaSH-/qui_workflows) route by tracker tier. This repo routes by category and tracker tag. It has no tier system, no upload throttling for non-TL trackers, no stalled-download cleanup, and no problem cross-seed detection.

## Related

- [baker-scripts/StarrScripts](https://github.com/baker-scripts/StarrScripts) includes `qui-xseed.sh` for cross-seed automation.
- [TRaSH-/qui_workflows](https://github.com/TRaSH-/qui_workflows) is the tier-based reference.

## Contributing

Issues and pull requests welcome. See the [contributing guidelines](https://github.com/baker-scripts/.github/blob/main/CONTRIBUTING.md), or [open an issue](https://github.com/baker-scripts/qui_workflows/issues) to discuss larger changes.

## Disclaimer

Provided as-is with no warranty. These automations delete torrents and files based on their conditions. Review the JSON before importing. The authors are not responsible for data loss.

## License

[MIT](LICENSE)
