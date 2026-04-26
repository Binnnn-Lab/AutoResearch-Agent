#!/usr/bin/env bash
# 4-layer citation verification - detect hallucinated references
# Usage: bash verify_citations.sh <references.bib> [output_report.json|-]
# Layers: L1 arXiv ID -> L2 DOI -> L3a OpenAlex -> L3b S2 title search

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./init.sh
source "$SCRIPT_DIR/init.sh"
BIB_FILE="${1:-}"
OUTPUT_FILE="${2:--}"

if [ -z "$BIB_FILE" ] || { [ "$BIB_FILE" != "-" ] && [ ! -f "$BIB_FILE" ]; }; then
    echo "Usage: verify_citations.sh <references.bib|-> [output_report.json|-]" >&2
    echo "Verifies each BibTeX entry through 4 layers:" >&2
    echo "  L1: arXiv ID lookup" >&2
    echo "  L2: DOI resolution (CrossRef + DataCite)" >&2
    echo "  L3a: OpenAlex title search" >&2
    echo "  L3b: S2 title search (fallback)" >&2
    exit 1
fi

echo "[verify] Starting 4-layer citation verification..." >&2
echo "[verify] Input: $BIB_FILE" >&2

if [[ -z "${PYTHON_BIN:-}" ]]; then
    echo "Error: python3/python not found in PATH" >&2
    exit 1
fi

# Create temp directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Parse BibTeX entries
BIB_FILE="$BIB_FILE" "$PYTHON_BIN" -c '
import re
import json
import sys
import os

# Parse BibTeX entries
entry_re = re.compile(r"@(\w+)\s*\{\s*([^,\s]+)\s*,\s*(.*?)\s*\}(?=\s*(?:@|\Z))", re.DOTALL)
field_re = re.compile(r"(\w+)\s*=\s*\{((?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*)\}", re.DOTALL)

qf = os.environ["BIB_FILE"]
if qf == "-":
    bib_text = sys.stdin.read()
else:
    bib_text = open(qf, encoding="utf-8").read()
entries = []

for m in entry_re.finditer(bib_text):
    entry = {
        "type": m.group(1).lower(),
        "key": m.group(2).strip(),
    }
    body = m.group(3)
    for fm in field_re.finditer(body):
        entry[fm.group(1).lower()] = fm.group(2).strip()
    entries.append(entry)

print(json.dumps(entries))
' > "$TMP_DIR/entries.json"

export TMP_DIR
export SCRIPT_DIR
TOTAL=$("$PYTHON_BIN" -c "import json, os; print(len(json.load(open(os.path.join(os.environ['TMP_DIR'], 'entries.json')))))")
echo "[verify] Found $TOTAL BibTeX entries to verify" >&2

# Write the Python verifier script to a temp file
cat > "$TMP_DIR/verifier.py" << 'PYEOF'
import json
import re
import sys
import time
import urllib.request
import urllib.error
import urllib.parse
import os
import hashlib
from pathlib import Path

# Cache setup
CACHE_DIR = Path.home() / ".cache" / "paper-discovery" / "citation_verify"
CACHE_DIR.mkdir(parents=True, exist_ok=True)

def cache_key(title, doi=''):
    raw = f"{(doi or '').lower().strip()}|{title.lower().strip()}"
    return hashlib.sha256(raw.encode()).hexdigest()[:16]

def read_cache(title, doi=''):
    cache_file = CACHE_DIR / f"{cache_key(title, doi)}.json"
    if cache_file.exists():
        try:
            return json.loads(cache_file.read_text())
        except:
            return None
    return None

def write_cache(title, doi, result):
    cache_file = CACHE_DIR / f"{cache_key(title, doi)}.json"
    cache_file.write_text(json.dumps(result, indent=2))

def normalize_title(title):
    return re.sub(r'[^a-z0-9\s]', '', title.lower()).strip()

def title_similarity(a, b):
    wa = set(normalize_title(a).split()) - {''}
    wb = set(normalize_title(b).split()) - {''}
    if not wa or not wb:
        return 0.0
    return len(wa & wb) / max(len(wa), len(wb))

def _normalize_surname(name):
    if not name:
        return ''
    n = str(name).strip()
    if ',' in n:
        n = n.split(',', 1)[0].strip()
    else:
        parts = n.split()
        n = parts[-1].strip() if parts else n
    n = re.sub(r'[^a-zA-Z\-\']', '', n).lower()
    return n

