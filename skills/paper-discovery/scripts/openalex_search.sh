#!/usr/bin/env bash
# OpenAlex search client - highest rate limits (10K/day)
# Usage: bash openalex_search.sh "query" [limit] [year_min]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/init.sh"

QUERY="${1:-}"
LIMIT="${2:-20}"
YEAR_MIN="${3:-0}"

if [ -z "$QUERY" ]; then
    echo "Usage: openalex_search.sh <query> [limit] [year_min]" >&2
    exit 1
fi

EMAIL="${OPENALEX_EMAIL:-research@example.com}"

# Encode query
ENCODED_QUERY=$(printf '%s' "$QUERY" | "$PYTHON_BIN" -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()))" 2>/dev/null || echo "$QUERY")

URL="https://api.openalex.org/works?search=${ENCODED_QUERY}&per_page=${LIMIT}&mailto=${EMAIL}"
if [ "$YEAR_MIN" -gt 0 ]; then
    URL="${URL}&filter=from_publication_date:${YEAR_MIN}-01-01"
fi

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "User-Agent: PaperDiscovery/2.0" \
    -H "Accept: application/json" \
    --connect-timeout 15 \
    --max-time 30 \
    "$URL" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo '{"papers":[],"error":"API failed","source":"openalex"}'
    exit 1
fi

# Write body to temp file to avoid heredoc variable injection issues
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "$BODY" > "$TMP_DIR/body.json"

# Transform to unified format using environment variables
export PYTHON_SCRIPT="$TMP_DIR/transform.py"
export TMP_FILE="$TMP_DIR/body.json"
export OUTPUT_QUERY="$QUERY"
export OUTPUT_LIMIT="$LIMIT"
export OUTPUT_YEAR_MIN="$YEAR_MIN"

"$PYTHON_BIN" << 'PYEOF'
import json
import sys
import os

input_file = os.environ['TMP_FILE']
query = os.environ['OUTPUT_QUERY']
limit = int(os.environ['OUTPUT_LIMIT'])
year_min = int(os.environ['OUTPUT_YEAR_MIN'])

try:
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
except Exception as e:
    print(json.dumps({"papers": [], "error": str(e), "source": "openalex"}))
    sys.exit(1)

results = []

for work in data.get('results', []):
    if not work or not isinstance(work, dict):
        continue

    # Extract authors safely
    authors = []
    for auth in work.get('authorships', []) or []:
        if not auth or not isinstance(auth, dict):
            continue
        author_info = auth.get('author') or {}
        if not author_info:
            continue
        name = author_info.get('display_name', '')
        if name:
            authors.append({'name': name})

    # Extract DOI
    doi = work.get('doi') or ''
    if isinstance(doi, str) and doi.startswith('https://doi.org/'):
        doi = doi[16:]

    # Extract venue safely
    venue = ''
    primary_loc = work.get('primary_location') or {}
    if primary_loc and isinstance(primary_loc, dict):
        source = primary_loc.get('source') or {}
        if source and isinstance(source, dict):
            venue = source.get('display_name', '')

    paper = {
        'paper_id': (work.get('id') or '').replace('https://openalex.org/', ''),
        'title': work.get('display_name') or '',
        'authors': authors,
        'publication_type': work.get('type') or '',
        'year': work.get('publication_year') or 0,
        'abstract': work.get('abstract') or '',
        'venue': venue,
        'citation_count': work.get('cited_by_count') or 0,
        'doi': doi,
        'arxiv_id': '',
        'url': (work.get('primary_location') or {}).get('landing_page_url', '') or (f"https://doi.org/{doi}" if doi else ''),
        'source': 'openalex',
        'openalex_id': work.get('id') or ''
    }
    results.append(paper)

output = {
    'query': query,
    'limit': limit,
    'year_min': year_min,
    'count': len(results),
    'source': 'openalex',
    'papers': results
}
print(json.dumps(output, indent=2))
PYEOF
