# Step 08 - Deliverables

## Visualizer Status Hook (Required)

Before starting Step 08, MUST run:

`bash -lc 'source scripts/init.sh; write_status running "交付物生成"'`

After Step 08 completes, MUST run:

`bash -lc 'source scripts/init.sh; write_status done "交付物生成"'`

If blocked/failed, MUST run:

`bash -lc 'source scripts/init.sh; write_status error "交付物生成"'`

## ⛔ PREREQUISITE GATE (DO NOT PROCEED IF FAILED)

**Before reading this file, Step 07 MUST be complete:**
- Step 07 checkpoint: `executed=true`
- Step 07 status: `ok`
- Coverage check completed
- Stop/continue decision made with reason

**If Step 07 not complete**: STOP. Go back and finish Step 07 first.

---

## Required Outputs

- `literature-review.md`
- `references.bib`

## Optional Output

- `research-proposal.md` only when user explicitly requests

## Required Actions

1. Generate outputs from verified and coverage-checked set only.
2. Include a compact execution evidence summary for all steps.
3. Explicitly label any unexecuted hard step as unverified.

## Hard Rule

Do not claim complete execution if any hard step lacks evidence.

## Paper Discovery Report Template (Required)

Use the following structure when generating `literature-review.md`:

```markdown
## 论文发现报告

### 1. 检索目标
- 主题：
- 约束：
- 时间范围：
- 排除项：
- 检索策略：

### 2. 检索路径
- Query A:
- Query B:
- Query C:
- Query D:
- 种子论文：
- 扩展方式：recommendations / citations / references
- 路径说明：OpenAlex -> S2 -> arXiv -> Google Scholar（近两年强制补充）

### 3. 覆盖性说明
- 已覆盖 venues：
- 已覆盖论文类型：
- 证据充分方向：
- 可能遗漏方向：
- 收束或继续原因：

### 4. 核心论文分桶

#### Foundational
- [title] ([year], [venue], cites=[n])

#### Representative methods
- ...

#### Recent frontier
- ...

#### Survey / benchmark / dataset
- ...

#### Adjacent or contrary work
- ...

#### Security-specific threat models / defenses
- ...

### 5. 对比矩阵
| Paper | Type | Venue | Year | Threat Model | Method | Dataset/Benchmark | Metric | Route |
|------|------|------|------|------|------|------|------|------|
| ... | ... | ... | ... | ... | ... | ... | ... | ... |

### 6. 趋势与缺口
- 趋势 1：
- 趋势 2：
- 缺口 1：
- 缺口 2：
- 矛盾与证据不足：

### 7. 推荐阅读顺序
1. 先读综述/benchmark
2. 再读奠基与代表方法
3. 最后读近两年 frontier work

### 8. 执行证据摘要
- step checkpoints:
- sources attempted:
- verification summary:
- zotero ingest summary:

### 9. 备注
- 哪些论文只有摘要
- 哪些为 arXiv 预印本
- 哪些条目未通过验证及原因
```

For `references.bib`, include only verification-approved entries under current policy.

## Detailed Guidance (Restored)

- `literature-review.md` must follow the template structure above and include coverage statement.
- `references.bib` must be derived from verification output, not raw retrieval output.
- Keep suspicious/unverified candidates in a separate section/report artifact for manual review.
- If user explicitly requests `research-proposal.md`, include at least:
	- Research question
	- Background
	- Proposed method
	- Expected contributions