def extract_expected_author_surnames(author_field):
    """Parse BibTeX author field into normalized surname set."""
    if not author_field:
        return set()
    parts = [p.strip() for p in str(author_field).split(' and ') if p.strip()]
    out = set()
    for p in parts:
        s = _normalize_surname(p)
        if s:
            out.add(s)
    return out

def extract_found_author_surnames(author_names):
    out = set()
    for n in author_names or []:
        s = _normalize_surname(n)
        if s:
            out.add(s)
    return out

def author_overlap_ratio(expected_surnames, found_surnames):
    if not expected_surnames or not found_surnames:
        return 0.0
    inter = expected_surnames & found_surnames
    return len(inter) / max(1, min(len(expected_surnames), len(found_surnames)))

def verify_url_redirect(url, doi='', arxiv_id=''):
    """Lightweight URL redirect consistency check.

    Returns dict with warning flag when final URL is inconsistent with DOI/arXiv identifiers.
    """
    if not url:
        return {'ok': True, 'warning': False, 'reason': ''}

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "PaperDiscovery/2.0"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            final_url = (resp.geturl() or '').lower()
            status = getattr(resp, 'status', 200)

        doi_l = (doi or '').lower().strip()
        arxiv_l = (arxiv_id or '').lower().strip()

        if doi_l and 'doi.org/' in url.lower() and doi_l not in final_url:
            return {
                'ok': False,
                'warning': True,
                'reason': f"DOI redirect mismatch: expected {doi_l}, got {final_url}",
                'http_status': status,
                'final_url': final_url,
            }
        if arxiv_l and 'arxiv.org/' in url.lower() and arxiv_l not in final_url:
            return {
                'ok': False,
                'warning': True,
                'reason': f"arXiv redirect mismatch: expected {arxiv_l}, got {final_url}",
                'http_status': status,
                'final_url': final_url,
            }

        return {
            'ok': True,
            'warning': False,
            'reason': '',
            'http_status': status,
            'final_url': final_url,
        }
    except Exception as e:
        return {
            'ok': False,
            'warning': True,
            'reason': f"URL check failed: {e}",
        }

