---
name: paper-discovery-assistant
description: Use when the user needs systematic paper discovery, security-focused related-work search, literature review generation, reading-list construction, citation-network expansion, Zotero-backed paper collection, BibTeX generation, or venue/author quality checks. Triggers include 论文查找、找相关工作、paper discovery、related papers、reading list、citation network、沿引用扩展、Semantic Scholar 推荐、文献综述检索、网络安全论文、USENIX Security、CCS、NDSS、S&P、bib、参考文献。
---

# Paper Discovery Assistant 论文发现与引用助手

## 核心原则

1. **必须优先通过 `scripts/` 目录中的脚本执行**，不要手写临时 `curl`。
2. **discovery-first**：先做问题拆解和召回，再做推荐扩展、引文扩展、质量筛选。
3. **语义优先，不是关键词堆砌**：查询要体现任务、方法、对象、约束、时间范围、排除项。
4. **组合检索**：默认使用“双路线检索 + 结果融合”，而不是只跑一次搜索。
5. **Zotero 优先做管理，Semantic Scholar 优先做发现**：如果当前会话可用 Zotero 工具，则用它做 collection、PDF 附件、full-text、BibTeX；如果不可用，就用本 skill 的脚本完成检索与元数据整理，并明确说明没有全文分析。
6. **明确能力边界**：Semantic Scholar API 通常提供元数据与摘要，不提供论文正文；只有在 Zotero `get_item_fulltext`、开放 PDF 或出版社页面可用时，才能声称做了全文分析。
7. **不自动修改文稿**：如果用户还在写论文，所有候选文献、综述文件和 BibTeX 先生成并汇报，再由用户决定如何使用。

## 适用场景

- 用户给出主题、方法、任务、数据集、年份、排除项，要求系统化找论文
- 用户给出 1-5 篇种子论文，要求沿着相关推荐或引用网络继续扩展
- 用户要做文献综述，需要区分 foundational / recent / survey / contrary work
- 用户要构建阅读清单、related work 候选池或 BibTeX 列表
- 用户需要对候选论文做 venue、作者、影响力辅助判断
- 用户要围绕安全领域 topic 系统查找论文，尤其是 `IEEE S&P`、`USENIX Security`、`CCS`、`NDSS` 等 venues
- 用户要输出 `literature-review.md`、`references.bib`、`research-proposal.md`

## 可用脚本

依赖：`curl`、`jq`、`sqlite3`

| 脚本 | 用途 | 用法 |
|------|------|------|
| `s2_search.sh` | 少量高相关结果检索，返回 `paperId` 供后续扩展 | `bash scripts/s2_search.sh "query" [limit]` |
| `s2_bulk_search.sh` | 批量拉取候选结果，适合先扩大召回再筛选 | `bash scripts/s2_bulk_search.sh "query" "year_range" limit` |
| `s2_recommend.sh` | 基于 1 个或多个种子论文做相关推荐 | `bash scripts/s2_recommend.sh "paperId1,paperId2" [negative_ids] [limit]` |
| `s2_citations.sh` | 查找“谁引用了这篇论文”，适合追踪后续工作 | `bash scripts/s2_citations.sh "paperId" [limit] [offset]` |
| `s2_references.sh` | 查找“这篇论文引用了谁”，适合找基础工作 | `bash scripts/s2_references.sh "paperId" [limit] [offset]` |
| `author_info.sh` | 作者信息查询（H-index） | `bash scripts/author_info.sh "author_id"` |
| `venue_info.sh` | 期刊综合查询 | `bash scripts/venue_info.sh "venue_name"` |
| `ccf_lookup.sh` | CCF 分级查询 | `bash scripts/ccf_lookup.sh "venue_name"` |
| `if_lookup.sh` | 影响因子查询 | `bash scripts/if_lookup.sh "journal_name"` |
| `doi2bibtex.sh` | DOI 转 BibTeX | `bash scripts/doi2bibtex.sh "doi"` |
| `crossref_search.sh` | CrossRef 搜索（fallback） | `bash scripts/crossref_search.sh "query" [limit]` |

## 先解析用户给的关键指令

在检索前，把用户输入整理成以下槽位。缺失项可以合理补全，但要在报告里说明假设：

