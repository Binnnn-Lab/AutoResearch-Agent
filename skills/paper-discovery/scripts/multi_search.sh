#!/usr/bin/env bash
# Multi-source paper search - OpenAlex → S2 → arXiv with deduplication
# Usage: bash multi_search.sh "query" [limit] [year_min]
# Legacy compatible: bash multi_search.sh "query" [year_range] [limit]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./init.sh
source "$SCRIPT_DIR/init.sh"
QUERY="${1:-}"
ARG2="${2:-20}"
ARG3="${3:-0}"

# Parameter compatibility:
# - New:    <query> [limit] [year_min]
# - Legacy: <query> [year_range] [limit], e.g. 2020-2026 30
LIMIT="20"
YEAR_MIN="0"

if [[ "$ARG2" =~ ^[0-9]+$ ]]; then
    LIMIT="$ARG2"
    if [[ "$ARG3" =~ ^[0-9]+$ ]]; then
        YEAR_MIN="$ARG3"
    fi
elif [[ "$ARG2" =~ ^([0-9]{4})-([0-9]{4})$ ]]; then
    YEAR_MIN="${BASH_REMATCH[1]}"
    if [[ "$ARG3" =~ ^[0-9]+$ ]]; then
        LIMIT="$ARG3"
    fi
elif [[ "$ARG2" =~ ^([0-9]{4})-$ ]]; then
    YEAR_MIN="${BASH_REMATCH[1]}"
    if [[ "$ARG3" =~ ^[0-9]+$ ]]; then
        LIMIT="$ARG3"
    fi
else
    echo "Error: Invalid parameters. Use either '<query> [limit] [year_min]' or '<query> [year_range] [limit]'" >&2
    echo "Examples:" >&2
    echo "  multi_search.sh 'ICS protocol security' 30 2020" >&2
    echo "  multi_search.sh 'ICS protocol security' 2020-2026 30" >&2
    exit 1
fi

if [[ "$LIMIT" -le 0 ]]; then
    echo "Error: limit must be a positive integer" >&2
    exit 1
fi

if [[ -z "${PYTHON_BIN:-}" ]]; then
    echo "Error: python3/python not found in PATH" >&2
    exit 1
fi

if [ -z "$QUERY" ]; then
    echo "Usage: multi_search.sh <query> [limit] [year_min]" >&2
    echo "Example: multi_search.sh 'LLM security' 30 2020" >&2
    exit 1
fi

echo "[multi-search] Query: '$QUERY' | Limit: $LIMIT | Year >= $YEAR_MIN" >&2
echo "[multi-search] Source order: OpenAlex → Semantic Scholar → arXiv → Google Scholar(fallback)" >&2

# Create temp directory for results
if TMP_DIR=$(mktemp -d 2>/dev/null); then
    :
else
    TMP_DIR="${TMPDIR:-/tmp}/paper_discovery_$$"
    mkdir -p "$TMP_DIR"
fi
trap 'rm -rf "$TMP_DIR"' EXIT

# Search OpenAlex (highest rate limit, generous)
echo "[multi-search] Searching OpenAlex..." >&2
write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"OpenAlex\",\"status\":\"running\"}],\"stats\":{}}"
if bash "$SCRIPT_DIR/openalex_search.sh" "$QUERY" "$LIMIT" "$YEAR_MIN" > "$TMP_DIR/openalex.json" 2>/dev/null; then
    OA_COUNT=$(
        TMP_OPENALEX="$TMP_DIR/openalex.json" "$PYTHON_BIN" << 'PY'
import json
import os

with open(os.environ['TMP_OPENALEX'], encoding='utf-8') as f:
    d = json.load(f)
print(d.get('count', 0))
PY
    )
    echo "[multi-search] OpenAlex: $OA_COUNT papers" >&2
    write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"OpenAlex\",\"status\":\"done\",\"message\":\"$OA_COUNT papers\"}],\"stats\":{\"openalex\":$OA_COUNT}}"
