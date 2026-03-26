# Section Blueprint

这份文件给出章节级的论证义务，用来配合 `security-top4-paper-skeleton` 生成更具体的论文骨架。

## 1. Abstract

- `Goal`: 用 6 句左右讲清问题、缺口、方法、结果、影响
- `What to Write`:
  - one-sentence problem pressure
  - one-sentence prior limitation
  - one-sentence core idea
  - one-sentence system summary
  - one-sentence evaluation headline
  - one-sentence impact headline
- `Evidence`: 至少一个量化 headline result
- `Figures/Tables`: 无
- `Reviewer Objections`: 太泛；只有方法没有结果
- `Transition`: 引出 full story

## 2. Introduction

- `Goal`: 完成整篇论文最关键的推销任务
- `What to Write`:
  - 用真实或高风险漏洞场景起手
  - 说明问题为什么重要
  - 解释 prior work 的共同盲区
  - 给出 key idea 和系统名
  - 说明为什么这不是 incremental tweak
  - 给 evaluation teaser
  - 结尾列 contributions
- `Evidence`:
  - motivating incident / exploit path / real target scenario
  - prior-work gap
  - headline results
- `Figures/Tables`:
  - teaser figure
  - optional `problem -> prior gap -> our pipeline` 图
- `Reviewer Objections`: 问题不新；重要性不足；和现有工作差异不清
- `Transition`: 引到 `Background and Scope` 或 `Threat Model`

## 3. Background and Scope

- `Goal`: 让 reviewer 用最低成本理解 bug semantics、目标环境、资产和边界
- `What to Write`:
  - 只讲必要背景
  - 定义 asset、attacker、assumption、out-of-scope
  - 如果没有单独 threat model，至少写清 `problem scope`
- `Evidence`: target stack / protocol / runtime / app architecture 的必要上下文
- `Figures/Tables`:
  - target architecture diagram
  - attack surface sketch
- `Reviewer Objections`: scope 太散；漏洞定义不严谨；假设藏得太深
- `Transition`: 引到 `Overview`

## 4. Overview

- `Goal`: 让 reviewer 在进入细节前先理解 pipeline
- `What to Write`:
  - 按输入、处理阶段、输出讲系统
  - 说明每一步解决哪个 challenge
  - 明确自动化边界和人工边界
- `Evidence`: pipeline consistency；stage interfaces；failure points
- `Figures/Tables`:
  - end-to-end pipeline diagram
  - challenge-to-component mapping table
- `Reviewer Objections`: 图好看但不落地；看完还是不知道核心 insight
- `Transition`: 引到 `Design` 或 `Technique`

## 5. Design / Core Techniques

- `Goal`: 证明方法不是拼装，而是有机制上的新意
- `What to Write`:
  - 按 challenge 分小节
  - 每个小节写 `challenge -> insight -> mechanism -> trade-off -> failure mode`
  - 如果用了 LLM，要明确它做什么、不做什么、如何 grounding / verification
- `Evidence`: mechanism-level reasoning；example walkthrough；why prior solutions fail
- `Figures/Tables`:
  - component internals
  - algorithm flow
  - running example
- `Reviewer Objections`: 只是旧方法组合；heuristic 堆砌；LLM contribution 不可信
- `Transition`: 引到 `Implementation`

## 6. Implementation

- `Goal`: 证明系统可落地，而不是概念
- `What to Write`:
  - 模块、代码规模、instrumentation、runtime environment
  - 工程化选择和替代方案
  - 输入输出接口
  - replay / exploit / witness generation 链路
- `Evidence`: concrete engineering details；why choices are necessary
- `Figures/Tables`:
  - module table
  - implementation footprint table
- `Reviewer Objections`: prototype 痕迹重；细节不足以支持 evaluation
- `Transition`: 引到 `Evaluation Setup`

## 7. Evaluation

- `Goal`: 证明方法有效、可靠、值得采用
- `What to Write`:
  - 优先按 `RQ1 / RQ2 / RQ3` 组织
  - 必须覆盖 targets、benchmarks、baselines、metrics、main effectiveness
  - 还要覆盖 bug findings、ablation、efficiency、scalability、failure analysis
- `Evidence`: apples-to-apples baseline comparison；reproducible setup；confirmed findings
- `Figures/Tables`:
  - benchmark table
  - main result table
  - bug / CVE / confirmation table
  - ablation table
  - cost chart
- `Reviewer Objections`: baseline 不公平；target 偏向自己方法；只有 bug 数没有验证质量
- `Transition`: 引到 `Discussion` 或 `Case Studies`

## 8. Case Studies / Real Findings / Disclosure

- `Goal`: 把“有效”落到“真实而且重要”
- `What to Write`:
  - 选 2-4 个最能代表价值的案例
  - 讲 trigger、root cause、impact、verification、disclosure status
- `Evidence`: exploit trace / witness / patch confirmation / CVE / vendor ack
- `Figures/Tables`:
  - vulnerability timeline table
  - root-cause walkthrough figure
- `Reviewer Objections`: zero-day 价值不高；没有验证真实影响
- `Transition`: 引到 `Discussion / Limitations`

## 9. Discussion / Limitations / Ethics

- `Goal`: 主动管理预期，减少 reviewer 对边界问题的负面解读
- `What to Write`:
  - false positive / false negative sources
  - unsupported targets
  - assumptions that may fail
  - ethical handling and disclosure policy
  - artifact / release constraints
- `Evidence`: honest failure accounting
- `Figures/Tables`: optional limitation matrix
- `Reviewer Objections`: 回避边界问题；对现实部署过于乐观
- `Transition`: 引到 `Related Work`

## 10. Related Work

- `Goal`: 把自己放进路线图里，而不是孤立列论文
- `What to Write`:
  - 按 detection signal 或 automation strategy 分组
  - 不按时间顺序堆列表
  - 最后明确 target、automation depth、bug class、validation quality、real-world findings 这几个差异轴
- `Evidence`: clean comparison dimensions
- `Figures/Tables`: optional comparison matrix
- `Reviewer Objections`: 覆盖不完整；没讲清和最近顶会工作的关系
- `Transition`: 引到 `Conclusion`

## 11. Conclusion

- `Goal`: 收束贡献，不重复摘要
- `What to Write`:
  - 回到研究问题
  - 总结方法和实证价值
  - 给一条可信的 future work
- `Evidence`: 无新增证据
- `Figures/Tables`: 无
- `Reviewer Objections`: 结论空泛
- `Transition`: 结束