- **topic / problem**：要研究什么问题
- **method / angle**：偏方法、应用、benchmark、survey、理论还是系统
- **must-have**：必须覆盖的数据集、模型、术语、作者、会议
- **exclude**：明确排除的方向、任务、领域、方法
- **year range**：如 `2022-`、`2018-2021`
- **paper type**：survey / seminal / recent / empirical / negative / benchmark
- **venue preference**：安全领域优先 `IEEE S&P`、`USENIX Security`、`CCS`、`NDSS`，其次 `EuroS&P`、`ACSAC`、`RAID`、`SOUPS`、`PETS`；若主题和 ML 安全相关，再补 `NeurIPS`、`ICML`、`ICLR`、`ACL`、`CVPR`
- **target count**：如 “先给我 10 篇最核心 + 5 篇最新”
- **output goal**：做阅读列表、related work、综述框架、BibTeX、还是仅做初筛

把这些槽位转成 2-4 个英文语义查询，而不是直接把中文原句原样搜索。

## 安全领域优先的 scope 设定

默认优先级：

- **核心安全 venue**：`IEEE S&P`、`USENIX Security`、`CCS`、`NDSS`
- **扩展安全 venue**：`EuroS&P`、`ACSAC`、`RAID`、`AsiaCCS`、`SOUPS`、`PETS`
- **相邻系统/网络 venue**：`SOSP`、`OSDI`、`NSDI`、`SIGCOMM`、`IMC`
- **仅在主题交叉时补充 ML venue**：`NeurIPS`、`ICML`、`ICLR`、`ACL`、`EMNLP`、`CVPR`

默认时间范围：

- **综述 / 研究现状**：最近 3 年 + 必要的 seminal works
- **广泛摸底**：50-100 篇候选
- **聚焦综述**：20-50 篇候选

包含/排除标准建议：

- 包含：顶级 venue、与问题直接相关、方法或威胁模型明确、实验设置可比较
- 排除：仅边缘相关、无实质实验、与用户威胁模型不匹配、重复路线过多

## Zotero 增强综述工作流（若工具可用）

如果当前会话有 Zotero 工具，优先采用下面的 6 步法；如果没有，就用本 skill 的脚本完成检索和元数据整理，并在输出里声明“未做 Zotero 全文分析”。

### Step 1: Define Scope

1. 明确 topic、关键词、威胁模型、任务边界和研究问题。
2. 默认时间范围为最近 3 年，并补充 seminal papers。
3. 确定 venues 和 inclusion/exclusion criteria。
4. 如果可用，先用 `create_collection` 建立顶层 Zotero collection。

### Step 2: Search and Collect

1. 用下面两条路线并行找论文：
   - **Route A: Graph-based discovery**
     用本 skill 的 `s2_search.sh`、`s2_bulk_search.sh`、`s2_recommend.sh`、`s2_citations.sh`、`s2_references.sh` 做语义搜索、推荐扩展和引用网络扩展。
   - **Route B: Systematic review sweep**
     按 `survey / seminal / recent / benchmark / threat model / venue` 几个维度拆 query，做覆盖式检索，防止漏掉综述、benchmark、顶会最新论文和负面结果论文。
2. 如有 Zotero 工具，对每篇相关论文：
   - 提取 DOI
   - 用 `add_items_by_doi` 入库
   - 用 `create_collection` 放入合适的子 collection
   - 用 `find_and_attach_pdfs` 附加开放 PDF
3. 目标规模：
   - 聚焦综述：20-50 篇
   - 宽泛综述：50-100 篇

### Step 3: Screen and Filter

1. 根据关键词、作者、venue、年份、威胁模型进行筛选。
2. 保留不同路线的代表作，不要让同一路线占满候选池。
3. 合并 Route A 和 Route B 的结果，并按以下优先级去重：
   - `paperId`
   - DOI
   - `title + year`
4. 为每篇论文保留来源标签：`route_a_graph`、`route_b_systematic`、`both`
5. 如果可用，用 Zotero 的 tags / collections 管理：
   - `Core Papers`
   - `Methods`
   - `Benchmarks / Datasets`
   - `Defenses`
   - `Attacks / Threat Models`
   - `Limitations / Negative Results`

### Step 4: Deep Analysis

1. 对 `Core Papers` 和 `Methods` 做深读。
2. 如果可用，用 `get_item_fulltext` 做全文分析，提取：
   - 关键贡献
   - 方法细节
   - 实验设置
   - 主结果
   - 优势与局限
3. 如果没有全文，只能基于 abstract / metadata 做初步分析，必须明确标注。

