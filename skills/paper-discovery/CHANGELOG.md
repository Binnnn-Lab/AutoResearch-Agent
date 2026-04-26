# 更新日志

本文件记录项目的主要变更。

格式参考 [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)。

## [未发布]

### 已修复

- 在 `s2_bulk_search.sh` 中保留 Semantic Scholar bulk search 的真实语义
- 将 bulk 搜索结果在本地按请求的 `limit` 截断输出
- 为 `s2_bulk_search.sh` 增加 `limit` 必须为正整数的校验
- 修复 `expand_queries.sh` 参数名错误导致的查询扩展失败
- 修复 `multi_search.sh` 与 `s2_search.sh` 输出契约不一致导致的多源融合失效
- 修复 `multi_query_search.sh` 合并阶段读取临时目录失败
- 修复 `verify_citations.sh` 的 BibTeX 解析调用与 S2 回退解析失败问题
- 修复 `openalex_search.sh` 缓存写入空结果的问题

### 已更改

- 新增 `EXECUTION_GATES.md` 与 `execution-steps/` 分步执行体系，要求 Claude Code 按文件顺序读取并执行
- 将执行入口从“单一大 skill 文档”拆分为“主控门禁 + 单步文件”，降低跳步和改序风险
- 在 step-file gated 模式下禁用 `run_pipeline.sh` 一键黑盒执行，改为显式逐步调用脚本链
- 删除 `scripts/run_pipeline.sh`，避免误触发一键 pipeline，强制转向 Claude Code 手动分步执行
- 将 `SKILL.md` 重构为最小路由入口，执行细节全部下沉到 `EXECUTION_GATES.md` 与 `execution-steps/`
- 新增 `docs/legacy-skill-reference.md` 归档历史长文档说明，并声明为非执行权威来源
- 删除 `CLAUDE.md`，避免与 `SKILL.md` / `EXECUTION_GATES.md` 形成重复指令源
- 删除 `docs/legacy-skill-reference.md`，进一步减少非执行文档干扰
- 明确 `README.md` 与 `SKILL.md` 的文档职责边界
- 优化 `README.md` 结构，同时保留关键安装说明与使用示例
- 统一 S2 系列脚本输出字段（增加 `paper_id`、`citation_count`、`pdf_url`）
- 将默认正式引用流程整合为“多源检索 + 4 层验证 + 过滤”闭环
- 补充 Zotero 工具可用性探测与入库/附件/分类的执行要求
- 增加“参考项目搜索路径（AutoResearchClaw）”与“当前 skill 整合执行顺序”章节，明确阶段化检索顺序与通道优先级
- 新增工作区级 `copilot-instructions.md`，将 Zotero MCP 预检与入库改为自然语言自动触发（无需 `/zotero-auto`）
- 统一 `README.md`、`SKILL.md`、`.github/copilot-instructions.md`、`ZOTERO_INGEST_TEMPLATE.md` 的流程顺序与门禁规则：MCP preflight 先行、失败原因必回报、VERIFIED 入库优先
- 统一文档中的预配置口径：补齐 `.env.example`（`OPENALEX_EMAIL`、`ARXIV_CITATION_THRESHOLD`、`S2_MIN_INTERVAL`、`ENABLE_GOOGLE_SCHOLAR`、`VERIFY_SIMILARITY_THRESHOLD`、`CACHE_TTL_DAYS`）
- 统一 `multi_search.sh` 参数文档，明确兼容两种调用顺序（`query limit year_min` / `query year_range limit`）

---

## [3.0.0] - 2025-03-03

### 已更改

- 从 Plugin 导向结构回归到纯 Skill 导向结构
- 使用 Shell 脚本替代 Python 脚本，以提升可移植性并简化依赖
- 将原 `references/` 中的核心内容收敛到 `SKILL.md`

### 已新增

- 模块化 `scripts/` 目录，用于搜索、质量查询和 BibTeX 生成
- arXiv 结果智能标记能力
- 搜索结果中返回作者 ID
- Semantic Scholar 请求的基础限流能力

### 已移除

- `claude-code-plugin/` 目录
- `references/` 目录
- Python 脚本实现

---

## [2.0.0] - 2025-03-02

### 已新增

- Plugin 架构版本，位于 `claude-code-plugin/` 目录
- 独立 Commands 支持
- 通过 Marketplace 安装的支持

---

## [1.0.0] - 2025-02

### 已新增

- 初始版本发布
- 单一 Skill 架构
- 语义化文献搜索
- 期刊/会议质量评估
- BibTeX 生成功能
- 中文推荐报告输出
