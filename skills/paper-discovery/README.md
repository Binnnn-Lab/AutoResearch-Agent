# Paper Discovery 学术文献发现与引用助手

> 面向 Claude Code / Cursor 的学术文献引用助手，适合论文写作、BibTeX 生成与文献质量筛选。

基于 Semantic Scholar API 的语义化文献检索，整合 CCF 分级、JCR 分区、中科院分区、影响因子、作者 H-index 等多维度质量评估，生成 BibTeX 并提供清晰的中文推荐说明。

这个仓库同时服务两类场景：

- **GitHub 用户**：阅读 `README.md`，了解功能、安装方式和使用示例
- **Claude Code 运行时**：读取 `SKILL.md`（最小路由入口），并严格按 `EXECUTION_GATES.md` 与 `execution-steps/*.md` 执行任务

---

## ✨ 核心功能

| 功能                       | 说明                                                                              |
| -------------------------- | --------------------------------------------------------------------------------- |
| 🔍**语义化搜索**     | 基于 Semantic Scholar API（覆盖 2 亿 + 文献），理解上下文语义，无需手动构造关键词 |
| 🛡️**真实性保障**   | DOI→BibTeX 强制校验机制，确保文献真实存在，杜绝 AI 幻觉生成虚假引用              |
| 📊**多维度质量评估** | 期刊层面（CCF 分级、JCR 分区、中科院分区、影响因子）+ 作者层面（H-index、引用量） |
| 📝**BibTeX 生成**    | 一键生成标准 BibTeX 格式，可直接用于 LaTeX 文档                                   |
| 📋**推荐报告**       | 结构化输出搜索结果，附推荐理由，便于快速决策                                      |

### v2 多源整合与验证闭环（分步硬门禁）

正式写作/投稿建议默认使用以下闭环，避免“搜到但不可验证”的条目：

1. 先读取 `EXECUTION_GATES.md`
2. 按顺序逐步读取并执行 `execution-steps/*.md`
3. 每步执行后输出 checkpoint 证据
4. 检索与验证脚本按步骤显式调用（而非一次性黑盒管道）

默认脚本链（按步骤执行）：
- `scripts/expand_queries.sh`
- `scripts/openalex_search.sh`
- `scripts/s2_search.sh` 或 `scripts/s2_bulk_search.sh`
- `scripts/arxiv_search.sh`
- `scripts/generate_bibtex.sh`
- `scripts/verify_citations.sh`
- `scripts/filter_verified.sh`

当需要落盘文件输出时，`references.bib` 是标准输出之一：
- 优先使用 Zotero 中的真实条目导出。
- 如果 Zotero 不可用，则基于 DOI / Semantic Scholar / CrossRef 元数据生成，并明确标注不是 Zotero-backed。

如果用户明确要求研究计划，则额外生成 `research-proposal.md`：
- Research question
- Background
- Proposed method
- Expected contributions

如果 preflight 成功且用户未禁用入库，必须将 VERIFIED 条目入库并自动尝试附加 PDF。

### MCP 预检强制规则

- 未完成 preflight 前，不得开始检索脚本、Web 兜底检索或生成结果文件。
- 若 preflight 发现 Zotero 工具缺失，先自动执行一次修复：`claude mcp add --transport http zotero-mcp http://127.0.0.1:23120/mcp` + `claude mcp list`，再重跑 preflight。
- preflight 结果必须包含：`attempted=true`、`connected=true|false`、`available_tools`、`missing_tools`、`auto_repair_attempted=true|false`、失败原因（失败时）。
- preflight 在自动修复后仍失败时可继续脚本检索，但最终产物必须包含失败原因和缺失工具列表。
- preflight 成功后，VERIFIED 条目默认应执行 Zotero 入库（除非用户明确禁用入库）。
- 若 preflight 成功但导入失败，必须先重跑一次 preflight 并对失败批次自动重试一次，再给出最终失败结论。
- 仅当脚本检索链路失败时，才允许使用通用 Web Search，并需要说明失败原因。

---

## 🚀 安装

### Claude Code

```bash
# 克隆仓库
git clone https://github.com/ZhangNy301/paper-discovery.git

# 复制到 Claude Code Skills 目录
mkdir -p ~/.claude/skills/paper-discovery
cp paper-discovery/SKILL.md ~/.claude/skills/paper-discovery/
cp -r paper-discovery/scripts ~/.claude/skills/paper-discovery/
cp -r paper-discovery/data ~/.claude/skills/paper-discovery/

# 配置 API Key（推荐）
echo 'S2_API_KEY="your_key_here"' > ~/.claude/skills/paper-discovery/.env
```

### Cursor

```bash
# 创建目录并克隆
mkdir -p ~/.cursor/skills
cd ~/.cursor/skills
git clone https://github.com/ZhangNy301/paper-discovery.git

# 配置 API Key（推荐）
echo 'S2_API_KEY="your_key_here"' > ~/.cursor/skills/paper-discovery/.env
```

获取 API Key: https://www.semanticscholar.org/product/api

---

## 📦 可用脚本

