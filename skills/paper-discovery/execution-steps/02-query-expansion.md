# Step 02 - Query Expansion

## Visualizer Status Hook (Required)

Before starting Step 02, MUST run:

`bash -lc 'source scripts/init.sh; write_status running "查询扩展"'`

After Step 02 completes, MUST run:

`bash -lc 'source scripts/init.sh; write_status done "查询扩展"'`

If blocked/failed, MUST run:

`bash -lc 'source scripts/init.sh; write_status error "查询扩展"'`

## ⛔ PREREQUISITE GATE (DO NOT PROCEED IF FAILED)

**Before reading this file, Step 01 MUST be complete:**
- Step 01 checkpoint: `executed=true`
- Step 01 status: `ok`
- `scope_plan` object produced with target_count defined

**If Step 01 not complete**: STOP. Go back and finish Step 01 first.

---


## Required Actions

1. Run `scripts/expand_queries.sh` for normalized topic.
2. Keep original semantic queries plus expanded variants.
3. Remove obvious duplicate queries.
4. Keep query intent labels (survey, benchmark, recent, seminal, threat/defense).

## Evidence

- Expanded query list with labels.
- Actual command used.

## Hard Rule

No source retrieval in this step. Only query construction.

## Detailed Guidance (Restored)

### Query construction principles

- Prefer semantic intent over keyword stacking.
- Convert Chinese requirements into concise English research queries.
- Keep balanced intent buckets: survey, benchmark/dataset, seminal, recent, threat/defense.

### Recommended combinations

- task + method
- task + benchmark/dataset
- method + constraint/threat model
- task + survey/review
- task + year constraint

### Example intents

- security survey: "llm security survey prompt injection jailbreak defense"
- core methods: "network intrusion detection graph neural network security"
- recent works: "software supply chain security attack defense 2024 2025"
- cross-domain: "adversarial robustness large language model security benchmark"