### Step 5: Synthesize Findings

1. 按主题分组：方法路线、威胁模型、应用域、评测设置。
2. 识别趋势：新兴方向、衰退方向、交叉融合方向。
3. 识别 gap：评测缺口、威胁模型缺口、场景缺口、方法矛盾。
4. 生成 comparison matrix：`method vs. threat model vs. dataset vs. metric`。

### Step 6: Generate Outputs

默认生成以下文件：

1. `literature-review.md`
2. `references.bib`
3. `research-proposal.md`（仅在用户要求时）

在生成输出前，必须先确认检索已经达到“足够全面”的停止条件，而不是搜到几篇像样论文就提前结束。

## 推荐工作流

### 双路线融合策略

- **Route A: Semantic Scholar 图扩展路线**
  - 强项：recommendations、forward citations、backward references
  - 适合：从高质量 seed paper 出发，找 follow-up、基线和相邻路线

- **Route B: Systematic review 检索路线**
  - 强项：venue sweep、survey sweep、benchmark sweep、recent/seminal coverage
  - 适合：防止漏掉综述、benchmark、顶会最新论文和图扩展没有覆盖到的工作

- **融合原则**
  - 两条路线并行跑
  - 统一去重、合并、排序
  - 被两条路线同时命中的论文提高优先级
  - 只被一条路线命中的论文也保留，但在报告里标记来源
  - 只有当两条路线都完成至少一轮补查后，才允许进入最终汇总

### 模式 A：用户只给主题或任务

1. **Route A**：用 `s2_search.sh` 构造 2-3 个高精度 query，先拿核心结果，再用 `s2_bulk_search.sh` 扩大召回。
2. 从 Route A 中选出 2-5 篇最像“种子论文”的候选，记录 `paperId`。
3. 对这些 seed 跑 `s2_recommend.sh`、`s2_citations.sh`、`s2_references.sh`。
4. **Route B**：再补查 4 类论文：
   - survey / review
   - recent top-venue papers
   - seminal / classic baselines
   - benchmark / dataset / evaluation papers
5. 合并 Route A 和 Route B，去重后按角色分桶：`foundational`、`core methods`、`recent frontier`、`survey/benchmark`、`contrary or adjacent`。

### 模式 B：用户给了种子论文 / DOI / 标题

1. 先用 `s2_search.sh` 根据标题或 DOI 找到准确的 `paperId`。
2. 用 `s2_recommend.sh` 做相关推荐。
3. 用 `s2_citations.sh` 找后续发展、工程化变体、最新 follow-up。
4. 用 `s2_references.sh` 找奠基工作、早期路线和经典基线。
5. 如果用户说“不要某个方向”，把那类论文作为 negative seeds 传给 `s2_recommend.sh` 的第二个参数。

### 模式 C：用户要补 related work / survey

1. 先用 Route B 覆盖 survey / benchmark / seminal 三类。
2. 再用 Route A 补最近 2-3 年代表作、竞争路线和 follow-up。
3. 必须显式区分：
   - 综述性文献
   - 奠基文献
   - 直接相关方法
   - 最新代表作
   - 反对证据 / 局限性工作

## 检索策略细则

### 1. 先广后深

- 第一次搜索优先高召回，但不要超过 3-4 个 query。
- 第二轮开始必须从高质量 seed paper 往外扩展，而不是继续盲搜。
- 默认至少完成：
  - Route A 的初始搜索 + 推荐扩展 + citations/references 扩展
  - Route B 的 survey sweep + recent venue sweep + seminal sweep + benchmark/evaluation sweep
- 不能因为“已经有几篇够写了”就停止；必须先检查 coverage 是否完整。

### 2. 查询要带“研究意图”

- 不要只搜名词堆砌。
- 优先组合：
  - 任务 + 方法
  - 任务 + 数据集/benchmark
  - 方法 + 约束条件
  - 任务 + survey/review
  - 任务 + 年份约束
- 对中文需求优先转成英文 query。

示例：

| 用户意图 | 推荐查询 |
|----------|----------|
| 找安全综述 | `"llm security survey prompt injection jailbreak defense"` |
| 找核心安全方法 | `"network intrusion detection graph neural network security"` |
| 找最新安全论文 | `"software supply chain security attack defense 2024 2025"` |
| 找 ML 安全交叉 | `"adversarial robustness large language model security benchmark"` |
| 排除某方向 | 先主搜，再将排除方向作为 negative seed 或人工剔除 |

