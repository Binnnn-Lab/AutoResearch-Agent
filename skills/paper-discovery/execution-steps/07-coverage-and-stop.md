# Step 07 - Coverage and Stop Decision

## Visualizer Status Hook (Required)

Before starting Step 07, MUST run:

`bash -lc 'source scripts/init.sh; write_status running "覆盖性检查"'`

After Step 07 completes, MUST run:

`bash -lc 'source scripts/init.sh; write_status done "覆盖性检查"'`

If blocked/failed, MUST run:

`bash -lc 'source scripts/init.sh; write_status error "覆盖性检查"'`

## ⛔ PREREQUISITE GATE (DO NOT PROCEED IF FAILED)

**Before reading this file, Step 06 MUST be complete:**
- Step 06 checkpoint: `executed=true`
- Step 06 status: `ok`
- Zotero ingest completed
- `actual_imported_count` reported

**If Step 06 not complete**: STOP. Go back and finish Step 06 first.

---

## Required Coverage Checks

- survey/review covered
- recent top-venue works covered
- seminal baselines covered
- benchmark/dataset/evaluation covered
- major threat-model or defense lines covered
- **target count achieved (if user-specified)**

## Required Actions

1. Count current verified papers:
   - VERIFIED count from verification report
   - SUSPICIOUS count (optional, if user allows)
   - Total unique papers available for ingest

2. Compare with target_count from scope_plan:
   - If `count >= target_count`: proceed to Step 08
   - If `count < target_count`: evaluate continuation options

3. Produce a coverage statement with:
   - covered types
   - covered venues
   - evidence-sufficient directions
   - likely-missing directions
   - **current count vs target count**
   - stop or continue decision with reason

4. If key category missing OR target count not met, continue retrieval loop from Step 02.

## Target Count Enforcement (New)

### Hard Constraint Mode
When `count_hard_constraint=true` (user explicitly specified target):

1. **Count Check Point:**
   ```
   VERIFIED_count = count of VERIFIED papers
   SUSPICIOUS_count = count of SUSPICIOUS papers (if INCLUDE_SUSPICIOUS=true)
   Total = VERIFIED_count + SUSPICIOUS_count
   ```

2. **Decision Matrix:**
   
   | Total vs Target | Action |
   |----------------|--------|
   | Total >= Target | Proceed to Step 08 (coverage satisfied) |
   | Total < Target AND gap < 20% | Expand search (Step 02) with broader queries |
   | Total < Target AND gap >= 20% | **ASK USER** for decision |

3. **User Consultation Required When:**
   - After 3 retrieval cycles and still below target
   - Gap >= 20% of target
   - No new papers found in last cycle
   - All sources exhausted

4. **Ask User Template:**
   ```
   目标论文数: {target_count}
   当前已验证: {VERIFIED_count}
   可疑待复核: {SUSPICIOUS_count}
   缺口: {gap} 篇 ({gap_percent}%)
   
  已尝试:
   - 查询轮次: {cycles}
   - 搜索源: {sources_attempted}
   - 覆盖年份: {year_range}
   
   请选择:
   [A] 继续扩展搜索 (添加相关关键词/扩展年份)
   [B] 接受当前数量 ({Total}篇)，继续生成报告
   [C] 降低目标数量到 {suggested_count}
   [D] 提供种子论文，通过引用扩展
   ```

### Soft Constraint Mode
When `count_hard_constraint=false` (default targets):

- Follow original coverage-based stopping criteria
- Target count serves as guidance only
- Prioritize quality and coverage over exact count

## Retrieval Loop Management

### Loop Counter
- Track number of retrieval cycles
- Max 5 cycles before forced user consultation
- Each cycle must produce new papers (≥1 VERIFIED)

### Expansion Strategies (when count < target)
1. **Query expansion**: Add broader synonyms, remove specific constraints
2. **Source expansion**: Use S2 recommend/citations/references for seed papers
3. **Year expansion**: Extend year range backward/forward
4. **Venue expansion**: Relax venue constraints
5. **Type expansion**: Include more paper types (workshops, preprints)

## Hard Rule

Do not stop only because a small number of good papers were found.

**When target count is specified: Do not stop until target is met OR user explicitly approves lower count.**

## Detailed Guidance (Restored)

### Stop-check checklist

- survey/review coverage confirmed
- recent top-venue coverage confirmed
- seminal baseline coverage confirmed
- benchmark/dataset/evaluation coverage confirmed
- major threat/defense lines covered
- **target count achieved (if applicable)**

### Continue when missing

- If any key category is missing, return to Step 02 and run another retrieval cycle.
- If target count not met, return to Step 02 with expanded queries.
- Explicitly report what is still missing and which query/source branch will be used to补齐.

### Required final statement

Before stopping, provide:

- covered paper types
- covered venues
- directions with strong evidence
- likely missing directions
- **actual count vs target count**
- explicit reason to stop now
