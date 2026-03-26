---
name: security-top4-paper-skeleton
description: Use when the user provides an idea proposal, research proposal, or rough paper idea and wants a venue-aware security top-conference paper skeleton for an automated vulnerability-detection tool paper. Supports IEEE S&P, USENIX Security, ACM CCS, and NDSS styles, and explains what each chapter must say, what evidence it must carry, and how to adapt the structure by paper mode.
---

# Security Top-4 Paper Skeleton

这个 skill 的目标很单一：
把用户已有的 `idea proposal` / `research-proposal.md` / 粗略研究想法，转换成一套**可直接用于 LaTeX 目录搭建**的安全顶会论文骨架。

它面向的论文类型不是泛安全论文，而是这类更具体的目标：
- automated vulnerability detection tools
- fuzzing-based bug finding
- static/dynamic/concolic/symbolic analysis for vulnerability discovery
- firmware / kernel / web / protocol / runtime vulnerability mining
- LLM-assisted vulnerability discovery systems

如果用户要的是“写完整论文”或“补 related work”，这不是主职责。
这个 skill 的输出重点是：
- 选一个合适的论文模式
- 选一个合适的 venue emphasis
- 生成章节骨架
- 解释每章讲什么
- 说明每章要拿什么证据支撑
- 提醒常见 reviewer objections

详细的样本归纳见 [top4-style-findings.md](references/top4-style-findings.md)。

## 输入解析

优先输入：
- `research-proposal.md`
- markdown idea proposal
- 中文或英文的结构化研究设想

回退输入：
- 一段自由文本 idea

先从输入里提取以下槽位：
- `problem`: 要解决的漏洞发现问题
- `target`: 面向什么对象
  - web application
  - firmware
  - kernel
  - protocol implementation
  - runtime / VM / browser / middleware
- `vulnerability_class`: 想抓哪类漏洞
- `automation_story`: 自动化是怎么发生的
  - static reasoning
  - dynamic testing
  - fuzzing
  - symbolic execution
  - LLM-guided analysis
  - replay / validation
- `pipeline`: 系统的阶段化流程
- `evidence_plan`: 预计能拿到哪些证据
  - known-vuln benchmark
  - zero-day findings
  - CVE / disclosure
  - exploit / replay / witness
  - precision / recall
  - coverage / throughput / overhead
  - ablation
- `scope_boundaries`: 不支持什么、威胁模型边界是什么
- `venue_preference`: 用户指定或隐含偏向哪一个会

如果用户没有明确给出 venue，就默认同时判断 `IEEE S&P / USENIX Security / ACM CCS / NDSS` 哪个更像。

## 第一步：选择论文模式

先在下面三种模式里选一个主模式。不要混成泛泛模板。

### Mode A: Tool/System-first

适用条件：
- 用户已经有比较完整的系统管线
- 核心贡献是一个工具或系统
- 论文卖点是“能工作、能扩展、能找出真实漏洞”

结构偏好：
- `Introduction`
- `Background and Problem Scope`
- `System Overview`
- `Design`
- `Implementation`
- `Evaluation`
- `Discussion / Limitations / Disclosure`
- `Related Work`
- `Conclusion`

这个模式要重点强化：
- 系统边界
- 模块分工
- 设计约束
- implementation realism
- evaluation credibility

### Mode B: Method+Tool Hybrid

适用条件：
- 用户的主创新点是一个方法学 insight
- 工具只是承载这个 insight 的系统化实现
- 比如 constraint reasoning、state abstraction、LLM grounding、symbolic guidance、protocol semantics recovery

结构偏好：
- `Introduction`
- `Background and Threat Model`
- `Problem Formulation`
- `Approach Overview`
- `Technique I`
- `Technique II`
- `Implementation`
- `Evaluation`
- `Limitations`
- `Related Work`
- `Conclusion`

这个模式要重点强化：
- challenge -> insight -> mechanism
- 为什么现有方法不行
- 为什么你的核心技术足够新
- soundness / precision / generality trade-off

### Mode C: Evaluation-heavy Tool Paper

适用条件：
- 用户最强的资产是大规模评测、真实发现、CVE、广泛 target set
- 系统本身未必极复杂，但验证非常扎实
- 论文亮点是“这个方向终于被系统性证明有效”

结构偏好：
- `Introduction`
- `Problem and Scope`
- `Method Overview`
- `Implementation`
- `Evaluation Setup`
- `Main Results`
- `Bug Findings / Case Studies / Disclosure`
- `Ablation and Failure Analysis`
- `Related Work`
- `Conclusion`

这个模式要重点强化：
- benchmark and target quality
- baseline fairness
- bug confirmation quality
- exploit / replay / witness strength
- false positive / false negative accounting

## 第二步：选择 venue emphasis

骨架只有一套核心版，但每个 venue 要切换强调点。

### IEEE S&P

默认强调：
- 第一章要更强的研究问题正当性
- novelty 和 rigor 要同时成立
- threat model、assumption、scope 要更清晰
- reviewer 会更在意“是不是一个真正值得发 top venue 的新 insight”

输出时要偏向：
- 更强的问题定义
- 更明确的 threat model 或 scope boundary
- 更清晰的 novelty claim
- discussion / limitations 不能弱

### USENIX Security

默认强调：
- system clarity
- practical engineering details
- artifact friendliness
- readable pipeline and implementation story

输出时要偏向：
- `System Overview` 和 `Implementation` 更完整
- evaluation setup 说得更可复现
- figures / tables 建议更具体
- 如果有源码、artifact、release plan，要自然写进文稿

### ACM CCS

