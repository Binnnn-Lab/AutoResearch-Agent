# Step 04 - Dedup and Triage

## ⛔ PREREQUISITE GATE (DO NOT PROCEED IF FAILED)

**Before reading this file, Step 03 MUST be complete:**
- Step 03 checkpoint: `executed=true`
- Step 03 status: `ok`
- ALL 4 sources executed: OpenAlex, Semantic Scholar, arXiv, Google Scholar (2025-2026)
- Source results files produced

**If Step 03 not complete**: STOP. Go back and finish Step 03 first.

---


## Required Actions

1. Merge all source outputs.
2. Deduplicate in order:
   - DOI exact match
   - arXiv ID match
   - normalized title similarity
3. Keep provenance fields on each paper:
   - source list
   - query origin
   - dedup reason
4. Build triage buckets:
   - core
   - supporting
   - suspicious

## Evidence

- candidate count before dedup
- candidate count after dedup
- dropped duplicates count
- triage distribution

## Detailed Guidance (Restored)

### Dedup priority and retention

1. DOI exact match (strongest identity)
2. arXiv ID exact match
3. normalized title similarity (Jaccard/fuzzy title threshold)

When duplicates are found, prefer the record with:

- richer metadata (doi/url/pdf_url/authors/year)
- higher citation signal when available
- stronger source provenance (multi-source hit)

### Triage buckets

- core: directly answers research question and should enter main review
- supporting: useful context or secondary baseline
- suspicious: weak or conflicting metadata, needs manual re-check
