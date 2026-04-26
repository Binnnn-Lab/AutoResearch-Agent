# Step 01 - Scope Normalization

## ⛔ PREREQUISITE GATE (DO NOT PROCEED IF FAILED)

**Before reading this file, Step 00 MUST be complete:**
- Step 00 checkpoint: `executed=true`
- Step 00 status: `ok` or `blocked`
- Preflight tools confirmed available

**If Step 00 not complete**: STOP. Go back and finish Step 00 first.

---


## Input Slots (must fill)

- topic/problem
- method/angle
- must-have coverage
- exclude scope
- year range
- paper types
- venue preferences
- target count
- output goal

## Required Actions

1. Normalize user request into the 9 slots above.
2. State assumptions for missing slots.
3. Convert to 2-4 English semantic queries.
4. Define stop criteria for coverage before retrieval starts.
5. **Explicitly confirm target_count with user if not specified.**

## Target Count Hard Constraints (New)

### User-Specified Target
- If user explicitly specifies paper count (e.g., "找30篇", "need 50 papers"), record as `target_count`.
- **MUST** treat this as hard constraint - do not stop until target is met or user explicitly approves lower count.

### Default Targets (when not specified)
- Survey/state-of-the-art tasks: 30-50 papers
- Broad mapping: 50-100 papers
- Focused review: 20-30 papers
- Quick overview: 10-15 papers

### Fallback Policy (when target cannot be met)
If retrieval cannot meet target count after exhausting all sources:

1. **STOP** - do not proceed to next step automatically
2. **Report to user:**
   - Target count requested
   - Actual papers found (with breakdown: VERIFIED / SUSPICIOUS)
   - Search coverage attempted
   - Gap analysis (why target not met)
3. **Provide options:**
   - Option A: Continue with fewer papers (report actual count)
   - Option B: Expand search scope (broader queries, more sources)
   - Option C: Relax constraints (remove year/venue filters)
   - Option D: Add seed papers for citation expansion
4. **Wait for user decision** before proceeding

## Detailed Guidance (Restored)

### Default venue priorities

- Core security venues: IEEE S&P, USENIX Security, CCS, NDSS
- Extended security venues: EuroS&P, ACSAC, RAID, AsiaCCS, SOUPS, PETS
- Adjacent systems/network venues: SOSP, OSDI, NSDI, SIGCOMM, IMC
- Add ML/NLP/CV venues only when topic is cross-domain (NeurIPS, ICML, ICLR, ACL, EMNLP, CVPR)

### Default time windows

- Survey/state-of-the-art tasks: recent 3 years + necessary seminal works
- Broad mapping: 50-100 candidates
- Focused review: 20-50 candidates

### Inclusion / exclusion checklist

- Include: top venues, direct relevance, explicit threat model/method, comparable evaluation setup
- Exclude: marginal relevance, no meaningful experiment, threat-model mismatch, duplicate routes without incremental value

### Route selection (operational)

- Topic-only request: run broad multi-source route first, then graph expansion
- Seed-paper request: resolve seed metadata first, then run broad route and graph补漏
- Related-work/survey request: force coverage on survey + seminal + recent + benchmark categories

## Output Artifact

- `scope_plan` object in response (or temp JSON file).
- `scope_plan` must include: selected route, venue scope, year window, **target_count**, **count_hard_constraint** (true/false), and stop criteria.
