# Zotero Ingest Template (Claude Code + MCP)

This template is for sessions where Zotero MCP tools are available.

## 1. Preconditions

- MCP preflight must be attempted first in current session (HARD GATE).
- Do not start retrieval, file generation, or ingest before preflight result is reported.
- If Zotero tools are missing, auto-repair must be attempted before declaring failure:
  - `claude mcp add --transport http zotero-mcp http://127.0.0.1:23120/mcp`
  - `claude mcp list`
  - Run preflight again in the same task.
- Preflight report fields are mandatory:
   - `attempted=true`
   - `connected=true|false`
   - `available_tools=[...]`
   - `missing_tools=[...]`
   - `auto_repair_attempted=true|false`
   - `reason` (when failed)

- Search and verification already completed, with candidate and verification data available
   (from stdout pipeline, in-memory objects, or temporary files when needed).
   Persisted files are optional and should only be kept when explicitly requested.
- MCP tools are visible in current session:
  - `create_collection`
  - `add_items_by_doi`
  - `find_and_attach_pdfs`

## 2. Recommended Ingest Policy

- Ingest order: `VERIFIED` first, then optional `SUSPICIOUS`.
- Prefer DOI import. If DOI missing, use metadata fallback.
- Attach PDFs immediately after item creation.
- Apply collection/tags consistently for later review.
- Interaction mode: single confirmation + batch ingest. Do not ask for confirmation per paper.
- Batch size recommendation: 20-50 items per `add_items_by_doi` call (or per ingest round), then summarize success/failure per batch.
- If a batch fails, ask once for batch-level retry/skip decision; do not fall back to per-item prompts unless explicitly requested.
- If preflight is successful but a batch import fails, re-run preflight and retry that batch once before asking user-level decision.

## 3. Collection Taxonomy

When classifying papers into Zotero, strictly adhere to the following naming convention and structure:

- Derive 3-5 specific sub-collections from the research question.
- Format sub-collection names logically with a zero-padded sequential prefix and hyphen-separated lowercase words (kebab-case).
- Examples from ICS protocol & vulnerability detection domain:
  - `01-state-machine-bugs`
  - `02-stateful-fuzzing-and-symbolic-execution`
  - `03-protocol-inference-and-spec-mining`
  - `04-ics-protocol-security`
  - `05-llm-assisted-rule-generation`

## 4. Execution Checklist

1. Create top-level collection for current topic.
2. Parse verification results and build two lists: VERIFIED and SUSPICIOUS.
3. Build the numbered taxonomy of sub-collections based on the current context.
4. For VERIFIED entries:
   - If DOI exists: call `add_items_by_doi`.
   - Put each item into the appropriate numbered target sub-collection.
   - Call `find_and_attach_pdfs`.
   - Record URL for each item (DOI URL preferred, else publisher/arXiv URL).
   - Add tags: `route_a_graph`, `route_b_systematic`, `both` (if known).
5. For SUSPICIOUS entries (optional):
   - Ingest into a separate review collection (e.g., `99-needs-manual-check`).
6. Produce ingest report:
   - Total candidates
   - Imported by DOI count
   - PDF attached count
   - URL recorded count
   - Failed attachment reasons
   - Auto-repair attempted or not
   - Retry attempted or not
   - Failure categories (`tool-missing` / `permission` / `network` / `invalid-doi` / `rate-limit`)

## 5. Suggested Prompt for Claude Code

Use this prompt in a session that has Zotero MCP tools:

"""
I have verification results and cleaned candidate references ready.
Please ingest VERIFIED papers into Zotero collection `Paper Discovery/<topic>`.
Create sequentially numbered sub-collections like `01-state-machine-bugs`, `02-protocol-inference`, etc., 
and place items accordingly.
Attach PDFs for each imported item, and output a final import report with failures.
For SUSPICIOUS papers, place them into `Needs Manual Check`.
"""

## 5. Notes

- Shell scripts in this repository do not connect to Zotero directly.
- Zotero operations are performed by MCP tools exposed to Claude Code in the active session.
- If preflight fails or MCP tools are unavailable after auto-repair attempt, continue script workflow and include failure reason and missing tools list in every deliverable; keep `literature-review.md` as the only persisted default output. Generate files like `references_clean.bib` only when explicitly requested.
- For file deliverable workflows (literature review / research plan / related work dossier / systematic review), generate `references.bib` as the canonical bibliography output together with `literature-review.md`.
- If the user explicitly requests a research proposal, generate `research-proposal.md` with Research question, Background, Proposed method, and Expected contributions.
