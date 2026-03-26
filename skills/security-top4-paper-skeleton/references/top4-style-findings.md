# Security Top-4 Style Findings

这份参考文件记录了基于本地 PDF 样本做出的结构归纳，用来支撑 `security-top4-paper-skeleton` 的骨架生成逻辑。

## Sample Pool

本轮分析使用了本地样本目录 `~/Downloads/securitypaper` 中的 22 篇 PDF：

### IEEE S&P 2025

- `GoSonar: Detecting Logical Vulnerabilities in Memory Safe Language Using Inductive Constraint Reasoning`
- `EPScan: Automated Detection of Excessive RBAC Permissions in Kubernetes Applications`
- `RGFuzz: Rule-Guided Fuzzer for WebAssembly Runtimes`
- `RACEDB: Detecting Request Race Vulnerabilities in Database-Backed Web Applications`
- `SCAD: Towards a Universal and Automated Network Side-Channel Vulnerability Detection`
- `Predator: Directed Web Application Fuzzing for Efficient Vulnerability Validation`

### USENIX Security 2025

- `ChainFuzz: Exploiting Upstream Vulnerabilities in Open-Source Supply Chains`
- `LLFuzz: An Over-the-Air Dynamic Testing Framework for Cellular Baseband Lower Layers`
- `BLuEMan: A Stateful Simulation-based Fuzzing Framework for Open-Source RTOS Bluetooth Low Energy Protocol Stacks`
- `Effective Directed Fuzzing with Hierarchical Scheduling for Web Vulnerability Detection`
- `Hybrid Language Processor Fuzzing via LLM-Based Constraint Solving`
- `Waltzz: WebAssembly Runtime Fuzzing with Stack-Invariant Transformation`

### ACM CCS 2025

- `Fuzzing Processing Pipelines for Zero-Knowledge Circuits`
- `Error Messages to Fuzzing: Detecting XPS Parsing Vulnerabilities in Windows Printing Components`
- `PromeFuzz: A Knowledge-Driven Approach to Fuzzing Harness Generation with Large Language Models`
- `SyzSpec: Specification Generation for Linux Kernel Fuzzing via Under-Constrained Symbolic Execution`
- `Protocol-Aware Firmware Rehosting for Effective Fuzzing of Embedded Network Stacks`

### NDSS 2026

- `ProtocolGuard: Detecting Protocol Non-compliance Bugs via LLM-guided Static Analysis and Dynamic Verification`
- `BSFuzzer: Context-Aware Semantic Fuzzing for BLE Logic Flaw Detection`
- `FirmCross: Detecting Taint-Style Vulnerabilities in Modern C-Lua Hybrid Web Services of Linux-based Firmware`
- `GoldenFuzz: Generative Golden Reference Hardware Fuzzing`
- `FirmAgent: Leveraging Fuzzing to Assist LLM Agents with IoT Firmware Vulnerability Discovery`

## High-Level Structural Observations

跨 22 篇样本，最稳定的主干不是普通 IMRAD，而是更像下面这条链：

`Introduction -> Background/Scope -> Overview -> Design/Technique -> Implementation -> Evaluation -> Limitations/Discussion -> Related Work -> Conclusion`

对 tool papers 来说，`Overview` 和 `Implementation` 几乎从不缺席。
对 vulnerability-discovery papers 来说，`Evaluation` 不是收尾例行公事，而是论文价值本身的一半以上。

### What appears very often

- `Introduction`: 所有样本都有
- `Evaluation`: 四个会里几乎都是核心大章
- `Implementation`: 在样本中高度稳定
- `Overview`: 在 `S&P / NDSS / USENIX` 尤其常见
- `Design`: 不是泛写法，而是用来承接 challenge-to-technique mapping

### What appears selectively

- `Threat Model`: 不一定单列，但 scope boundary 一定会交代
- `Case Study`: 当论文有高价值真实发现时更常见
- `Ablation`: 在 fuzzing / LLM-assisted / multi-stage systems 中更常见
- `Discussion / Limitations`: `S&P` 和 `NDSS` 更稳定，`CCS` 往往融入 evaluation 后半段

## Quantitative Snapshot

基于本地样本的粗粒度统计：

### IEEE S&P

- total papers analyzed: `6`
- motivating example / real incident flavor: `6/6`
- explicit overview/design flow: `6/6`
- implementation present: `6/6`
- evaluation present: `6/6`
- discussion or limitations: `6/6`
- threat-model-like framing: `2/6`
- CVE / zero-day / disclosure signals: `5/6`

Interpretation:
- `S&P` 样本很在意第一章的说服力
- 常见写法是 “真实风险 -> prior gap -> key idea -> strong teaser result”
- 即使是系统论文，也会努力把方法意义写得像 research insight

### USENIX Security

- total papers analyzed: `6`
- motivating example flavor: `6/6`
- implementation present: `6/6`
- artifact / release / availability signals: `6/6`
- evaluation present: `5/6`
- design section present: `5/6`

Interpretation:
- `USENIX` 样本最像成熟系统论文
- implementation 和 reproducibility 可信度很重要
- 如果论文有 artifact、source release、可复现实验条件，应该主动写出来

### ACM CCS

- total papers analyzed: `5`
- implementation present: `5/5`
- evaluation present: `5/5`
- artifact-style signals: `5/5`
- explicit research-question flavor: `5/5`
- overview present: `4/5`

Interpretation:
- `CCS` 样本经常把 evaluation 写得更结构化
- 适合用 `RQ1 / RQ2 / RQ3` 方式组织评测
- 第一页需要对一般安全 reviewer 更友好