# L1: Verify by arXiv ID
def verify_arxiv_id(arxiv_id, expected_title, expected_author_surnames):
    """L1 verification via arXiv API."""
    if not arxiv_id:
        return None

    try:
        url = f"https://export.arxiv.org/api/query?id_list={arxiv_id}&max_results=1"
        req = urllib.request.Request(url, headers={"User-Agent": "PaperDiscovery/2.0"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = resp.read().decode('utf-8')

        import xml.etree.ElementTree as ET
        ns = {'atom': 'http://www.w3.org/2005/Atom'}
        root = ET.fromstring(data)
        entries = root.findall('atom:entry', ns)

        if not entries:
            return {'status': 'HALLUCINATED', 'confidence': 0.9, 'method': 'arxiv_id',
                    'details': f'arXiv ID {arxiv_id} not found'}

        entry = entries[0]
        found_title = entry.findtext('atom:title', '', ns).strip()
        found_title = re.sub(r'\s+', ' ', found_title)
        found_authors = [a.findtext('atom:name', '', ns).strip() for a in entry.findall('atom:author', ns)]
        found_author_surnames = extract_found_author_surnames(found_authors)
        a_overlap = author_overlap_ratio(expected_author_surnames, found_author_surnames)

        if 'Error' in found_title or not found_title:
            return {'status': 'HALLUCINATED', 'confidence': 0.9, 'method': 'arxiv_id',
                    'details': f'arXiv ID {arxiv_id} returned error'}

        sim = title_similarity(expected_title, found_title)
        if sim >= 0.80:
            if expected_author_surnames and a_overlap == 0.0:
                return {'status': 'SUSPICIOUS', 'confidence': sim, 'method': 'arxiv_id',
                        'details': f"Title match but author mismatch (overlap={a_overlap:.2f}): '{found_title}'"}
            return {'status': 'VERIFIED', 'confidence': sim, 'method': 'arxiv_id',
                    'details': f"Confirmed via arXiv: '{found_title}'"}
        elif sim >= 0.50:
            return {'status': 'SUSPICIOUS', 'confidence': sim, 'method': 'arxiv_id',
                    'details': f"arXiv ID exists but title differs (sim={sim:.2f}): '{found_title}'"}
        else:
            return {'status': 'HALLUCINATED', 'confidence': 1.0 - sim, 'method': 'arxiv_id',
                    'details': f"Title mismatch (sim={sim:.2f}): '{found_title}'"}
    except Exception as e:
        return None  # Network failure, fall through

# L2: Verify by DOI
def verify_doi(doi, expected_title, expected_author_surnames):
    """L2 verification via CrossRef/DataCite."""
    if not doi:
        return None

    try:
        # Try CrossRef first
        encoded = urllib.parse.quote(doi, safe='')
        url = f"https://api.crossref.org/works/{encoded}"
        req = urllib.request.Request(url, headers={
            "User-Agent": "PaperDiscovery/2.0 (mailto:research@example.com)",
            "Accept": "application/json"
        })
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode('utf-8'))

        message = data.get('message', {})
        titles = message.get('title', [])
        found_title = titles[0] if titles else ''
        found_authors = [a.get('family', '') for a in message.get('author', []) if isinstance(a, dict)]
        found_author_surnames = extract_found_author_surnames(found_authors)
        a_overlap = author_overlap_ratio(expected_author_surnames, found_author_surnames)

        if not found_title:
            return {'status': 'HALLUCINATED', 'confidence': 0.95, 'method': 'doi',
                'details': f'DOI {doi} resolves but title is missing in CrossRef metadata'}

        sim = title_similarity(expected_title, found_title)
        if sim >= 0.80:
            if expected_author_surnames and a_overlap == 0.0:
                return {'status': 'SUSPICIOUS', 'confidence': sim, 'method': 'doi',
                        'details': f"DOI title match but author mismatch (overlap={a_overlap:.2f}): '{found_title}'"}
            return {'status': 'VERIFIED', 'confidence': sim, 'method': 'doi',
                    'details': f"Confirmed via CrossRef: '{found_title}'"}
        elif sim >= 0.50:
            return {'status': 'SUSPICIOUS', 'confidence': sim, 'method': 'doi',
                    'details': f"DOI resolves but title differs (sim={sim:.2f}): '{found_title}'"}
        else:
            return {'status': 'SUSPICIOUS', 'confidence': sim, 'method': 'doi',
                    'details': f"Title mismatch (sim={sim:.2f}): '{found_title}'"}
    except urllib.error.HTTPError as e:
        if e.code == 404:
            # Try DataCite for arXiv DOIs
            if doi.startswith('10.48550/') or doi.startswith('10.5281/'):
                try:
                    url = f"https://api.datacite.org/dois/{urllib.parse.quote(doi, safe='')}"
                    req = urllib.request.Request(url, headers={
                        "User-Agent": "PaperDiscovery/2.0",
                        "Accept": "application/json"
                    })
                    with urllib.request.urlopen(req, timeout=15) as resp:
                        data = json.loads(resp.read().decode('utf-8'))

                    attrs = data.get('data', {}).get('attributes', {})
                    dc_titles = attrs.get('titles', [])
                    found_title = dc_titles[0].get('title', '') if dc_titles else ''
                    dc_creators = attrs.get('creators', [])
                    found_authors = [c.get('familyName', '') or c.get('name', '') for c in dc_creators if isinstance(c, dict)]
                    found_author_surnames = extract_found_author_surnames(found_authors)
                    a_overlap = author_overlap_ratio(expected_author_surnames, found_author_surnames)

                    if not found_title:
                        return {'status': 'HALLUCINATED', 'confidence': 0.95, 'method': 'doi',
                                'details': f'DOI {doi} resolves but title is missing in DataCite metadata'}

                    sim = title_similarity(expected_title, found_title)
                    if sim >= 0.80:
                        if expected_author_surnames and a_overlap == 0.0:
                            return {'status': 'SUSPICIOUS', 'confidence': sim, 'method': 'doi',
                                    'details': f"DataCite title match but author mismatch (overlap={a_overlap:.2f}): '{found_title}'"}
                        return {'status': 'VERIFIED', 'confidence': sim, 'method': 'doi',
                                'details': f"Confirmed via DataCite: '{found_title}'"}
                    elif sim >= 0.50:
                        return {'status': 'SUSPICIOUS', 'confidence': sim, 'method': 'doi',
                                'details': f"DataCite DOI differs (sim={sim:.2f}): '{found_title}'"}
                except:
                    pass
            return {'status': 'HALLUCINATED', 'confidence': 0.9, 'method': 'doi',
                    'details': f'DOI {doi} not found'}
        return None
    except Exception:
        return None

# L3a: Verify via OpenAlex title search
def verify_openalex(title, expected_author_surnames):
    """L3a verification via OpenAlex API."""
    try:
        search_title = title.replace(',', ' ').replace(':', ' ')
        params = urllib.parse.urlencode({
            'filter': 'title.search:' + search_title,
            'per_page': '5',
            'mailto': 'researchclaw@users.noreply.github.com'
        })
        url = f"https://api.openalex.org/works?{params}"

        req = urllib.request.Request(url, headers={
            "User-Agent": "PaperDiscovery/2.0",
            "Accept": "application/json"
        })
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode('utf-8'))

        results = data.get('results', [])
        if not results:
            return {'status': 'HALLUCINATED', 'confidence': 0.7, 'method': 'openalex',
                    'details': 'No results found via OpenAlex'}

        best_sim = 0.0
        best_title = ''
        best_auth_overlap = 0.0
        for r in results:
            found = r.get('title', '')
            if found:
                sim = title_similarity(title, found)
                if sim > best_sim:
                    best_sim = sim
                    best_title = found
                    oa_auth = [
                        a.get('author', {}).get('display_name', '')
                        for a in r.get('authorships', [])
                        if isinstance(a, dict)
                    ]
                    best_auth_overlap = author_overlap_ratio(
                        expected_author_surnames,
                        extract_found_author_surnames(oa_auth),
                    )

        if best_sim >= 0.80:
            if expected_author_surnames and best_auth_overlap == 0.0:
                return {'status': 'SUSPICIOUS', 'confidence': best_sim, 'method': 'openalex',
                        'details': f"Title match but author mismatch (overlap={best_auth_overlap:.2f}): '{best_title}'"}
            return {'status': 'VERIFIED', 'confidence': best_sim, 'method': 'openalex',
                    'details': f"Confirmed via OpenAlex: '{best_title}'"}
        elif best_sim >= 0.50:
            return {'status': 'SUSPICIOUS', 'confidence': best_sim, 'method': 'openalex',
                    'details': f"Partial match (sim={best_sim:.2f}): '{best_title}'"}
        else:
            return {'status': 'HALLUCINATED', 'confidence': 0.7, 'method': 'openalex',
                    'details': f"Best match too weak (sim={best_sim:.2f}): '{best_title}'"}
    except Exception:
        return None

