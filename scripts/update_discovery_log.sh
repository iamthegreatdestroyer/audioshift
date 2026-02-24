#!/usr/bin/env bash
##
# update_discovery_log.sh — AudioShift Track 4 §4.2
#
# Appends a dated weekly section to DISCOVERY_LOG.md if one does not
# already exist for the current ISO week. Safe to run multiple times
# in the same week (idempotent).
#
# Usage:
#   ./scripts/update_discovery_log.sh           # appends current week
#   ./scripts/update_discovery_log.sh 2024-W42  # override week label
#
# Called automatically by the CI "weekly discovery" job, or manually
# before starting a new research session.
##

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${REPO_ROOT}/DISCOVERY_LOG.md"

# Allow optional override: ./update_discovery_log.sh 2024-W42
if [[ $# -ge 1 ]]; then
  WEEK="$1"
else
  WEEK=$(date +%Y-W%V)
fi

SECTION="## Week: ${WEEK}"

# ── Guard: already has an entry for this week? ─────────────────────────────
if grep -qF "${SECTION}" "${LOG_FILE}"; then
  echo "Discovery log already has an entry for ${WEEK} — nothing added."
  exit 0
fi

# ── Append the weekly template ──────────────────────────────────────────────
cat >> "${LOG_FILE}" << EOF


${SECTION}

### What I Discovered
-

### What Surprised Me
-

### Decisions Made
-

### Questions Generated
-

EOF

echo "Discovery log entry created for ${WEEK} in ${LOG_FILE}"