### NDSS

- total papers analyzed: `5`
- overview present: `5/5`
- implementation present: `5/5`
- evaluation present: `5/5`
- discussion / limitations present: `5/5`
- results sections明显存在: `5/5`

Interpretation:
- `NDSS` 样本最稳定的写法是：
  `Overview -> Design -> Implementation -> Evaluation -> Limitations`
- 很强调真实攻击面、真实部署、真实影响
- 没有真实 target 或真实漏洞语义时，不要硬套 NDSS 风格

## Common Winning Dimensions

下面这些维度在样本里反复出现，可以视为安全顶会 tool paper 的通用“中稿维度”。

### 1. Problem Pressure

论文必须先证明：
- 这类漏洞是真实的
- 风险不是边角问题
- 以前的工具没有把它打穿

常见实现方式：
- 真实系统例子
- 公开事故 / known vulnerabilities
- 一个简洁但高冲击的 motivating scenario

### 2. Scope Precision

好论文很少说“我们做了一个通用检测器”就结束。
它们会非常清楚地限定：
- target stack
- bug semantics
- attacker capability
- automation boundary
- unsupported cases

### 3. Mechanistic Novelty

顶会论文不只要有系统，还要讲清：
- 新 insight 是什么
- 为什么旧方法到这里失效
- 新机制如何解决具体 challenge

最常见的写法是：
- `Challenge`
- `Insight`
- `Design`

### 4. System Credibility

reviewer 会不断问：
- 这是不是 prototype
- 这能不能稳定跑
- 这是不是靠很多 hidden manual effort

所以 implementation 章通常承担的是“可信度建设”，不是纯工程流水账。

### 5. Evaluation Credibility

最常见的硬要求：
- 目标集是否合理
- baseline 是否公平
- metric 是否支持 claim
- 结果是否能重复
- bug findings 是否被验证

只说 “found N bugs” 不够。
更强的写法是：
- `known-vuln recall`
- `new findings`
- `validated exploits / witnesses`
- `time-to-trigger / overhead / coverage`
- `ablation`
- `failure analysis`

### 6. Real-World Payoff

这类论文如果能做到下面任一项，故事会明显更强：
- CVE
- vendor acknowledgment
- patch confirmation
- exploit witness
- deployment-impact estimate

### 7. Honest Boundaries

强样本通常不会回避：
- false positives
- false negatives
- unsupported targets
- assumptions that may fail
- ethical / disclosure concerns

这不是减分项，反而是可信度来源。

## Section-Level Lessons

### Introduction

好的引言通常完成 6 件事：
- 给一个能快速建立痛感的场景
- 定义问题而不是只报题目
- 说明 prior work 为什么不够
- 讲出核心 insight
- 给出系统轮廓
- 先亮结果，再列贡献

坏引言的常见问题：
- 只说问题重要，不说为什么难
- 只列 feature，不讲机制
- 结果 teaser 太弱

### Background / Scope / Threat Model

不是教学章，而是校准章。
目标是让 reviewer 在不查额外资料的情况下理解：
- bug 语义
- target context
- assumptions
- out-of-scope

### Overview

顶会样本很少跳过 overview。
它的作用不是重复引言，而是：
- 展示 pipeline
- 绑定 challenge 和 module
- 控制 reviewer 的阅读路径

### Design / Technique

最好的 design 章节不按模块 API 讲，而按“研究难点”讲。

建议顺序：
- 先 challenge
- 再 insight
- 再 mechanism
- 最后讲 trade-off 和 corner cases

### Implementation

implementation 章节通常要回答：
- 你到底实现了什么
- 跑在哪
- 接了哪些 runtime / parser / IR / harness / solver
- 哪些地方是工程上真正困难的

### Evaluation

这是本类论文最容易决定胜负的章节。

高频结构：
- evaluation setup
- target / benchmark
- baselines
- main effectiveness
- bug findings
- ablation
- efficiency / overhead
- failure analysis

如果评测目标不够多，至少要用：
- 更强的验证质量
- 更强的 case study
- 更强的 exploit / replay / witness
来补。

### Discussion / Limitations

高质量样本通常把这章当成：
- 主动拆 reviewer 的雷
- 说明边界不等于无效
- 给未来工作留下合理出口

## Venue Delta Summary

### When to lean S&P

如果 proposal 的强项是：
- 更本质的方法 insight
- 更严格的 reasoning
- 更清晰的 scope / assumption story

就把骨架向 `S&P` 靠。

### When to lean USENIX Security

如果 proposal 的强项是：
- 系统完整度
- implementation maturity
- artifact readiness
- practical deployment realism

就把骨架向 `USENIX` 靠。

### When to lean CCS

如果 proposal 的强项是：
- general security audience 可读性
- evaluation 结构化
- 可以把 story 讲得很清楚

就把骨架向 `CCS` 靠。

### When to lean NDSS

如果 proposal 的强项是：
- 真正的 attack surface
- 真实世界协议 / firmware / infra / deployed systems
- 漏洞验证和现实影响都很强

就把骨架向 `NDSS` 靠。

## Practical Writing Rules for This Skill

- 永远先讲问题和风险，再讲系统
- 永远把 evidence obligations 写进 skeleton
- 如果没有真实 findings，不要假装自己有 disclosure story
- 如果 proposal 的 novelty 更像 technique，就不要硬套 system-first 模板
- 如果 proposal 的强项是大规模结果，就扩 evaluation，不要扩 background
