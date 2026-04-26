# Step 00 - Session Preflight (Hard Gate)

## Must Read Before Execute

- `SKILL.md`
- `ZOTERO_INGEST_TEMPLATE.md`

## Required Actions

0. Check script runtime readiness before any retrieval:
   - `bash` executable available
   - `python`/`python3` executable available
   - `jq` and `curl` available for shell chain
   - if not available, mark blocker and stop
1. Probe Zotero MCP tool visibility in current session.
2. If missing required tools, run one auto-repair attempt:
   - `claude mcp add --transport http zotero-mcp http://127.0.0.1:23120/mcp`
   - `claude mcp list`
   - re-probe tool visibility
3. Produce mandatory preflight report fields:
   - `attempted=true`
   - `connected=true|false`
   - `available_tools=[...]`
   - `missing_tools=[...]`
   - `auto_repair_attempted=true|false`
   - `reason=...` (only when failed)

## Hard Stop Condition

Do not run retrieval, synthesis, file generation, or ingest before this step is fully reported.

## Detailed Guidance (Restored)

- This preflight is mandatory even when users claim Zotero is already connected.
- General web search is not a default branch; it is allowed only after script-chain failure is explicitly reported.
- If Zotero remains unavailable after auto-repair, continue script workflow but carry `missing_tools` and failure reason into final deliverables.
