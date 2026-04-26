#!/usr/bin/env bash
# Filter BibTeX by verification status
# Usage: bash filter_verified.sh <references.bib> <verification_report.json> [output.bib|-]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./init.sh
source "$SCRIPT_DIR/init.sh"

BIB_FILE="${1:-}"
VERIFY_FILE="${2:-}"
OUTPUT_FILE="${3:--}"

if [ -z "$BIB_FILE" ] || { [ "$BIB_FILE" != "-" ] && [ ! -f "$BIB_FILE" ]; } || [ -z "$VERIFY_FILE" ] || { [ "$VERIFY_FILE" != "-" ] && [ ! -f "$VERIFY_FILE" ]; }; then
    echo "Usage: filter_verified.sh <references.bib|-> <verification_report.json|-> [output.bib|-]" >&2
    echo "" >&2
    echo "Filters BibTeX to keep only VERIFIED and optionally SUSPICIOUS entries." >&2
    echo "Removes HALLUCINATED entries." >&2
    exit 1
fi

if [[ -z "${PYTHON_BIN:-}" ]]; then
    echo "Error: python3/python not found in PATH" >&2
    exit 1
fi

# Create temp directory for Python script
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Write Python script to temp file
cat > "$TMP_DIR/filter.py" << 'FILTER'
import json
import re
import sys
import os

# 处理可能来自标准输入的 json 数据
vf = os.environ.get('VERIFY_FILE', '')
if vf == '-':
    verify_data = json.load(sys.stdin)
else:
    with open(vf, encoding='utf-8') as f:
        verify_data = json.load(f)

results = verify_data.get('results', [])

# Build sets of keys to keep
verified_keys = set()
suspicious_keys = set()
hallucinated_keys = set()

for r in results:
    key = r.get('cite_key', '')
    status = r.get('status', '')
    if status == 'VERIFIED':
        verified_keys.add(key)
    elif status == 'SUSPICIOUS':
        suspicious_keys.add(key)
    elif status == 'HALLUCINATED':
        hallucinated_keys.add(key)

include_suspicious = os.environ.get('INCLUDE_SUSPICIOUS', 'true').lower() == 'true'

# Keys to keep
keep_keys = verified_keys.copy()
if include_suspicious:
    keep_keys.update(suspicious_keys)

print(f"[filter] Total entries: {len(results)}", file=sys.stderr)
print(f"[filter] VERIFIED: {len(verified_keys)}", file=sys.stderr)
print(f"[filter] SUSPICIOUS: {len(suspicious_keys)} (included={include_suspicious})", file=sys.stderr)
print(f"[filter] HALLUCINATED (removed): {len(hallucinated_keys)}", file=sys.stderr)
print(f"[filter] Keeping: {len(keep_keys)} entries", file=sys.stderr)

bf = os.environ['BIB_FILE']
try:
    if bf == '-':
        bib_text = sys.stdin.read()
    else:
        with open(bf, encoding='utf-8') as f:
            bib_text = f.read()
except Exception as e:
    print(f"[filter] Error reading bib file: {e}", file=sys.stderr)
    sys.exit(1)

# Parse entries
entry_re = re.compile(r'@(\w+)\s*\{\s*([^,\s]+)\s*,', re.IGNORECASE)

# Find all entry positions
entries = []
for m in entry_re.finditer(bib_text):
    entries.append((m.start(), m.group(2).strip()))

# Add end position
entries.append((len(bib_text), None))

# Extract and filter entries
kept = []
removed = []

for i in range(len(entries) - 1):
    start_pos = entries[i][0]
    key = entries[i][1]
    end_pos = entries[i + 1][0]

    entry_text = bib_text[start_pos:end_pos].strip()

    if key in keep_keys:
        kept.append(entry_text)
    else:
        removed.append((key, entry_text[:100]))

# Add header
print(f"% Filtered BibTeX - Verification Status")
print(f"% Original entries: {len(results)}")
print(f"% VERIFIED: {len(verified_keys)}")
print(f"% SUSPICIOUS: {len(suspicious_keys)} (included={include_suspicious})")
print(f"% HALLUCINATED removed: {len(hallucinated_keys)}")
print(f"% Final count: {len(kept)}")
print("")

if hallucinated_keys:
    print(f"% Removed entries (HALLUCINATED):")
    for key in sorted(hallucinated_keys):
        print(f"%   - {key}")
    print("")

# Output kept entries
for entry in kept:
    print(entry)
    print("")
FILTER

# Default: include SUSPICIOUS (set to 'false' to exclude)
export INCLUDE_SUSPICIOUS="${INCLUDE_SUSPICIOUS:-true}"
export BIB_FILE="$BIB_FILE"
export VERIFY_FILE="$VERIFY_FILE"

if [[ "$OUTPUT_FILE" == "-" ]]; then
    "$PYTHON_BIN" "$TMP_DIR/filter.py"
else
    "$PYTHON_BIN" "$TMP_DIR/filter.py" > "$OUTPUT_FILE"
    echo "[filter] Verified BibTeX saved to: $OUTPUT_FILE" >&2
fi