# L3b: Verify via S2 title search (last resort)
def verify_s2_title(title, expected_author_surnames):
    """L3b verification via Semantic Scholar."""
    try:
        import subprocess
        result = subprocess.run(
            ['bash', os.path.join(os.environ['SCRIPT_DIR'], 's2_search.sh'), title, '5'],
            capture_output=True, text=True, encoding='utf-8', errors='ignore', timeout=30
        )
        papers = []
        for line in result.stdout.splitlines():
            line = line.strip()
            if not line or not line.startswith('{'):
                continue
            try:
                papers.append(json.loads(line))
            except Exception:
                continue

        if not papers:
            return {'status': 'HALLUCINATED', 'confidence': 0.6, 'method': 's2_title',
                    'details': 'No results found via S2'}

        best_sim = 0.0
        best_title = ''
        best_auth_overlap = 0.0
        for p in papers:
            found = p.get('title', '')
            if found:
                sim = title_similarity(title, found)
                if sim > best_sim:
                    best_sim = sim
                    best_title = found
                    s2_auth = [a.get('name', '') for a in p.get('authors', []) if isinstance(a, dict)]
                    best_auth_overlap = author_overlap_ratio(
                        expected_author_surnames,
                        extract_found_author_surnames(s2_auth),
                    )

        if best_sim >= 0.80:
            if expected_author_surnames and best_auth_overlap == 0.0:
                return {'status': 'SUSPICIOUS', 'confidence': best_sim, 'method': 's2_title',
                        'details': f"S2 title match but author mismatch (overlap={best_auth_overlap:.2f}): '{best_title}'"}
            return {'status': 'VERIFIED', 'confidence': best_sim, 'method': 's2_title',
                    'details': f"Found via S2: '{best_title}'"}
        elif best_sim >= 0.50:
            return {'status': 'SUSPICIOUS', 'confidence': best_sim, 'method': 's2_title',
                    'details': f"Partial S2 match (sim={best_sim:.2f}): '{best_title}'"}
        else:
            return {'status': 'HALLUCINATED', 'confidence': 0.6, 'method': 's2_title',
                    'details': f"Weak S2 match (sim={best_sim:.2f}): '{best_title}'"}
    except Exception:
        return None

