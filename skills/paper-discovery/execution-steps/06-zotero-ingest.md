# Step 06 - Zotero Ingest

## ⛔ PREREQUISITE GATE (DO NOT PROCEED IF FAILED)

**Before reading this file, Step 05 MUST be complete:**
- Step 05 checkpoint: `executed=true`
- Step 05 status: `ok`
- `verification_report` produced with VERIFIED/SUSPICIOUS/HALLUCINATED classification
- BibTeX generated and verified

**If Step 05 not complete**: STOP. Go back and finish Step 05 first.

---


## Preconditions

- **HARD DEPENDENCY**: Step 04 (Dedup) and Step 05 (Verification) MUST complete first.
- **VERIFICATION REQUIRED**: Must have `verification_report` with VERIFIED/SUSPICIOUS classification from Step 05.
- Run only after Step 00 preflight.
- Required tools: `create_collection`, `add_items_by_doi`, `find_and_attach_pdfs`.
- Must have target_count from Step 01 scope_plan for quantity tracking.
- **NO VERIFICATION = NO INGEST**: Unverified papers cannot be imported to Zotero.

## Required Actions

1. Count available papers before ingest:
   - VERIFIED papers count
   - SUSPICIOUS papers count (if INCLUDE_SUSPICIOUS=true)
   - Total available for import

2. Compare with target_count:
   - If Total < target_count: **STOP and report to user** before ingest
   - If Total >= target_count: proceed with ingest

3. Create numbered kebab-case sub-collections (3-5).
4. Ingest VERIFIED first by DOI.
5. Attach PDFs immediately.
6. Record URL for each imported item.
7. Optional: ingest SUSPICIOUS into a separate review bucket.
8. **Report actual import count vs target count.**

## Count Validation Before Ingest (New)

### Pre-Ingest Count Check
```
available_VERIFIED = count of VERIFIED papers from Step 05
available_SUSPICIOUS = count of SUSPICIOUS papers (optional)
total_available = available_VERIFIED + available_SUSPICIOUS
target_count = from scope_plan (Step 01)
```

### Decision Flow

| Condition | Action |
|-----------|--------|
| total_available >= target_count | Proceed with ingest |
| total_available < target_count AND count_hard_constraint=true | **ASK USER** - insufficient papers |
| total_available < target_count AND count_hard_constraint=false | Proceed with warning note |

### User Prompt (when insufficient papers)

```
Zotero导入前数量检查：

目标论文数: {target_count}
当前可导入: {total_available}
  - 已验证: {available_VERIFIED}
  - 可疑待复核: {available_SUSPICIOUS}
缺口: {target_count - total_available} 篇

选项：
[A] 继续导入现有论文 ({total_available}篇)
[B] 返回搜索，补充更多论文
[C] 降低目标数量至 {total_available}
```

## Ingest Progress Tracking (New)

### Batch-Level Counting
Track per-batch import counts:
- Batch number (e.g., "Batch 1/3")
- Papers in batch
- Successfully imported
- Failed imports
- Running total vs target

### Mid-Ingest Count Check
After each batch, report:
```
批次 {n} 完成: {imported_this_batch}/{batch_size} 成功
累计导入: {total_imported}/{target_count} ({percent}%)
剩余缺口: {remaining}
```

## Failure Recovery

If import fails after successful preflight:

1. re-run preflight once
2. retry failed batch once
3. report failure category counts:
   - tool-missing
   - permission
   - network
   - invalid-doi
   - rate-limit

## Evidence

- imported-by-doi count
- PDF-attached count
- URL-recorded count
- failed attachment reasons
- **target_count** (from scope_plan)
- **actual_imported_count**
- **gap_analysis** (if any)

## Detailed Guidance (Restored)

### Batch strategy

- Use batch ingest as default (recommended 20-50 entries per batch).
- Avoid per-paper confirmation loops unless user explicitly asks.
- **Track cumulative count toward target after each batch.**

### Collection taxonomy

- Build 3-5 numbered kebab-case sub-collections from current research question.
- Example style: `01-state-machine-bugs`, `02-protocol-inference-and-spec-mining`.

### Standard ingest report fields

- total candidates
- target count (from scope_plan)
- actual imported count
- gap (target - actual, if positive)
- imported-by-doi count
- PDF-attached count
- URL-recorded count
- failed attachment reasons
- retry attempted (true/false)
- failure category counts (tool-missing / permission / network / invalid-doi / rate-limit)

## Post-Ingest Count Verification

After all batches complete:

1. Count total items in Zotero collection
2. Compare with target_count
3. If count < target_count: note gap in final report
4. Include in deliverables:
   ```
   Zotero导入完成:
   - 目标: {target_count} 篇
   - 实际导入: {actual_count} 篇
   - 完成率: {actual/target*100}%
   ```