| 脚本                   | 用途                                                                             | 用法                                                          |
| ---------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `s2_search.sh`       | 少量高相关结果检索（含 arXiv 判断）                                              | `bash scripts/s2_search.sh "query" [limit]`                 |
| `s2_bulk_search.sh`  | 使用 Semantic Scholar bulk endpoint 批量拉取候选结果，并按本地 limit 输出前 N 条 | `bash scripts/s2_bulk_search.sh "query" "year_range" limit` |
| `author_info.sh`     | 作者 H-index 查询                                                                | `bash scripts/author_info.sh "author_id"`                   |
| `venue_info.sh`      | 期刊综合查询                                                                     | `bash scripts/venue_info.sh "venue_name"`                   |
| `ccf_lookup.sh`      | CCF 分级查询                                                                     | `bash scripts/ccf_lookup.sh "venue_name"`                   |
| `if_lookup.sh`       | 影响因子查询                                                                     | `bash scripts/if_lookup.sh "journal_name"`                  |
| `doi2bibtex.sh`      | DOI 转 BibTeX                                                                    | `bash scripts/doi2bibtex.sh "doi"`                          |
| `crossref_search.sh` | CrossRef 搜索（fallback）                                                        | `bash scripts/crossref_search.sh "query" [limit]`           |

增强脚本：

| 脚本                         | 用途                                    | 用法                                                                     |
| ---------------------------- | --------------------------------------- | ------------------------------------------------------------------------ |
| `expand_queries.sh`        | 自动扩展查询（survey/benchmark/recent） | `bash scripts/expand_queries.sh "topic" -` 或显式输出文件                |
| `multi_search.sh`          | 多源统一搜索与去重（兼容两种参数顺序）  | `bash scripts/multi_search.sh "query" 30 2020` 或 `bash scripts/multi_search.sh "query" 2020-2026 30` |
| `multi_search.ps1`         | 无 Bash 的 PowerShell 多源搜索与去重    | `powershell -ExecutionPolicy Bypass -File scripts/multi_search.ps1 -Query "query" -Limit 30 -YearMin 2020` |
| `multi_query_search.sh`    | 多查询融合搜索                          | `bash scripts/expand_queries.sh "topic" - | bash scripts/multi_query_search.sh - 30 2020`              |
| `generate_bibtex.sh`       | 从搜索结果生成 BibTeX（默认 stdout）     | `bash scripts/generate_bibtex.sh - -` （接收管道输入）                       |
| `verify_citations.sh`      | 4 层验证 BibTeX（默认 stdout）          | `bash scripts/verify_citations.sh - -` （接收管道输入）                   |
| `filter_verified.sh`       | 过滤低可信条目（默认 stdout）            | `bash scripts/filter_verified.sh references.bib report.json -`         |
| `google_scholar_search.py` | Google Scholar 搜索（近两年强制补充）   | `python scripts/google_scholar_search.py "query" 10 2020`              |

> 说明：`s2_search.sh` 更适合少量高相关结果检索；`s2_bulk_search.sh` 更适合减少请求次数、先批量拉取候选文献再做筛选。

---

## 🆕 增强功能

### arXiv 文章智能判断

搜索结果会自动标记 arXiv 文章的引用状态：

| 状态            | 条件                | 推荐建议                    |
| --------------- | ------------------- | --------------------------- |
| `recommended` | arXiv + 引用 ≥ 100 | ✅ 高影响力 arXiv，可引用   |
| `caution`     | arXiv + 引用 < 100  | ⚠️ 低引用 arXiv，谨慎引用 |
| `normal`      | 正式发表            | ✅ 正式发表                 |

### 作者信息查询

搜索结果包含前 3 位作者的 ID，可用于查询 H-index：

```bash
bash scripts/author_info.sh "18119920"
```

返回示例：

```json
{
  "name": "Daquan Zhou",
  "hIndex": 25,
  "citations": 8500,
  "papers": 42
}
```

---

## 📁 文件结构

```
paper-discovery/
├── SKILL.md               # Skill 主文件
├── README.md              # 本文件
├── CHANGELOG.md           # 版本历史
├── .env.example           # 配置模板
├── scripts/               # Shell 脚本
│   ├── init.sh
│   ├── s2_search.sh
│   ├── s2_bulk_search.sh
│   ├── s2_recommend.sh
│   ├── s2_citations.sh
│   ├── s2_references.sh
│   ├── openalex_search.sh
│   ├── arxiv_search.sh
│   ├── multi_search.sh
│   ├── multi_query_search.sh
│   ├── expand_queries.sh
│   ├── generate_bibtex.sh
│   ├── verify_citations.sh
│   ├── filter_verified.sh
│   ├── google_scholar_search.py
│   ├── author_info.sh
│   ├── venue_info.sh
│   ├── ccf_lookup.sh
│   ├── if_lookup.sh
│   ├── doi2bibtex.sh
│   └── crossref_search.sh
└── data/                  # 数据库
    ├── ccf_2022.jsonl
    ├── ccf_2026.jsonl
    └── impact_factor.sqlite3
```

---