else
    echo "[multi-search] OpenAlex: failed (will try cache or skip)" >&2
    echo '{"papers":[]}' > "$TMP_DIR/openalex.json"
    write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"OpenAlex\",\"status\":\"failed\"}],\"stats\":{}}"
fi
sleep 0.5

# Search Semantic Scholar
echo "[multi-search] Searching Semantic Scholar..." >&2
write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"Semantic Scholar\",\"status\":\"running\"}],\"stats\":{}}"
if bash "$SCRIPT_DIR/s2_search.sh" "$QUERY" "$LIMIT" > "$TMP_DIR/s2.jsonl" 2>/dev/null; then
    S2_COUNT=$(
        TMP_S2="$TMP_DIR/s2.jsonl" "$PYTHON_BIN" << 'PY'
import os

count = 0
with open(os.environ['TMP_S2'], encoding='utf-8') as f:
    for line in f:
        if line.strip().startswith('{'):
            count += 1
print(count)
PY
    )
    echo "[multi-search] Semantic Scholar: $S2_COUNT papers" >&2
    write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"Semantic Scholar\",\"status\":\"done\",\"message\":\"$S2_COUNT papers\"}],\"stats\":{\"s2\":$S2_COUNT}}"
else
    echo "[multi-search] Semantic Scholar: failed" >&2
    : > "$TMP_DIR/s2.jsonl"
    write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"Semantic Scholar\",\"status\":\"failed\"}],\"stats\":{}}"
fi
sleep 1

# Search arXiv
echo "[multi-search] Searching arXiv..." >&2
write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"arXiv\",\"status\":\"running\"}],\"stats\":{}}"
if bash "$SCRIPT_DIR/arxiv_search.sh" "$QUERY" "$LIMIT" "$YEAR_MIN" > "$TMP_DIR/arxiv.json" 2>/dev/null; then
    ARX_COUNT=$(
        TMP_ARXIV="$TMP_DIR/arxiv.json" "$PYTHON_BIN" << 'PY'
import json
import os

with open(os.environ['TMP_ARXIV'], encoding='utf-8') as f:
    d = json.load(f)
print(d.get('count', 0))
PY
    )
    echo "[multi-search] arXiv: $ARX_COUNT papers" >&2
    write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"arXiv\",\"status\":\"done\",\"message\":\"$ARX_COUNT papers\"}],\"stats\":{\"arxiv\":$ARX_COUNT}}"
else
    echo "[multi-search] arXiv: failed" >&2
    echo '{"papers":[]}' > "$TMP_DIR/arxiv.json"
    write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"arXiv\",\"status\":\"failed\"}],\"stats\":{}}"
fi

# Search Google Scholar as mandatory recent-coverage source
if [[ "${ENABLE_GOOGLE_SCHOLAR:-true}" == "true" ]]; then
    echo "[multi-search] Searching Google Scholar (fallback)..." >&2
    write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"Google Scholar\",\"status\":\"running\"}],\"stats\":{}}"
    if "$PYTHON_BIN" "$SCRIPT_DIR/google_scholar_search.py" "$QUERY" "$LIMIT" "$YEAR_MIN" > "$TMP_DIR/google_scholar.json" 2>/dev/null; then
        GS_COUNT=$(
            TMP_GS="$TMP_DIR/google_scholar.json" "$PYTHON_BIN" << 'PY'
import json
import os

with open(os.environ['TMP_GS'], encoding='utf-8') as f:
    d = json.load(f)
print(d.get('count', 0))
PY
        )
        echo "[multi-search] Google Scholar: $GS_COUNT papers" >&2
        write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"Google Scholar\",\"status\":\"done\",\"message\":\"$GS_COUNT papers\"}],\"stats\":{\"gs\":$GS_COUNT}}"
    else
        echo "[multi-search] Google Scholar: failed" >&2
        echo '{"papers":[]}' > "$TMP_DIR/google_scholar.json"
        write_status_json "{\"state\":\"running\",\"main_step\":\"多源检索\",\"sub_steps\":[{\"name\":\"Google Scholar\",\"status\":\"failed\"}],\"stats\":{}}"
    fi
