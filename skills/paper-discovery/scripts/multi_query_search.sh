#!/usr/bin/env bash
# Multi-query search with sequential execution and global deduplication
# Usage: bash multi_query_search.sh <queries.json> [limit_per_query]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./init.sh
source "$SCRIPT_DIR/init.sh"
QUERIES_FILE="${1:-}"
LIMIT_PER_QUERY="${2:-30}"
YEAR_MIN="${3:-0}"

if [[ -z "${PYTHON_BIN:-}" ]]; then
    echo "Error: python3/python not found in PATH" >&2
    exit 1
fi

if [ -z "$QUERIES_FILE" ] || { [ "$QUERIES_FILE" != "-" ] && [ ! -f "$QUERIES_FILE" ]; }; then
    echo "Usage: multi_query_search.sh <queries.json|-> [limit_per_query] [year_min]" >&2
    echo "Input JSON format: { 'queries': [{'query': '...', 'type': '...'}, ...] }" >&2
    exit 1
fi

# Parse queries
QUERIES=$(QUERIES_FILE="$QUERIES_FILE" "$PYTHON_BIN" -c '
import json
import sys
import os

qf = os.environ["QUERIES_FILE"]
try:
    if qf == "-":
        d = json.load(sys.stdin)
    else:
        with open(qf, encoding="utf-8") as f:
            d = json.load(f)
    print("\n".join([q["query"] for q in d.get("queries", [])]))
except Exception as e:
    print(f"Error parsing JSON queries: {e}", file=sys.stderr)
')

# Windows shells may inject CRLF into command substitution output.
# Remove CR to avoid passing malformed queries downstream.
QUERIES=$(printf '%s' "$QUERIES" | tr -d '\r')

if [ -z "$QUERIES" ]; then
    echo "Error: No queries found in $QUERIES_FILE" >&2
    exit 1
fi

echo "[multi-query] Processing $(echo "$QUERIES" | wc -l) queries..." >&2

# Create temp directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT
export TMP_DIR

# Run searches sequentially with delay
i=0
echo "$QUERIES" | while read -r query; do
    i=$((i + 1))
    query=$(printf '%s' "$query" | tr -d '\r')
    if [ -z "$query" ]; then continue; fi

    echo "[multi-query] [$i] Searching: '$query'" >&2

    # Run multi_search for this query
    ERR_FILE="$TMP_DIR/query_$i.err"
    if bash "$SCRIPT_DIR/multi_search.sh" "$query" "$LIMIT_PER_QUERY" "$YEAR_MIN" > "$TMP_DIR/query_$i.json" 2>"$ERR_FILE"; then
        count=$(TMP_QUERY="$TMP_DIR/query_$i.json" "$PYTHON_BIN" << 'PY'
import json
import os

with open(os.environ['TMP_QUERY'], encoding='utf-8') as f:
    d = json.load(f)
print(d.get('total_found', 0))
PY
)
        echo "[multi-query] [$i] Found $count papers" >&2
    else
        if [ -s "$ERR_FILE" ]; then
            reason=$(head -n 1 "$ERR_FILE")
            echo "[multi-query] [$i] Search failed: $reason" >&2
        else
            echo "[multi-query] [$i] Search failed" >&2
        fi
        echo '{"papers":[]}' > "$TMP_DIR/query_$i.json"
    fi

    # Rate limiting between queries
    if [ $i -lt $(echo "$QUERIES" | wc -l) ]; then
        sleep 2
    fi
done

# Merge all results
$PYTHON_BIN << 'MERGER'
import json
import sys
import glob

def normalize_title(title):
    import re
    t = (title or '').lower()
    t = re.sub(r'[^a-z0-9\s]', '', t)
    return re.sub(r'\s+', ' ', t).strip()


def normalize_doi(doi):
    import re
    if not doi:
        return ''
    d = str(doi).strip().lower()
    d = re.sub(r'^https?://(dx\.)?doi\.org/', '', d)
    d = re.sub(r'^doi:\s*', '', d)
    d = re.sub(r'\s+', '', d)
    return d


def normalize_arxiv_id(arxiv_id):
    import re
    if not arxiv_id:
        return ''
    a = str(arxiv_id).strip().lower()
    a = re.sub(r'^https?://arxiv\.org/abs/', '', a)
    a = re.sub(r'^arxiv:\s*', '', a)
    a = re.sub(r'v\d+$', '', a)
    return a


def title_similarity(a, b):
    wa = set(normalize_title(a).split()) - {''}
    wb = set(normalize_title(b).split()) - {''}
    if not wa or not wb:
        return 0.0
    return len(wa & wb) / max(len(wa), len(wb))


TITLE_SIM_THRESHOLD = 0.85

all_papers = []
query_sources = {}

# Load all query results
import os
for f in sorted(glob.glob(os.environ.get('TMP_DIR', '/tmp') + '/query_*.json')):
    try:
        data = json.load(open(f))
        query_idx = f.split('query_')[-1].split('.')[0]
        for paper in data.get('papers', []):
            paper['_source_query'] = query_idx
            all_papers.append(paper)
    except Exception as e:
        print(f"Warning: Failed to load {f}: {e}", file=sys.stderr)

# Deduplicate by DOI → arXiv ID → fuzzy title
seen_doi = {}
seen_arxiv = {}
seen_title = {}
unique_papers = []


def update_indices(paper, idx):
    doi_key = normalize_doi(paper.get('doi'))
    if doi_key:
        seen_doi[doi_key] = idx

    ax_key = normalize_arxiv_id(paper.get('arxiv_id'))
    if ax_key:
        seen_arxiv[ax_key] = idx

    norm = normalize_title(paper.get('title', ''))
    if norm:
        seen_title[norm] = idx


def find_title_match_idx(title):
    norm = normalize_title(title)
    if norm and norm in seen_title:
        return seen_title[norm]

    for idx, existing in enumerate(unique_papers):
        if title_similarity(title, existing.get('title', '')) >= TITLE_SIM_THRESHOLD:
            return idx
    return None


def replace_at(idx, new_paper):
    old_paper = unique_papers[idx]

    old_doi = normalize_doi(old_paper.get('doi'))
    new_doi = normalize_doi(new_paper.get('doi'))
    if old_doi and old_doi != new_doi and seen_doi.get(old_doi) == idx:
        del seen_doi[old_doi]

    old_ax = normalize_arxiv_id(old_paper.get('arxiv_id'))
    new_ax = normalize_arxiv_id(new_paper.get('arxiv_id'))
    if old_ax and old_ax != new_ax and seen_arxiv.get(old_ax) == idx:
        del seen_arxiv[old_ax]

    old_norm = normalize_title(old_paper.get('title', ''))
    new_norm = normalize_title(new_paper.get('title', ''))
    if old_norm and old_norm != new_norm and seen_title.get(old_norm) == idx:
        del seen_title[old_norm]

    merged_sources = list(set(old_paper.get('sources_found', []) + new_paper.get('sources_found', [])))
    merged_queries = list(set(old_paper.get('source_queries', []) + new_paper.get('source_queries', [])))

    new_paper['sources_found'] = merged_sources
    new_paper['source_queries'] = merged_queries
    unique_papers[idx] = new_paper
    update_indices(new_paper, idx)

for paper in all_papers:
    paper['source_queries'] = list(set(paper.get('source_queries', []) + [paper.get('_source_query', '')]))
    is_dup = False

    # Check DOI
    doi_key = normalize_doi(paper.get('doi'))
    if doi_key:
        if doi_key in seen_doi:
            idx = seen_doi[doi_key]
            if int(paper.get('citation_count', paper.get('citations', 0)) or 0) > int(unique_papers[idx].get('citation_count', unique_papers[idx].get('citations', 0)) or 0):
                replace_at(idx, paper)
            else:
                unique_papers[idx]['sources_found'] = list(set(unique_papers[idx].get('sources_found', []) + paper.get('sources_found', [])))
                unique_papers[idx]['source_queries'] = list(set(unique_papers[idx].get('source_queries', []) + paper.get('source_queries', [])))
            is_dup = True

    # Check arXiv
    ax_key = normalize_arxiv_id(paper.get('arxiv_id'))
    if not is_dup and ax_key:
        if ax_key in seen_arxiv:
            idx = seen_arxiv[ax_key]
            if int(paper.get('citation_count', paper.get('citations', 0)) or 0) > int(unique_papers[idx].get('citation_count', unique_papers[idx].get('citations', 0)) or 0):
                replace_at(idx, paper)
            else:
                unique_papers[idx]['sources_found'] = list(set(unique_papers[idx].get('sources_found', []) + paper.get('sources_found', [])))
                unique_papers[idx]['source_queries'] = list(set(unique_papers[idx].get('source_queries', []) + paper.get('source_queries', [])))
            is_dup = True

    # Check title
    if not is_dup:
        idx = find_title_match_idx(paper.get('title', ''))
        if idx is not None:
            if int(paper.get('citation_count', paper.get('citations', 0)) or 0) > int(unique_papers[idx].get('citation_count', unique_papers[idx].get('citations', 0)) or 0):
                replace_at(idx, paper)
            else:
                unique_papers[idx]['sources_found'] = list(set(unique_papers[idx].get('sources_found', []) + paper.get('sources_found', [])))
                unique_papers[idx]['source_queries'] = list(set(unique_papers[idx].get('source_queries', []) + paper.get('source_queries', [])))
            is_dup = True

    if not is_dup:
        new_idx = len(unique_papers)
        unique_papers.append(paper)
        update_indices(paper, new_idx)

# Sort by citation count, then year
unique_papers.sort(key=lambda p: (int(p.get('citation_count', p.get('citations', 0)) or 0), int(p.get('year', 0) or 0)), reverse=True)

# Build output
output = {
    'query_count': len(glob.glob(os.environ.get('TMP_DIR', '/tmp') + '/query_*.json')),
    'total_raw': len(all_papers),
    'total_unique': len(unique_papers),
    'deduplication_ratio': f"{len(unique_papers)}/{len(all_papers)}",
    'papers': unique_papers
}

print(json.dumps(output, indent=2))
print(f"[multi-query] Merged: {len(all_papers)} raw → {len(unique_papers)} unique", file=sys.stderr)
MERGER

echo "[multi-query] Complete" >&2