## 🔧 配置

### Semantic Scholar API Key

获取地址：`https://www.semanticscholar.org/product/api`

| 模式       | 速率限制               |
| ---------- | ---------------------- |
| 有 API Key | 1 次/秒                |
| 无 API Key | 共享限额，极易触发 429 |

### OpenAlex 邮箱（推荐）

```bash
echo 'OPENALEX_EMAIL="your_email@example.com"' >> ~/.claude/skills/paper-discovery/.env
```

### Zotero 连接说明

本仓库脚本本身不直接操作 Zotero 数据库。若要在 Claude Code 中自动入库/挂 PDF/分类，需要当前会话实际启用 Zotero MCP 工具（如 `create_collection`、`add_items_by_doi`、`find_and_attach_pdfs`）。

若未启用 Zotero 工具，脚本仍可完成检索、去重、验证和 BibTeX 生成，但不能自动导入 Zotero。

### arXiv 引用阈值（可选）

```bash
# 默认 100，可在 .env 中配置
echo 'ARXIV_CITATION_THRESHOLD=100' >> ~/.claude/skills/paper-discovery/.env
```

### 推荐 .env 预配置（统一）

```bash
S2_API_KEY="your_key_here"
OPENALEX_EMAIL="your_email@example.com"
ARXIV_CITATION_THRESHOLD=100
S2_MIN_INTERVAL=1
ENABLE_GOOGLE_SCHOLAR=false
VERIFY_SIMILARITY_THRESHOLD=0.80
CACHE_TTL_DAYS=7
```

---

## 📊 质量评估维度

| 维度         | 权重   | 说明                                |
| ------------ | ------ | ----------------------------------- |
| CCF 分级     | 基础分 | A=100, B=70, C=40                   |
| JCR 分区     | 基础分 | Q1=80, Q2=60, Q3=40, Q4=20          |
| 中科院分区   | 基础分 | 1区=90, 2区=70, 3区=50, 4区=30      |
| 影响因子     | 30%    | IF × 5 (上限50)                    |
| 引用量       | 20%    | log₁₀(citations+1) × 10 (上限50) |
| 年份         | 10%    | (year-2015) × 2 (上限30)           |
| 作者 H-index | 10%    | 第一作者 H-index × 2 (上限30)      |

---

## 📖 使用示例

下面这些示例是**用户在 Claude Code / Cursor 中可以直接提出的请求**，也是这个 skill 最常见的使用方式。

### 示例 1：为 LaTeX 段落找引用

```
我在写论文，这段话需要找引用：

  "Deep learning has achieved remarkable success in medical image analysis, particularly in radiology where chest X-rays are the most commonly performed imaging examination globally [CITE]. Recent advances in vision transformers have further improved performance on these tasks [CITE]."
```

帮我找合适的文献。

### 示例 2: 查询期刊质量

```
我想投 TMI (IEEE Transactions on Medical Imaging)，这个期刊质量怎么样？
CCF 分级是什么？影响因子多少?
```

### 示例 3: 查询作者学术影响力

```
这篇论文的第一作者 H-index 是多少?我想评估一下作者的学术影响力。
```

### 示例 4: 生成 BibTeX

```
帮我生成这篇论文的 BibTeX：
DOI: 10.1038/s41591-020-0792-9
```

### 示例 5：批量搜索 + 年份过滤

```
帮我找 2020 年以后关于 remote photoplethysmography (rPPG) 的论文，要高质量的，列出 10 篇推荐。
```

适合使用 `s2_bulk_search.sh` 对候选文献进行批量拉取，再结合年份、引用量、venue 质量等信息做筛选。

### 示例 6: 综合工作流（粘贴论文段落）

帮我检查这段论文的引用是否合适，如果有更好的推荐请告诉我：

```
Remote photoplethysmography (rPPG) enables non-contact heart rate estimation from facial videos [1]. Traditional methods like CHROM and POS have been widely used [2], while recent deep learning approaches have shown superior performance [3].

[1] Some arXiv paper with 5 citations
[2] A conference paper from 2015
[3] Another paper
```

### Zotero 自动连接与入库（自然语言触发）

默认交互方式为自然语言触发，例如：

- "请帮我查找 `<topic>` 的论文，并同步到 Zotero"

工作区默认指令会先做 Zotero MCP 可用性预检；若可用，再继续执行检索、验证、入库、PDF 附加和主题分类。
用户不需要额外写“请先检测 MCP 连接”。

---

## 🙏 致谢

- [Semantic Scholar](https://www.semanticscholar.org/) - Academic paper search API
- [impact_factor](https://github.com/suqingdong/impact_factor) - Journal impact factor database
- [CrossRef](https://www.crossref.org/) - DOI metadata API

## 📖 相关链接

- [小红书教程：文献引用自动化](https://www.xiaohongshu.com/discovery/item/699eecff000000000d00ab7d?source=webshare&xhsshare=pc_web&xsec_token=ABlbc1XDsjw8TWj8fUipbvyaj7qoU9u73hL5ZmzK4n65c=&xsec_source=pc_share)

## License

MIT