def pick_best_result(candidates):
    """Choose final status from multiple verification attempts.

    Priority: VERIFIED > SUSPICIOUS > HALLUCINATED > SKIPPED,
    then by confidence descending within same status.
    """
    order = {
        'VERIFIED': 3,
        'SUSPICIOUS': 2,
        'HALLUCINATED': 1,
        'SKIPPED': 0,
    }
    valid = [c for c in candidates if c]
    if not valid:
        return None

    valid.sort(
        key=lambda r: (order.get(r.get('status', 'SKIPPED'), 0), float(r.get('confidence', 0.0))),
        reverse=True,
    )
    best = dict(valid[0])

    evidence_chain = [
        f"{r.get('method', 'unknown')}:{r.get('status', 'SKIPPED')}({float(r.get('confidence', 0.0)):.2f})"
        for r in valid
    ]
    best['evidence_chain'] = evidence_chain
    if len(evidence_chain) > 1:
        details = best.get('details', '')
        best['details'] = f"{details} | Evidence: {'; '.join(evidence_chain)}".strip()

    return best

# Main execution
if __name__ == '__main__':
    # Load entries
    entries = json.load(open(os.path.join(os.environ['TMP_DIR'], 'entries.json')))
    results = []
    stats = {'VERIFIED': 0, 'SUSPICIOUS': 0, 'HALLUCINATED': 0, 'SKIPPED': 0}
    warning_stats = {'author_mismatch': 0, 'url_redirect': 0}

    # Adaptive delays
    DELAY_CROSSREF = 0.3
    DELAY_OPENALEX = 0.2
    DELAY_ARXIV = 1.0

    for i, entry in enumerate(entries):
        key = entry.get('key', f'unknown_{i}')
        title = entry.get('title', '')
        arxiv_id = entry.get('eprint', '')
        doi = entry.get('doi', '')
        url = entry.get('url', '')
        expected_author_surnames = extract_expected_author_surnames(entry.get('author', ''))

        print(f"[verify] [{i+1}/{len(entries)}] {key[:30]}...", file=sys.stderr, flush=True)

        if not title:
            results.append({
                'cite_key': key, 'title': '', 'status': 'SKIPPED',
                'confidence': 0.0, 'method': 'skipped', 'details': 'No title in entry'
            })
            stats['SKIPPED'] += 1
            continue

        if not doi and not arxiv_id:
            results.append({
                'cite_key': key, 'title': title, 'status': 'HALLUCINATED',
                'confidence': 0.95, 'method': 'strict_identifier',
                'details': 'Missing both DOI and arXiv ID'
            })
            stats['HALLUCINATED'] += 1
            continue

        # Check cache
        cache_identity = doi if doi else f"arxiv:{arxiv_id}"
        cached = read_cache(title, cache_identity)
        if cached:
            cached['cite_key'] = key
            results.append(cached)
            stats[cached['status']] += 1
            print(f"  [cache] {cached['status']}", file=sys.stderr)
            continue

        attempts = []
        api_calls = 0

        # arXiv-only entries are valid: verify by arXiv ID first and treat it as primary evidence.
        if (not doi) and arxiv_id:
            r = verify_arxiv_id(arxiv_id, title, expected_author_surnames)
            api_calls += 1
            if r:
                attempts.append(r)
                print(f"  L1 arXiv ID (primary) -> {r['status']} ({r['confidence']:.2f})", file=sys.stderr)

            result = pick_best_result(attempts)
            if result is None:
                result = {'status': 'SKIPPED', 'confidence': 0.0, 'method': 'arxiv_id',
                          'details': 'arXiv verification failed due to network/API error'}

            if result.get('status') != 'VERIFIED':
                result['details'] = f"arXiv-only contract failed: {result.get('details', '')}".strip()

            if url:
                u = verify_url_redirect(url, doi=doi, arxiv_id=arxiv_id)
                if u.get('warning'):
                    warning_stats['url_redirect'] += 1
                    result['details'] = (result.get('details', '') + f" | URL warning: {u.get('reason', '')}").strip()
                    if result.get('status') == 'VERIFIED':
                        result['status'] = 'SUSPICIOUS'
                        result['confidence'] = min(float(result.get('confidence', 0.0)), 0.79)

            result['cite_key'] = key
            result['title'] = title
            results.append(result)
            stats[result['status']] += 1
            if result['status'] != 'SKIPPED':
                write_cache(title, cache_identity, result)
            continue

        # L2: DOI verification (fast, generous limits) - try first
        if doi:
            if api_calls > 0:
                time.sleep(DELAY_CROSSREF)
            r = verify_doi(doi, title, expected_author_surnames)
            api_calls += 1
            if r:
                attempts.append(r)
                print(f"  L2 DOI -> {r['status']} ({r['confidence']:.2f})", file=sys.stderr)

        strong_verified = any(r.get('status') == 'VERIFIED' and float(r.get('confidence', 0.0)) >= 0.90 for r in attempts)

        # L3a: OpenAlex title search (high rate limits)
        if not strong_verified:
            if api_calls > 0:
                time.sleep(DELAY_OPENALEX)
            r = verify_openalex(title, expected_author_surnames)
            api_calls += 1
            if r:
                attempts.append(r)
                print(f"  L3a OpenAlex -> {r['status']} ({r['confidence']:.2f})", file=sys.stderr)

        strong_verified = strong_verified or any(r.get('status') == 'VERIFIED' and float(r.get('confidence', 0.0)) >= 0.90 for r in attempts)

        # L1: arXiv ID verification if available and not already strongly verified
        if arxiv_id and not strong_verified:
            if api_calls > 0:
                time.sleep(DELAY_ARXIV)
            r = verify_arxiv_id(arxiv_id, title, expected_author_surnames)
            api_calls += 1
            if r:
                attempts.append(r)
                print(f"  L1 arXiv ID -> {r['status']} ({r['confidence']:.2f})", file=sys.stderr)

        # L3b: S2 title search as final arbiter when no VERIFIED evidence exists
        if not any(r.get('status') == 'VERIFIED' for r in attempts):
            r = verify_s2_title(title, expected_author_surnames)
            api_calls += 1
            if r:
                attempts.append(r)
                print(f"  L3b S2 -> {r['status']} ({r['confidence']:.2f})", file=sys.stderr)

        result = pick_best_result(attempts)

        # Fallback: all methods failed
        if result is None:
            result = {'status': 'SKIPPED', 'confidence': 0.0, 'method': 'skipped',
                      'details': 'All verification methods failed (network error)'}
            print(f"  [failed] All methods failed", file=sys.stderr)

        # URL secondary consistency check (can downgrade VERIFIED to SUSPICIOUS)
        if url:
            u = verify_url_redirect(url, doi=doi, arxiv_id=arxiv_id)
            if u.get('warning'):
                warning_stats['url_redirect'] += 1
                result['details'] = (result.get('details', '') + f" | URL warning: {u.get('reason', '')}").strip()
                if result.get('status') == 'VERIFIED':
                    result['status'] = 'SUSPICIOUS'
                    result['confidence'] = min(float(result.get('confidence', 0.0)), 0.79)

        if 'author mismatch' in str(result.get('details', '')).lower():
            warning_stats['author_mismatch'] += 1

        result['cite_key'] = key
        result['title'] = title
        results.append(result)
        stats[result['status']] += 1

        # Cache result (skip SKIPPED from network failures)
        if result['status'] != 'SKIPPED':
            write_cache(title, cache_identity, result)

    # Calculate integrity score
    verifiable = len(entries) - stats['SKIPPED']
    integrity = round(stats['VERIFIED'] / verifiable, 3) if verifiable > 0 else 1.0

    report = {
        'summary': {
            'total': len(entries),
            'verified': stats['VERIFIED'],
            'suspicious': stats['SUSPICIOUS'],
            'hallucinated': stats['HALLUCINATED'],
            'skipped': stats['SKIPPED'],
            'author_mismatch_warnings': warning_stats['author_mismatch'],
            'url_redirect_warnings': warning_stats['url_redirect'],
            'integrity_score': integrity,
            'verifiable_rate': f"{verifiable}/{len(entries)}"
        },
        'results': results
    }

    print(json.dumps(report, indent=2))
    print(f"\n[verify] Summary: {stats['VERIFIED']} VERIFIED, {stats['SUSPICIOUS']} SUSPICIOUS, "
          f"{stats['HALLUCINATED']} HALLUCINATED, {stats['SKIPPED']} SKIPPED", file=sys.stderr)
    print(f"[verify] Integrity score: {integrity:.1%}", file=sys.stderr)
PYEOF

# Execute the Python script and handle output
if [[ "$OUTPUT_FILE" == "-" ]]; then
    "$PYTHON_BIN" "$TMP_DIR/verifier.py"
else
    "$PYTHON_BIN" "$TMP_DIR/verifier.py" > "$OUTPUT_FILE"
    echo "[verify] Report saved to: $OUTPUT_FILE" >&2
fi
