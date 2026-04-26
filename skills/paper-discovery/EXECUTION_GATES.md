# Claude Code Step Gates (Hard Order)

This file defines a strict, file-by-file execution order for Claude Code.
Goal: prevent step skipping, order changes, and hidden implicit execution.

Authority rule: this file and `execution-steps/*.md` are the only authoritative execution source.
If any other markdown file conflicts, ignore the conflicting instruction.

## Hard Rules

1. Claude Code MUST read this file first in every paper-discovery task.
2. Claude Code MUST read exactly one step file before executing that step.
3. Claude Code MUST finish the current step and produce evidence, then move on.
4. Claude Code MUST NOT jump to later steps.
5. Claude Code MUST NOT call `scripts/run_pipeline.sh` in this gated mode.
6. **CRITICAL**: Step 04 (Dedup) and Step 05 (Verification) MUST complete before Step 06 (Zotero Ingest). No unverified papers can be imported.
7. If a step cannot be executed, Claude Code must stop, report blocker, and ask user whether to continue with fallback.

## Required Step Order (SEQUENTIAL LOCK)

**CRITICAL RULE**: Claude Code MUST NOT read the next step file until the current step is COMPLETE with evidence.

```
Step 00: 00-session-preflight.md
    ↓ [evidence checkpoint required]
Step 01: 01-scope-normalization.md  
    ↓ [evidence checkpoint required]
Step 02: 02-query-expansion.md
    ↓ [evidence checkpoint required]
Step 03: 03-multi-source-search.md
    ↓ [evidence checkpoint required]
Step 04: 04-dedup-and-triage.md
    ↓ [evidence checkpoint required]
Step 05: 05-bibtex-and-verification.md
    ↓ [evidence checkpoint required]
Step 06: 06-zotero-ingest.md
    ↓ [evidence checkpoint required]
Step 07: 07-coverage-and-stop.md
    ↓ [evidence checkpoint required]
Step 08: 08-deliverables.md
```

### Step Transition Rule

**BEFORE reading step N+1, step N MUST have:**
- `executed=true` in checkpoint
- Required artifacts produced
- Status = `ok` or `blocked` with reason

**VIOLATION**: Reading step N+1 before step N completion is a protocol breach.

## Multi-Source Search Hard Constraints (CRITICAL)

### FOUR-SOURCE MANDATORY EXECUTION (Step 03)

**ALL FOUR SOURCES MUST EXECUTE - NO EXCEPTIONS:**

1. **OpenAlex** - Primary academic source (MANDATORY)
2. **Semantic Scholar** - Extended academic coverage (MANDATORY - cannot skip even if OpenAlex returned 100 papers)
3. **arXiv** - Preprint repository (MANDATORY - cannot skip even if previous sources returned sufficient results)
4. **Google Scholar** - **MANDATORY** recent 2-year coverage (2025-2026) - **THIS IS NOT SUPPLEMENTARY**

### PROHIBITED BEHAVIORS (Will Fail Validation)

- Skipping S2 because "OpenAlex already found enough papers"
- Skipping arXiv because "previous sources covered the topic"
- Skipping Google Scholar because "it's just supplementary"
- Skipping any source because "others returned empty results"
- Early termination before all 4 sources complete

### Google Scholar Specific Requirements

- **Role**: Dedicated source for recent 2-year paper retrieval
- **Year Filter**: MUST use current year range (e.g., `--years "2025,2026"` when in 2026)
- **Execution**: MUST run regardless of results from first 3 sources
- **Not Optional**: Cannot be marked as "supplementary" or "optional"

## Step Evidence Contract

After each step, Claude Code must output a mini checkpoint:

- `step_id=<id>`
- `read_file_done=true`
- `executed=true|false`
- `artifacts=[...]`
- `commands=[...]`
- `status=ok|blocked|partial`
- `reason=<required when blocked/partial>`

Without this checkpoint, the step is considered incomplete.
