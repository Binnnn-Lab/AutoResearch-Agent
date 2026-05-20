#!/usr/bin/env bash
# Generate unified BibTeX from multi-source search results
# Usage: bash generate_bibtex.sh <papers.json> [output.bib|-]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./init.sh
source "$SCRIPT_DIR/init.sh"

# Emit visualizer status: starting BibTeX generation
write_status "running" "BibTeX 与验证"

PAPERS_FILE="${1:-}"
OUTPUT_FILE="${2:--}"

if [ -z "$PAPERS_FILE" ] || { [ "$PAPERS_FILE" != "-" ] && [ ! -f "$PAPERS_FILE" ]; }; then
    echo "Usage: generate_bibtex.sh <papers.json|-> [output.bib|-]" >&2
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
cat > "$TMP_DIR/generator.py" << 'GENERATOR'
import json
import re
import sys
import os

CONFERENCE_KEYWORDS = {
    'conference', 'symposium', 'workshop', 'proceedings', 'usenix', 'ccs',
    'ndss', 'ieee s&p', 'ieee sp', 'security and privacy', 'eurosp',
    'asiaccs', 'acsac', 'raid'
}


def infer_entry_type(paper):
    """Infer BibTeX entry type from metadata."""
    publication_type = str(paper.get('publication_type', '') or '').strip().lower()
    venue = str(paper.get('venue', '') or '').strip().lower()

    if paper.get('arxiv_id'):
        return 'misc'

    if publication_type in {'proceedings-article', 'conference-paper', 'conference'}:
        return 'inproceedings'

    if publication_type in {'preprint', 'posted-content'}:
        return 'misc'

    if any(k in venue for k in CONFERENCE_KEYWORDS):
        return 'inproceedings'

    return 'article'


def derive_best_url(paper):
    """Build a stable URL fallback chain for importers."""
    url = str(paper.get('url', '') or '').strip()
    if url:
        return url

    doi = str(paper.get('doi', '') or '').strip()
    if doi:
        return f"https://doi.org/{doi}"

    arxiv_id = str(paper.get('arxiv_id', '') or '').strip()
    if arxiv_id:
        return f"https://arxiv.org/abs/{arxiv_id}"

    pdf_url = str(paper.get('pdf_url', '') or '').strip()
    if pdf_url:
        return pdf_url

    return ''

def clean_for_bibtex(text):
    """Clean text for safe BibTeX entry."""
    if not text:
        return ""
    # Escape special characters
    text = str(text)
    text = text.replace('\\', '\\textbackslash{}')
    text = text.replace('{', '\\{')
    text = text.replace('}', '\\}')
    text = text.replace('&', '\\&')
    text = text.replace('%', '\\%')
    text = text.replace('$', '\\$')
    text = text.replace('#', '\\#')
    text = text.replace('_', '\\_')
    text = text.replace('^', '\\textasciicircum{}')
    text = text.replace('~', '\\textasciitilde{}')
    return text

def derive_cite_key(paper):
    """Derive a cite key from paper metadata."""
    # Try to get first author surname
    authors = paper.get('authors', [])
    surname = "unknown"
    if authors and isinstance(authors, list):
        first_author = authors[0]
        if isinstance(first_author, dict):
            name = first_author.get('name', '')
        else:
            name = str(first_author)
        if name:
            parts = name.split()
            surname = parts[-1].lower() if parts else "unknown"
            # Remove non-alphanumeric
            surname = re.sub(r'[^a-z0-9]', '', surname)

    year = paper.get('year', 2024)

    # First 3 letters of first content word
    title = paper.get('title', 'study')
    words = [w for w in title.split() if len(w) > 3 and w.lower() not in {
        'the', 'and', 'for', 'with', 'from', 'that', 'this', 'these', 'those'
    }]
    title_abbr = ''.join(w[0].lower() for w in words[:3])

    return f"{surname}{year}{title_abbr}"

def to_bibtex(paper):
    """Convert paper dict to BibTeX entry."""
    entry_type = infer_entry_type(paper)

    cite_key = paper.get('cite_key', '') or derive_cite_key(paper)

    # Format authors
    authors = paper.get('authors', [])
    author_str = ""
    if authors:
        if isinstance(authors[0], dict):
            author_names = [a.get('name', '') for a in authors if a.get('name')]
        else:
            author_names = [str(a) for a in authors if a]
        author_str = " and ".join(author_names)

    lines = [f"@{entry_type}{{{cite_key}}},"]
    lines.append(f"  title = {{{clean_for_bibtex(paper.get('title', ''))}}},")

    if author_str:
        lines.append(f"  author = {{{clean_for_bibtex(author_str)}}},")

    if paper.get('year'):
        lines.append(f"  year = {{{paper['year']}}},")

    if paper.get('venue'):
        venue_value = clean_for_bibtex(paper['venue'])
        if entry_type == 'inproceedings':
            lines.append(f"  booktitle = {{{venue_value}}},")
        else:
            lines.append(f"  journal = {{{venue_value}}},")

    if paper.get('doi'):
        lines.append(f"  doi = {{{paper['doi']}}},")

    if paper.get('arxiv_id'):
        lines.append(f"  eprint = {{{paper['arxiv_id']}}},")
        lines.append(f"  archivePrefix = {{arXiv}},")

    best_url = derive_best_url(paper)
    if best_url:
        lines.append(f"  url = {{{best_url}}},")

    if paper.get('pdf_url'):
        lines.append(f"  pdf = {{{paper['pdf_url']}}},")

    # Add note about source
    sources = paper.get('sources_found', [paper.get('source', 'unknown')])
    if best_url:
        lines.append(f"  note = {{Sources: {', '.join(sources)}; Original URL: {best_url}}},")
    else:
        lines.append(f"  note = {{Sources: {', '.join(sources)}}},")

    lines.append("}")
    return "\n".join(lines)

# Load papers
pf = os.environ.get('PAPERS_FILE', '')
if pf == '-':
    data = json.load(sys.stdin)
else:
    with open(pf, encoding='utf-8') as f:
        data = json.load(f)
papers = data.get('papers', [])

print(f"% BibTeX generated from multi-source search")
print(f"% Total papers: {len(papers)}")
print(f"% Sources: OpenAlex, Semantic Scholar, arXiv")
print("")

for paper in papers:
    print(to_bibtex(paper))
    print("")

print(f"% End of file", file=sys.stderr)
print(f"[bibtex] Generated {len(papers)} BibTeX entries", file=sys.stderr)
GENERATOR

# Set environment variable and execute
export PAPERS_FILE="$PAPERS_FILE"

if [[ "$OUTPUT_FILE" == "-" ]]; then
    "$PYTHON_BIN" "$TMP_DIR/generator.py"
else
    "$PYTHON_BIN" "$TMP_DIR/generator.py" > "$OUTPUT_FILE"
    echo "[bibtex] Saved to: $OUTPUT_FILE" >&2
fi

# Emit visualizer status: finished BibTeX generation
if [[ "$OUTPUT_FILE" != "-" ]]; then
    write_status_json "{\"state\":\"done\",\"main_step\":\"BibTeX 与验证\",\"artifacts\":[\"$OUTPUT_FILE\"],\"executed\":true}"
else
    write_status "done" "BibTeX 与验证"
fi
