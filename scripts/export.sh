#!/bin/bash
set -euo pipefail

# Export qui automations from API to individual JSON files.
# Usage: ./scripts/export.sh [QUI_URL] [API_KEY]
#
# Configuration via environment variables or arguments:
#   QUI_URL:          base URL of your qui instance (default: http://localhost:7474)
#   QUI_API_KEY:      API key for authentication
#   QUI_INSTANCE_ID:  qui instance ID (default: 1)
#
# Requires: curl, python3 (json module)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_DIR

readonly QUI_URL="${1:-${QUI_URL:-http://localhost:7474}}"

if [[ -n "${2:-}" ]]; then
  readonly API_KEY="$2"
elif [[ -n "${QUI_API_KEY:-}" ]]; then
  readonly API_KEY="$QUI_API_KEY"
else
  printf "QUI API key (QUI_API_KEY or pass as arg 2): " >&2
  read -r API_KEY
  readonly API_KEY
fi

# Verify dependencies
command -v curl >/dev/null 2>&1 || {
  printf "curl required\n" >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  printf "python3 required\n" >&2
  exit 1
}

readonly QUI_INSTANCE_ID="${QUI_INSTANCE_ID:-1}"
readonly API_ENDPOINT="${QUI_URL}/api/instances/${QUI_INSTANCE_ID}/automations"

printf "Fetching automations from %s...\n" "$API_ENDPOINT"

response=$(curl -sf -H "X-API-Key: ${API_KEY}" "$API_ENDPOINT") || {
  printf "Failed to fetch from %s\n" "$API_ENDPOINT" >&2
  exit 1
}

# Process and export automations (pass JSON via stdin to avoid shell expansion)
printf '%s' "$response" | python3 -c "
import json, os, sys

automations = json.load(sys.stdin)

# Map automation ID to (category, filename)
# Update this map when adding new automations
FILE_MAP = {
    16: ('tagging', 'Tag - tracker name.json'),
    2:  ('tagging', 'Tag - noHL.json'),
    17: ('tagging', 'Tag - stalledDL.json'),
    18: ('tagging', 'Tag - tracker issue.json'),
    1:  ('maintenance', 'Resume Incomplete.json'),
    21: ('maintenance', 'Resume - min seed failsafe.json'),
    19: ('maintenance', 'Delete - unregistered.json'),
    20: ('maintenance', 'Recheck - missing files.json'),
    24: ('limits', 'HL-remove-limits.json'),
    6:  ('limits', 'noHL-movies-limits.json'),
    7:  ('limits', 'noHL-tv-limits.json'),
    8:  ('limits', 'TL-limits.json'),
    9:  ('limits', 'TLnoHL-limits.json'),
    10: ('limits', 'noHL-catchall-limits.json'),
    22: ('limits', 'noHL-xseed-limits.json'),
    11: ('cleanup', 'noHL-movies-cleanup.json'),
    12: ('cleanup', 'noHL-tv-cleanup.json'),
    13: ('cleanup', 'TL-cleanup.json'),
    14: ('cleanup', 'TLnoHL-cleanup.json'),
    15: ('cleanup', 'noHL-catchall-cleanup.json'),
    23: ('cleanup', 'noHL-xseed-cleanup.json'),
}

STRIP_FIELDS = {'instanceId', 'createdAt', 'updatedAt'}
base_dir = '${REPO_DIR}'
exported = 0
unmapped = []

for auto in automations:
    aid = auto['id']
    if aid not in FILE_MAP:
        unmapped.append(f'  ID={aid} name={auto[\"name\"]}')
        continue

    category, filename = FILE_MAP[aid]
    dirpath = os.path.join(base_dir, category)
    os.makedirs(dirpath, exist_ok=True)

    cleaned = {k: v for k, v in auto.items() if k not in STRIP_FIELDS}

    filepath = os.path.join(dirpath, filename)
    with open(filepath, 'w') as f:
        json.dump(cleaned, f, indent=2)
        f.write('\n')

    exported += 1
    print(f'  {category}/{filename} (ID={aid}, sort={auto[\"sortOrder\"]})')

print(f'\nExported {exported}/{len(automations)} automations')

if unmapped:
    print(f'\nUnmapped automations (add to FILE_MAP):')
    for u in unmapped:
        print(u)
    sys.exit(1)
"

printf "\nDone. Review changes with: git diff\n"
