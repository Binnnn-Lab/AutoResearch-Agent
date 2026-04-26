---
name: paper-discovery-assistant
description: Use when the user needs systematic paper discovery, security-focused related-work search, literature review generation, reading-list construction, citation-network expansion, Zotero-backed paper collection, BibTeX generation, or venue/author quality checks. Triggers include 论文查找、找相关工作、paper discovery、related papers、reading list、citation network、沿引用扩展、Semantic Scholar 推荐、文献综述检索、网络安全论文、USENIX Security、CCS、NDSS、S&P、bib、参考文献。
---
# Paper Discovery Assistant

This file is a routing entry only.
Do not place long workflow details here.

## Role of This File

- Trigger the paper-discovery skill.
- Define hard boundaries and non-negotiable constraints.
- Route execution to gate and step files.

## Single Source of Execution Truth

Claude Code must follow this order for every discovery/review task:

1. Read `EXECUTION_GATES.md`.
2. Read the current step file in `execution-steps/` before executing that step.
3. Execute in exact step order only.
4. Emit checkpoint evidence after each step.

If any statement in this file conflicts with `EXECUTION_GATES.md` or `execution-steps/*.md`, gate/step files win.

## Automatic Execution Directive (When Skill is Triggered)

**UPON TRIGGERING this skill (e.g., user says "帮我找论文", "paper discovery", "查找相关工作"):**

Claude Code MUST **automatically** execute the full four-source search protocol in Step 03:

1. **NO USER CONFIRMATION REQUIRED** between sources
2. **Execute sequentially**: OpenAlex → Semantic Scholar → arXiv → Google Scholar (2025-2026)
3. **Complete all four** before proceeding to Step 04
4. **Do NOT ask**: "Should I continue?", "Is this enough?", "Do you want me to search other sources?"
5. **Self-enforce completion**: Even if user only said "找几篇论文", still execute ALL four sources

**This is automatic behavior - user does NOT need to explicitly request "use all four sources".**

## Hard Constraints

- Do not skip or reorder steps.
- Do not claim completed work without current-session evidence.
- Use repository scripts under `scripts/` only. No ad-hoc scraping.
- `scripts/run_pipeline.sh` is removed and must not be invoked.
- **Mandatory four-source retrieval order** (ALL REQUIRED, NO EXCEPTIONS, AUTOMATIC):
  1. OpenAlex - primary academic source
  2. Semantic Scholar - extended academic coverage  
  3. arXiv - preprint repository
  4. **Google Scholar (recent 2-year)** - mandatory recent two-year coverage (e.g., 2025-2026)
  
  **CRITICAL**: ALL four sources MUST be executed. Cannot skip any source even if others returned sufficient results. Google Scholar is NOT optional supplementation - it is the required source for recent 2-year papers.
- **Mandatory verification workflow** (NO EXCEPTIONS):
  1. Step 04: Deduplicate candidates
  2. Step 05: Generate BibTeX + Verify citations (`generate_bibtex.sh` -> `verify_citations.sh` -> `filter_verified.sh`)
  3. **CRITICAL**: Only VERIFIED papers from Step 05 can be imported to Zotero in Step 06
  4. SUSPICIOUS/HALLUCINATED papers must NOT be imported
- Zotero Ingest (Step 06) is BLOCKED until verification (Step 05) completes.
- If Zotero tools are missing, auto-repair once, then re-preflight.

## Required Preflight Inputs

Before retrieval/synthesis/file generation/ingest:

- Read `execution-steps/00-session-preflight.md`
- Read `ZOTERO_INGEST_TEMPLATE.md`
- Report preflight fields:
  - attempted=true
  - connected=true|false
  - available_tools=[...]
  - missing_tools=[...]
  - auto_repair_attempted=true|false
  - reason (when failed)

## Script Capability Map (Atomic Building Blocks)

- Query: `expand_queries.sh`
- Source search: `openalex_search.sh`, `s2_search.sh`, `s2_bulk_search.sh`, `arxiv_search.sh`
- Merge/search helper: `multi_search.sh`, `multi_query_search.sh`, `multi_search.ps1`
- Citation quality: `generate_bibtex.sh`, `verify_citations.sh`, `filter_verified.sh`
- Expansion: `s2_recommend.sh`, `s2_citations.sh`, `s2_references.sh`
- Metadata/quality helper: `doi2bibtex.sh`, `crossref_search.sh`, `venue_info.sh`, `author_info.sh`, `ccf_lookup.sh`, `if_lookup.sh`
- Mandatory fourth source (2025-2026 coverage): `google_scholar_search.py`

## Output Defaults

- `literature-review.md`
- `references.bib`
- `research-proposal.md` only if user explicitly requests