默认强调：
- 一般安全 reviewer 的可读性
- 第一页必须快速讲清楚问题、差距、方法、结果
- evaluation 要结构化，最好带研究问题视角

输出时要偏向：
- `Introduction` 更 general-audience friendly
- 不要过早陷入细节
- 给出更清楚的 challenge list
- `Evaluation` 里建议显式拆成 `RQ1 / RQ2 / RQ3`

### NDSS

默认强调：
- practical attack surface
- deployed systems realism
- end-to-end attack / validation / verification
- 论文需要非常像“真实世界里会造成损害的问题”

输出时要偏向：
- 更强的 motivating scenario
- 更强的 vulnerability semantics / exploitation path
- evaluation 里强调真实 target、真实配置、真实影响
- `Limitations` 和 `Deployment Assumptions` 要更诚实

## 第三步：生成章节骨架

默认输出必须包含：
- `Recommended mode`
- `Recommended venue emphasis`
- `Paper title direction`
- `Core story in one paragraph`
- `Section-by-section skeleton`

每个 section 至少输出六个槽位：
- `Goal`
- `What to Write`
- `Evidence`
- `Figures/Tables`
- `Reviewer Objections`
- `Transition`

不要输出空模板，必须写出这一章承担的论证任务。
章节级细则见 [section-blueprint.md](references/section-blueprint.md)。

## 默认核心骨架

默认使用下面这条主干，然后按 mode 和 venue 调整：

- `Abstract`
- `Introduction`
- `Background and Scope` 或 `Background and Threat Model`
- `Overview`
- `Design / Core Techniques`
- `Implementation`
- `Evaluation`
- `Case Studies / Real Findings / Disclosure`
- `Discussion / Limitations / Ethics`
- `Related Work`
- `Conclusion`

各章默认职责：
- `Abstract`: 问题、缺口、方法、结果、影响的高密度摘要
- `Introduction`: 问题正当性、prior gap、key idea、teaser results、contributions
- `Background/Scope`: 定义 bug semantics、target、assumptions、out-of-scope
- `Overview`: 解释 pipeline、阶段接口、自动化边界
- `Design/Techniques`: 讲清 challenge -> insight -> mechanism
- `Implementation`: 建立系统可信度，而不是写工程流水账
- `Evaluation`: 证明有效性、验证质量、成本与边界
- `Case Studies`: 证明真实影响和漏洞价值
- `Discussion/Limitations`: 主动处理失败模式、边界和伦理问题
- `Related Work`: 按检测信号、自动化深度、目标域做比较
- `Conclusion`: 收束核心 claim 和可信 future work

## Mode-specific 调整规则

### 如果是 Tool/System-first

- 保留 `Overview -> Design -> Implementation -> Evaluation` 的主干
- `Background` 缩短，`Implementation` 增强
- `Evaluation` 里 main result 和 case studies 要分开
- 如果有真实发现，单列 `Real Findings / Disclosure`

### 如果是 Method+Tool hybrid

- `Problem Formulation` 可以替代部分 `Background`
- `Design` 拆成 `Technique I / Technique II / Technique III`
- 每个 technique 都要有 challenge/insight/mechanism
- `Implementation` 不宜太长，但要足够让 evaluation believable

### 如果是 Evaluation-heavy tool paper

- `Evaluation Setup` 和 `Main Results` 要拆开
- `Case Studies / Disclosure` 必须更强
- 如果方法本身不复杂，不要硬拉长 design
- reviewer 更关心：
  - target coverage
  - bug value
  - verification quality
  - baseline fairness

## Venue-specific 微调规则

### 输出给 IEEE S&P 时

- 强化 `Threat Model / Scope`
- contributions 写得更像 scientific claims，而不是 feature list
- `Discussion / Limitations` 不能省
- 如果方法有形式化或 reasoning flavor，要更突出

### 输出给 USENIX Security 时

- 强化 `System Overview`、`Implementation`、`Artifact Readiness`
- 图表建议更落地
- evaluation setup 要可复现
- 如果有开源、artifact、release、dataset，应该明确放进去

### 输出给 ACM CCS 时

- `Introduction` 要对 general security audience 友好
- 少用本领域内部黑话直冲正文
- 默认把 evaluation 拆成 `RQ1/RQ2/RQ3`
- 每章标题要更清爽，不要过度工程化命名

### 输出给 NDSS 时

- 强化 motivating scenario 和 exploitability
- 更突出真实 target、真实协议、真实部署条件
- `Limitations`、`Assumptions`、`Disclosure` 要更诚实
- 如果没有真实攻击面或真实 target，避免硬贴 NDSS 风格

## 输出模板

默认按这个格式输出：

```markdown
## Recommended Framing
- Mode:
- Venue emphasis:
- One-sentence paper claim:

## Proposed Skeleton

### 1. Abstract
- Goal:
- What to Write:
- Evidence:
- Figures/Tables:
- Reviewer Objections:
- Transition:

### 2. Introduction
...
```

## 硬性约束

- 不要虚构实验结果、漏洞数、CVE、确认状态
- 不要把 `Related Work` 放到太前面
- 不要给出空洞模板
- 不要把所有 venue 写成一模一样
- 不要只写章节名，不解释章节的论证任务
- 如果 proposal 还不够完整，要明确哪些章节只能先写成 placeholder

## 使用参考文件的时机

当你需要更细的风格依据时，再读：
- [top4-style-findings.md](references/top4-style-findings.md)
- [section-blueprint.md](references/section-blueprint.md)

尤其在下面情况要读：
- 需要解释为什么推荐某个 venue
- 需要判断 mode
- 需要决定 `Background/Threat Model/Overview` 的相对长度
- 需要强化 evaluation 结构