else
    echo "[multi-search] Google Scholar: disabled by ENABLE_GOOGLE_SCHOLAR=false" >&2
    echo '{"papers":[]}' > "$TMP_DIR/google_scholar.json"
fi

# Merge and deduplicate
echo "[multi-search] Merging and deduplicating..." >&2
write_status_json "{\"state\":\"running\",\"main_step\":\"去重与分拣\",\"sub_steps\":[],\"stats\":{}}"
_PD_TMP_DIR="$TMP_DIR"
    export _PD_TMP_DIR

$PYTHON_BIN << EOF
import json
import re


def load_openalex(path):
    try:
        data = json.load(open(path, encoding='utf-8'))
        return data.get('papers', [])
    except Exception:
        return []


def load_s2_jsonl(path):
    papers = []
    try:
        with open(path, encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or not line.startswith('{'):
                    continue
                try:
                    papers.append(json.loads(line))
                except Exception:
                    continue
    except Exception:
        pass
    return papers


def load_arxiv(path):
    try:
        data = json.load(open(path, encoding='utf-8'))
        return data.get('papers', [])
    except Exception:
        return []

def normalize_title(title):
    """Normalize title for deduplication comparison."""
    t = (title or '').lower()
    t = re.sub(r'[^a-z0-9\s]', '', t)
    return re.sub(r'\s+', ' ', t).strip()


def normalize_doi(doi):
    """Normalize DOI key across providers."""
    if not doi:
        return ''
    d = str(doi).strip().lower()
    d = re.sub(r'^https?://(dx\.)?doi\.org/', '', d)
    d = re.sub(r'^doi:\s*', '', d)
    d = re.sub(r'\s+', '', d)
    return d


def normalize_arxiv_id(arxiv_id):
    """Normalize arXiv ID and drop version suffix."""
    if not arxiv_id:
        return ''
    a = str(arxiv_id).strip().lower()
    a = re.sub(r'^https?://arxiv\.org/abs/', '', a)
    a = re.sub(r'^arxiv:\s*', '', a)
    a = re.sub(r'v\d+$', '', a)
    return a


def title_similarity(a, b):
    """Calculate Jaccard-like similarity between titles."""
    wa = set(normalize_title(a).split()) - {''}
    wb = set(normalize_title(b).split()) - {''}
    if not wa or not wb:
        return 0.0
    return len(wa & wb) / max(len(wa), len(wb))


TITLE_SIM_THRESHOLD = 0.85

# Load all results
import os
TMP_DIR_PY = os.environ.get("_PD_TMP_DIR", "")
sources = {
    'openalex': load_openalex(TMP_DIR_PY + '/openalex.json'),
    'semantic_scholar': load_s2_jsonl(TMP_DIR_PY + '/s2.jsonl'),
    'arxiv': load_arxiv(TMP_DIR_PY + '/arxiv.json'),
    'google_scholar': load_arxiv(TMP_DIR_PY + '/google_scholar.json')
}

# Filter by year for sources that return mixed years
year_min = int('$YEAR_MIN')
if year_min > 0:
    for k in list(sources.keys()):
        sources[k] = [p for p in sources[k] if int(p.get('year') or 0) >= year_min]

# Deduplication with priority: DOI > arXiv ID > fuzzy title
seen_doi = {}
seen_arxiv = {}
seen_title = {}
results = []

def update_indices(paper, idx):
    """Register paper identifiers."""
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

    for idx, existing in enumerate(results):
        if title_similarity(title, existing.get('title', '')) >= TITLE_SIM_THRESHOLD:
            return idx
    return None

def replace_at(old_paper, new_paper, idx):
    """Replace paper at index, updating indices."""
    merged_sources = list(set(old_paper.get('sources_found', []) + new_paper.get('sources_found', [])))

    # Clean up old indices
    old_doi = normalize_doi(old_paper.get('doi'))
    new_doi = normalize_doi(new_paper.get('doi'))
    if old_doi:
        if old_doi != new_doi and seen_doi.get(old_doi) == idx:
            del seen_doi[old_doi]

    old_ax = normalize_arxiv_id(old_paper.get('arxiv_id'))
    new_ax = normalize_arxiv_id(new_paper.get('arxiv_id'))
    if old_ax:
        if old_ax != new_ax and seen_arxiv.get(old_ax) == idx:
            del seen_arxiv[old_ax]

    old_norm = normalize_title(old_paper.get('title', ''))
    new_norm = normalize_title(new_paper.get('title', ''))
    if old_norm and old_norm != new_norm and seen_title.get(old_norm) == idx:
        del seen_title[old_norm]

    new_paper['sources_found'] = merged_sources
    results[idx] = new_paper
    update_indices(new_paper, idx)

# Process papers from all sources (OpenAlex first for better metadata)
source_order = ['openalex', 'semantic_scholar', 'arxiv', 'google_scholar']
for source in source_order:
    for paper in sources[source]:
        paper['sources_found'] = list(set(paper.get('sources_found', []) + [source]))
        is_dup = False

        # Check DOI
        doi_key = normalize_doi(paper.get('doi'))
        if doi_key:
            if doi_key in seen_doi:
                idx = seen_doi[doi_key]
                # Keep higher citation count
                if int(paper.get('citation_count', paper.get('citations', 0)) or 0) > int(results[idx].get('citation_count', results[idx].get('citations', 0)) or 0):
                    replace_at(results[idx], paper, idx)
                else:
                    results[idx]['sources_found'] = list(set(results[idx].get('sources_found', []) + [source]))
                is_dup = True

        # Check arXiv ID
        ax_key = normalize_arxiv_id(paper.get('arxiv_id'))
        if not is_dup and ax_key:
            if ax_key in seen_arxiv:
                idx = seen_arxiv[ax_key]
                if int(paper.get('citation_count', paper.get('citations', 0)) or 0) > int(results[idx].get('citation_count', results[idx].get('citations', 0)) or 0):
                    replace_at(results[idx], paper, idx)
                else:
                    results[idx]['sources_found'] = list(set(results[idx].get('sources_found', []) + [source]))
                is_dup = True

        # Check fuzzy title
        if not is_dup:
            idx = find_title_match_idx(paper.get('title', ''))
            if idx is not None:
                if int(paper.get('citation_count', paper.get('citations', 0)) or 0) > int(results[idx].get('citation_count', results[idx].get('citations', 0)) or 0):
                    replace_at(results[idx], paper, idx)
                else:
                    results[idx]['sources_found'] = list(set(results[idx].get('sources_found', []) + [source]))
                is_dup = True

        if is_dup:
            continue

        # New paper
        new_idx = len(results)
        update_indices(paper, new_idx)
        results.append(paper)

# Sort by citation count descending, then year descending
results.sort(key=lambda p: (int(p.get('citation_count', p.get('citations', 0)) or 0), int(p.get('year', 0) or 0)), reverse=True)

# Count by source
source_counts = {}
for p in results:
    for s in p.get('sources_found', []):
        source_counts[s] = source_counts.get(s, 0) + 1

output = {
    'query': '$QUERY',
    'limit_per_source': $LIMIT,
    'year_min': $YEAR_MIN,
    'total_found': len(results),
    'source_breakdown': source_counts,
    'deduplication_stats': {
        'openalex_original': len(sources['openalex']),
        's2_original': len(sources['semantic_scholar']),
        'arxiv_original': len(sources['arxiv']),
        'google_scholar_original': len(sources['google_scholar']),
        'unique_after_dedup': len(results)
    },
    'papers': results
}

print(json.dumps(output, indent=2))
EOF

echo "[multi-search] Complete!" >&2
write_status_json "{\"state\":\"done\",\"main_step\":\"多源检索\",\"artifacts\":[\"$TMP_DIR\"],\"executed\":true}"