### 3. 用 `paperId` 做贯通

- `paperId` 是 discovery 流程里的主键。
- 一旦找到高质量种子论文，后续推荐、引用、参考文献扩展都基于 `paperId`。
- 报告中最好保留 `paperId`、DOI、URL，方便去重和复查。

### 4. 排序与分桶

优先考虑以下维度：

- 与用户目标的直接相关性
- 是否同时被 Route A 和 Route B 命中
- 是否覆盖不同研究路线，而不是同一路线的重复论文
- 年份与新颖性
- 引用量与影响力
- 是否为 survey / benchmark / seminal paper
- venue 质量、作者影响力
- arXiv 是否只是预印本，是否已有正式发表版本

默认输出时至少分成下面几类：

- `Foundational`
- `Representative methods`
- `Recent frontier`
- `Survey / benchmark / dataset`
- `Adjacent or contrary work`
- `Security-specific threat models / defenses`

### 5. 覆盖性检查与停止条件

只有满足下面大部分条件，才算“可以停止检索并进入最终输出”：

- 核心 survey / review 已覆盖
- 最近 3 年 top-venue 代表作已覆盖
- seminal / classic baselines 已覆盖
- benchmark / dataset / evaluation papers 已覆盖
- 主要 threat model / defense / attack 路线已覆盖
- Route A 和 Route B 都至少补查过一轮
- 新一轮检索带来的新增高价值论文明显变少

如果上述任一关键类目明显缺失，必须继续检索，而不是提前收束。

### 6. 报告里必须写清 coverage

最终输出必须显式说明：

- 已覆盖了哪些论文类型
- 已覆盖了哪些 venues
- 哪些方向证据充分
- 哪些方向仍可能遗漏
- 为什么现在可以收束，或者为什么还需要继续补查

## 质量评估辅助

```bash
bash "${CLAUDE_SKILL_ROOT}/scripts/venue_info.sh" "Nature Medicine"
bash "${CLAUDE_SKILL_ROOT}/scripts/author_info.sh" "AUTHOR_ID"
```

当用户明确关心质量或投稿时，再补充：

- `ccf_lookup.sh`：CS 领域会议/期刊分级
- `if_lookup.sh`：期刊影响因子
- `venue_info.sh`：JCR / 中科院等综合信息
- `author_info.sh`：H-index、总引用、论文数

不要让这些质量指标喧宾夺主。discovery 阶段首先保证覆盖面和相关性。

## arXiv 处理规则

| 状态 | 条件 | 建议 |
|------|------|------|
| `recommended` | arXiv + 引用 >= 阈值 | 可作为高影响预印本纳入 |
| `caution` | arXiv + 引用 < 阈值 | 保留，但提醒谨慎引用 |
| `normal` | 正式发表或非 arXiv | 正常对待 |

默认阈值：

```bash
export ARXIV_CITATION_THRESHOLD=100
```

## BibTeX 与引用输出

需要正式引用时再生成：

```bash
bash "${CLAUDE_SKILL_ROOT}/scripts/doi2bibtex.sh" "10.1038/s41591-020-0792-9"
```

如果 Zotero 工具可用，优先从 Zotero 元数据导出 `references.bib`；否则再退回 DOI / CrossRef / Semantic Scholar 元数据整理。

## 默认文件输出

当用户要求 literature review、research plan、related work dossier 或系统综述时，默认在当前工作目录生成：

### `literature-review.md`

必须包含：

- Introduction
- Main body organized by themes
- Comparison matrix
- Research trends
- Research gaps
- Summary
- Search scope and coverage statement
- Inclusion / exclusion criteria
- Search routes used (`Route A` / `Route B`)
- Limitations and possible missing areas

### `references.bib`

- 优先使用 Zotero 中的真实条目导出
- 如果 Zotero 不可用，则基于 DOI / Semantic Scholar / CrossRef 元数据生成，并说明不是 Zotero-backed

### `research-proposal.md`

仅在用户要求时生成，至少包含：

- Research question
- Background
- Proposed method
- Expected contributions

## 输出模板

默认输出结构：

