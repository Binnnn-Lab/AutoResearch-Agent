# Step 03 - Multi-Source Search (MANDATORY FOUR-SOURCE EXECUTION)

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

### Source 1: OpenAlex (MANDATORY)

Purpose: Primary academic paper retrieval

```
scripts/openalex_search.sh <query> <limit>
```

**MUST execute regardless of any other considerations**

### Source 2: Semantic Scholar (MANDATORY)

Purpose: Extended academic paper coverage

```
scripts/s2_search.sh <query> <limit>
OR
scripts/s2_bulk_search.sh <query> <limit>
```

**MUST execute even if OpenAlex returned 100+ papers**
**MUST execute even if OpenAlex returned 0 papers**

### Source 3: arXiv (MANDATORY)

Purpose: Preprint and cutting-edge research retrieval

```
scripts/arxiv_search.sh <query> <limit>
```

**MUST execute even if OpenAlex + S2 already covered the topic**
**MUST execute even if previous sources returned empty results**

### Source 4: Google Scholar (MANDATORY - NOT SUPPLEMENTARY)

Purpose: **REQUIRED** coverage of recent 2-year papers (2025-2026)

```
scripts/google_scholar_search.py <query> --years "2025,2026"
```

**THIS IS NOT OPTIONAL SUPPLEMENTATION**
**THIS IS A MANDATORY SOURCE for recent paper coverage**
**MUST execute regardless of results from all previous three sources**
**MUST use --years "2025,2026" flag to filter recent papers**

## Execution Evidence Requirements

For EACH source, MUST record:

```yaml
source_name: <OpenAlex|SemanticScholar|arXiv|GoogleScholar>
executed: true|false (MUST be true for all 4 at completion)
command_used: <exact command>
query: <search query>
papers_found: <count>
status: success|failed|empty
years_covered: <for Google Scholar: [2025, 2026]>
error_message: <if failed>
```

## Pre-Completion Verification Checklist

Before claiming Step 03 complete, MUST verify:

- [ ] OpenAlex: executed=true, papers_found >= 0
- [ ] Semantic Scholar: executed=true, papers_found >= 0
- [ ] arXiv: executed=true, papers_found >= 0
- [ ] Google Scholar: executed=true, papers_found >= 0, years="2025,2026"
- [ ] All four sources have execution evidence logged
- [ ] No source was skipped for ANY reason

## Hard Constraints

1. **FOUR-SOURCE MANDATE**: All four sources MUST be executed
2. **NO RESULT-BASED SKIP**: Cannot skip based on result count from previous sources
3. **GOOGLE SCHOLAR IS REQUIRED**: Not supplementary, not optional - mandatory for recent 2-year coverage
4. **YEAR FILTER ENFORCED**: Google Scholar MUST use --years "2025,2026"
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
5. `google_scholar_results.json` - Google Scholar results (MUST contain 2025-2026 papers)

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
Years: 2025-2026
Papers Found: 8
Status: success

=== VERIFICATION ===
All 4 sources executed: YES
Google Scholar year filter applied: YES (2025-2026)
Completion status: COMPLETE
```
