#!/usr/bin/env bash
# arXiv search client (single source of truth, Windows-compatible)
# Usage: bash arxiv_search.sh "query" [limit] [year_min]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./init.sh
source "$SCRIPT_DIR/init.sh"

QUERY="${1:-}"
LIMIT="${2:-20}"
YEAR_MIN="${3:-0}"

if [ -z "$QUERY" ]; then
    echo "Usage: arxiv_search.sh <query> [limit] [year_min]" >&2
    exit 1
fi

CACHE_DIR="${HOME}/.cache/paper-discovery/arxiv"
CACHE_TTL_DAYS="${CACHE_TTL_DAYS:-7}"
mkdir -p "$CACHE_DIR"

if [[ -z "${PYTHON_BIN:-}" ]]; then
    echo "Error: python3/python not found in PATH" >&2
    exit 1
fi

# Build cache key
CACHE_KEY=$(echo "$QUERY|$LIMIT|$YEAR_MIN" | md5sum | cut -d' ' -f1)
CACHE_FILE="$CACHE_DIR/${CACHE_KEY}.xml"

# Check cache
if [ -f "$CACHE_FILE" ]; then
    CACHE_AGE=$(( ($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE")) / 86400 ))
    if [ "$CACHE_AGE" -lt "$CACHE_TTL_DAYS" ]; then
        cat "$CACHE_FILE" | "$PYTHON_BIN" -c "
import sys
import xml.etree.ElementTree as ET
import json
import re

ns = {'atom': 'http://www.w3.org/2005/Atom'}
tree = ET.parse(sys.stdin)
root = tree.getroot()

results = []
for entry in root.findall('atom:entry', ns):
    # Skip error entries
    title_el = entry.find('atom:title', ns)
    if title_el is None or title_el.text == 'Error':
        continue

    title = title_el.text or ''

    # Extract arXiv ID
    id_url = entry.find('atom:id', ns)
    arxiv_id = ''
    if id_url is not None:
        arxiv_id = id_url.text.split('/abs/')[-1].split('v')[0] if '/abs/' in id_url.text else ''

    # Extract authors
    authors = []
    for author in entry.findall('atom:author', ns):
        name = author.find('atom:name', ns)
        if name is not None:
            authors.append({'name': name.text})

    # Extract published date
    published = entry.find('atom:published', ns)
    year = 0
    if published is not None:
        year = int(published.text[:4]) if published.text else 0

    # Extract summary/abstract
    summary = entry.find('atom:summary', ns)
    abstract = summary.text if summary is not None else ''

    # Extract DOI if available
    doi = ''
    for link in entry.findall('atom:link', ns):
        if link.get('title') == 'doi':
            doi = link.get('href', '').replace('https://doi.org/', '')
            break

    # Extract PDF link
    pdf_url = ''
    for link in entry.findall('atom:link', ns):
        if link.get('type') == 'application/pdf':
            pdf_url = link.get('href', '')
            break

    paper = {
        'paper_id': arxiv_id,
        'title': title,
        'authors': authors,
        'publication_type': 'preprint',
        'year': year,
        'abstract': abstract,
        'venue': 'arXiv',
        'citation_count': 0,  # arXiv doesn't provide citation counts
        'doi': doi,
        'arxiv_id': arxiv_id,
        'url': f'https://arxiv.org/abs/{arxiv_id}' if arxiv_id else '',
        'pdf_url': pdf_url,
        'source': 'arxiv'
    }
    results.append(paper)

output = {
    'query': '$QUERY',
    'limit': $LIMIT,
    'year_min': $YEAR_MIN,
    'count': len(results),
    'source': 'arxiv',
    'papers': results
}
print(json.dumps(output, indent=2))
"
        exit 0
    fi
fi

# Encode query for URL
ENCODED_QUERY=$("$PYTHON_BIN" - "$QUERY" << 'PY'
import sys
import urllib.parse

print(urllib.parse.quote(sys.argv[1]))
PY
)

# Build search URL
# arXiv API uses 1-based indexing and max_results
START=0
MAX_RESULTS=$LIMIT

URL="https://export.arxiv.org/api/query?search_query=all:${ENCODED_QUERY}&start=${START}&max_results=${MAX_RESULTS}&sortBy=relevance&sortOrder=descending"

# Make request with conservative rate limiting (1 per 3 seconds)
sleep 3

RESPONSE=$(curl -s --ssl-no-revoke -w "\n%{http_code}" \
    -H "User-Agent: PaperDiscovery/2.0" \
    --connect-timeout 20 \
    --max-time 45 \
    "$URL" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo "Error: arXiv API returned HTTP $HTTP_CODE" >&2
    if [ -f "$CACHE_FILE" ]; then
        echo "Using stale cache..." >&2
        cat "$CACHE_FILE"
        exit 0
    fi
    echo '{"results":[],"error":"API failed","source":"arxiv"}'
    exit 1
fi

# Cache the XML response
echo "$BODY" > "$CACHE_FILE"

# Parse and output
"$PYTHON_BIN" << EOF
import xml.etree.ElementTree as ET
import json
import re

ns = {'atom': 'http://www.w3.org/2005/Atom'}
root = ET.fromstring('''$BODY''')

results = []
for entry in root.findall('atom:entry', ns):
    title_el = entry.find('atom:title', ns)
    if title_el is None or title_el.text == 'Error':
        continue

    title = title_el.text or ''
    title = re.sub(r'\s+', ' ', title).strip()

    id_url = entry.find('atom:id', ns)
    arxiv_id = ''
    if id_url is not None:
        arxiv_id = id_url.text.split('/abs/')[-1].split('v')[0] if '/abs/' in id_url.text else ''

    authors = []
    for author in entry.findall('atom:author', ns):
        name = author.find('atom:name', ns)
        if name is not None:
            authors.append({'name': name.text})

    published = entry.find('atom:published', ns)
    year = int(published.text[:4]) if published is not None and published.text else 0

    summary = entry.find('atom:summary', ns)
    abstract = summary.text if summary is not None else ''

    doi = ''
    pdf_url = ''
    for link in entry.findall('atom:link', ns):
        if link.get('title') == 'doi':
            doi = link.get('href', '').replace('https://doi.org/', '')
        if link.get('type') == 'application/pdf':
            pdf_url = link.get('href', '')

    # Filter by year if specified
    if $YEAR_MIN > 0 and year < $YEAR_MIN:
        continue

    paper = {
        'paper_id': arxiv_id,
        'title': title,
        'authors': authors,
        'publication_type': 'preprint',
        'year': year,
        'abstract': abstract,
        'venue': 'arXiv',
        'citation_count': 0,
        'doi': doi,
        'arxiv_id': arxiv_id,
        'url': f'https://arxiv.org/abs/{arxiv_id}' if arxiv_id else '',
        'pdf_url': pdf_url,
        'source': 'arxiv'
    }
    results.append(paper)

output = {
    'query': '$QUERY',
    'limit': $LIMIT,
    'year_min': $YEAR_MIN,
    'count': len(results),
    'source': 'arxiv',
    'papers': results
}
print(json.dumps(output, indent=2))
EOF