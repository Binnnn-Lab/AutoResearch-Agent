# Step 03 - Multi-Source Search (MANDATORY FOUR-SOURCE EXECUTION)

## Visualizer Status Hook (Required)

Before starting Step 03, MUST run:

`bash -lc 'source scripts/init.sh; write_status running "多源检索"'`

After Step 03 completes, MUST run:

`bash -lc 'source scripts/init.sh; write_status done "多源检索"'`

If blocked/failed, MUST run:

`bash -lc 'source scripts/init.sh; write_status error "多源检索"'`

## ⛔ PREREQUISITE GATE (DO NOT PROCEED IF FAILED)

**Before reading this file, Step 02 MUST be complete:**
- Step 02 checkpoint: `executed=true`
- Step 02 status: `ok`
- Expanded queries list with labels produced

**If Step 02 not complete**: STOP. Go back and finish Step 02 first.

---


## EXECUTION ENFORCEMENT (AUTOMATIC)

**WHEN this skill is triggered, Claude Code MUST:**

1. **Automatically identify** this as a paper-discovery task requiring multi-source search
2. **Execute ALL four sources** in strict order without waiting for user confirmation between sources
3. **NEVER ask user** "Should I continue to next source?" or "Is this enough papers?"
4. **Complete full sequence** (OpenAlex → S2 → arXiv → Google Scholar) before proceeding to next step
5. **Self-enforce**: Even if user says "find some papers" or "search for X", still execute ALL four sources

**Natural language triggers that MUST activate full 4-source execution:**

- "帮我找论文" / "找相关论文"
- "paper discovery" / "search for papers"
- "文献调研" / "查找相关工作"
- Any request involving finding academic papers

**NO EXCEPTIONS**: User does NOT need to explicitly say "use all four sources" - this is automatic.

## CRITICAL RULE: NO SOURCE SKIPPING ALLOWED

**ALL FOUR sources MUST be executed, NO EXCEPTIONS:**

- Cannot skip any source because previous sources returned "enough" results
- Cannot skip any source because previous sources returned empty results
- Cannot skip Google Scholar - it is REQUIRED for recent 2-year coverage
- Early termination is STRICTLY PROHIBITED

## Required Source Order (STRICT)

## Mandatory Execution Entry (Status Write-Back Required)

Claude Code MUST execute Step 03 through the repository wrapper below so visualizer status updates are emitted:

```
scripts/multi_search.sh <query> <limit> <year_min>
```

Reason: `multi_search.sh` sources `scripts/init.sh` and continuously calls `write_status_json` for source/sub-step progress.
Directly calling raw source scripts as the primary path is NOT allowed in visualizer mode.

### Source 1: OpenAlex (MANDATORY)

Purpose: Primary academic paper retrieval

`multi_search.sh` internally executes OpenAlex in required order.

**MUST execute regardless of any other considerations**

### Source 2: Semantic Scholar (MANDATORY)

Purpose: Extended academic paper coverage

`multi_search.sh` internally executes Semantic Scholar in required order.

**MUST execute even if OpenAlex returned 100+ papers**
**MUST execute even if OpenAlex returned 0 papers**

### Source 3: arXiv (MANDATORY)

Purpose: Preprint and cutting-edge research retrieval

`multi_search.sh` internally executes arXiv in required order.

**MUST execute even if OpenAlex + S2 already covered the topic**
**MUST execute even if previous sources returned empty results**

### Source 4: Google Scholar (MANDATORY - NOT SUPPLEMENTARY)

Purpose: **REQUIRED** coverage of recent 2-year papers (current year and previous year)

`multi_search.sh` internally executes Google Scholar in required order.

**THIS IS NOT OPTIONAL SUPPLEMENTATION**
**THIS IS A MANDATORY SOURCE for recent paper coverage**
**MUST execute regardless of results from all previous three sources**
**MUST use --years flag with current year and previous year to filter recent papers**

> **Note**: Replace `<current_year-1>` and `<current_year>` with actual years. For example, if current year is 2026, use `--years "2025,2026"`.

## Execution Evidence Requirements

For EACH source, MUST record:

```yaml
source_name: <OpenAlex|SemanticScholar|arXiv|GoogleScholar>
executed: true|false (MUST be true for all 4 at completion)
command_used: <exact command>
query: <search query>
papers_found: <count>
status: success|failed|empty
years_covered: <for Google Scholar: [current_year-1, current_year]>
error_message: <if failed>
```

## Pre-Completion Verification Checklist

Before claiming Step 03 complete, MUST verify:

- [ ] OpenAlex: executed=true, papers_found >= 0
- [ ] Semantic Scholar: executed=true, papers_found >= 0
- [ ] arXiv: executed=true, papers_found >= 0
- [ ] Google Scholar: executed=true, papers_found >= 0, years="<current_year-1>,<current_year>"
- [ ] All four sources have execution evidence logged
- [ ] No source was skipped for ANY reason

## Hard Constraints

1. **FOUR-SOURCE MANDATE**: All four sources MUST be executed
2. **NO RESULT-BASED SKIP**: Cannot skip based on result count from previous sources
3. **GOOGLE SCHOLAR IS REQUIRED**: Not supplementary, not optional - mandatory for recent 2-year coverage
4. **YEAR FILTER ENFORCED**: Google Scholar MUST use --years with current year and previous year (e.g., "2025,2026" when in 2026)
5. **CONTINUE ON FAILURE**: If one source fails, continue to next, mark failure in log

## Failure Handling

If any source fails:

1. Record failure with error message
2. **CONTINUE to next source immediately**
3. Do NOT retry (unless explicitly instructed)
4. Report all failures in final evidence

## Output Artifacts

1. `source_execution_log.md` - Execution record for all four sources
2. `openalex_results.json` - OpenAlex results
3. `semantic_scholar_results.json` - S2 results
4. `arxiv_results.json` - arXiv results
5. `google_scholar_results.json` - Google Scholar results (MUST contain papers from recent 2 years: current year and previous year)

## Example Execution Log Format

```
=== SOURCE EXECUTION LOG ===

[Source 1: OpenAlex]
Status: EXECUTED
Query: state machine bug detection protocol
Papers Found: 30
Status: success

[Source 2: Semantic Scholar]
Status: EXECUTED
Query: state machine bug detection protocol
Papers Found: 25
Status: success

[Source 3: arXiv]
Status: EXECUTED
Query: state machine bug detection protocol
Papers Found: 10
Status: success

[Source 4: Google Scholar]
Status: EXECUTED
Query: state machine bug detection protocol
Years: <current_year-1>-<current_year> (e.g., 2025-2026 when in 2026)
Papers Found: 8
Status: success

=== VERIFICATION ===
All 4 sources executed: YES
Google Scholar year filter applied: YES (recent 2-year coverage)
Completion status: COMPLETE
```