```markdown
## 论文发现报告

### 1. 检索目标
- 主题：
- 约束：
- 时间范围：
- 排除项：
- 我采用的检索策略：

### 2. 检索路径
- Query A:
- Query B:
- Query C:
- Query D:
- 种子论文：
- 扩展方式：recommendations / citations / references
- Route B sweep:
  - survey / review:
  - recent top-venue:
  - seminal:
  - benchmark / evaluation:

### 3. 覆盖性说明
- 已覆盖的 venues：
- 已覆盖的论文类型：
- 已覆盖的 threat models / defenses：
- 当前仍可能遗漏的方向：
- 我为什么认为这轮结果已经基本找全 / 还未找全：

### 4. 核心论文分桶

#### Foundational
- [title] ([year], [venue], cites=[n])
  Why: 奠基工作/概念源头

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
| ... | ... | ... | ... | ... | ... | ... | ... | route_a_graph / route_b_systematic / both |

### 6. 趋势与缺口
- 研究趋势 1：
- 研究趋势 2：
- Research gap 1：
- Research gap 2：
- 研究中的矛盾或证据不足：

### 7. 推荐阅读顺序
1. 先读 2-3 篇综述或 benchmark
2. 再读 3-5 篇奠基/代表方法
3. 最后跟进近两年的 frontier work

### 8. 备注
- 哪些论文只有摘要、没有正文
- 哪些是 arXiv 预印本
- 哪些结果值得继续沿引用网络深挖
- 哪些论文只由 Route A 找到
- 哪些论文只由 Route B 找到
- 哪些论文被两条路线共同命中
```

如果用户明确要文件而不只是聊天输出，则把上述结构落成 `literature-review.md`，并同步生成 `references.bib`；若请求研究计划，再额外生成 `research-proposal.md`。

## Semantic Scholar 能力边界

- `search` / `bulk search`：适合做初始召回
- `recommendations`：适合从多个种子论文向相近方向扩展
- `citations`：适合找后续工作、应用化工作、最新 follow-up
- `references`：适合找基础工作、经典方法、理论来源
- **正文限制**：默认 API 主要返回元数据和摘要，不保证返回全文正文。若用户需要正文，必须另外确认开放获取 PDF、出版社页面或其他全文来源。
- **Zotero 例外**：只有在 `find_and_attach_pdfs` 和 `get_item_fulltext` 等工具实际可用并成功后，才进入 full-text analysis 模式。

## 配置

```bash
echo 'S2_API_KEY="your_key_here"' > "${CLAUDE_SKILL_ROOT}/.env"
```

| 模式 | 速率限制 | 推荐场景 |
|------|----------|----------|
| 有 API Key | 1 次/秒左右 | discovery 工作流（推荐） |
| 无 API Key | 共享限额 | 容易触发 429 |

```bash
echo 'ARXIV_CITATION_THRESHOLD=100' >> "${CLAUDE_SKILL_ROOT}/.env"
```

## 错误处理

### 429 / 速率限制

1. 等待 1-2 秒后重试
2. 降低并发和 query 数量
3. 优先改用 `s2_bulk_search.sh` 统一召回
4. 再使用 `crossref_search.sh` 做 fallback

### 搜不到结果

1. 把中文需求改写成 2-4 个英文 query
2. 降低约束：先去掉年份或 venue 限制
3. 拆分成更基础的任务/方法词
4. 先找综述或 benchmark，再从其 references / citations 扩展

### 结果很多但很乱

1. 先挑 2-5 篇最贴近的 seed papers
2. 跑 Route A 的 `recommend`、`citations`、`references`
3. 同时补跑 Route B 的 survey / venue / benchmark sweep
4. 最后合并去重并强制分桶，不给用户一长串未整理列表

### 找到一部分就停下来了

如果已经找到一些“够用”的论文，但还没有覆盖 survey、recent top-venue、seminal、benchmark 这些关键类目，不能停。

此时必须：

1. 检查缺失的是哪一类
2. 针对缺失类目继续补 query
3. 再跑一次 Route A 或 Route B
4. 直到 coverage 说明可以自圆其说

## 质量标准

- 聚焦综述：20-50 篇
- 宽泛综述：50-100 篇
- 同时覆盖 recent papers 和 seminal works
- 优先顶级安全 venues，其次再补交叉领域 venues
- 至少识别 2-3 个具体 research gaps
- 输出里必须包含 coverage statement，而不是只给论文列表
- 若尚未达到 coverage 要求，必须明确写“当前仍未找全”，并继续补查
- 对核心论文，若有全文则做全文分析；若无全文，明确写成 abstract-level analysis
