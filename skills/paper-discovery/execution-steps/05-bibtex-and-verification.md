# Step 05 - BibTeX and Verification

## Visualizer Status Hook (Required)

Before starting Step 05, MUST run:

`bash -lc 'source scripts/init.sh; write_status running "BibTeX 与验证"'`

After Step 05 completes, MUST run:

`bash -lc 'source scripts/init.sh; write_status done "BibTeX 与验证"'`

If blocked/failed, MUST run:

`bash -lc 'source scripts/init.sh; write_status error "BibTeX 与验证"'`

## ⛔ PREREQUISITE GATE (DO NOT PROCEED IF FAILED)

**Before reading this file, Step 04 MUST be complete:**
- Step 04 checkpoint: `executed=true`
- Step 04 status: `ok`
- Deduplicated candidates produced
- Triage buckets: core/supporting/suspicious

**If Step 04 not complete**: STOP. Go back and finish Step 04 first.

---


## Required Actions

1. Generate BibTeX from deduplicated candidates using `scripts/generate_bibtex.sh`.
2. Verify using `scripts/verify_citations.sh`.
3. Filter verified entries using `scripts/filter_verified.sh`.
4. Keep suspicious entries separately.

## Hard Rules

1. Formal bibliography output cannot skip verification.
2. **BLOCKING**: Step 05 MUST produce `verification_report` with VERIFIED/SUSPICIOUS/HALLUCINATED classification before proceeding to Step 06.
3. Only VERIFIED entries can be imported to Zotero in Step 06.
4. SUSPICIOUS entries must be kept in a separate review list, NOT imported to main Zotero collection.

## Explicit Verification Contract (Restored)

Apply checks to all candidate entries:

1. Title exists.
2. Identifier exists: DOI or arXiv ID (at least one).
3. If DOI exists, DOI-resolved title must match candidate title above threshold.

### Decision policy

- VERIFIED: checks passed with strong evidence
- SUSPICIOUS: partial/weak match or warnings
- HALLUCINATED: identifier missing, unresolved, or strong mismatch
- SKIPPED: temporary network/tool failure

### Output policy for formal references

- `references.bib` should include verification-approved entries under active policy.
- Keep suspicious entries in a separate review list/report section.

## Evidence

- generated bib entry count
- verified count
- suspicious count
- verification artifact path(s)
