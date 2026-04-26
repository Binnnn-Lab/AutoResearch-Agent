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
   - Read ZOTERO_MCP_URL and ZOTERO_MCP_TRANSPORT from environment or .env file
   - Default values: URL=`http://127.0.0.1:23120/mcp`, TRANSPORT=`http`
   - Run: `claude mcp add --transport $ZOTERO_MCP_TRANSPORT zotero-mcp $ZOTERO_MCP_URL`
   - Run: `claude mcp list`
   - Re-probe tool visibility
   - If auto-repair fails, report the configured URL to user for manual verification
3. Produce mandatory preflight report fields:
   - `attempted=true`
   - `connected=true|false`
   - `available_tools=[...]`
   - `missing_tools=[...]`
   - `auto_repair_attempted=true|false`
   - `reason=...` (only when failed)

## Hard Stop Condition

Do not run retrieval, synthesis, file generation, or ingest before this step is fully reported.

## Zotero MCP Configuration Guide

### Default Configuration
- **URL**: `http://127.0.0.1:23120/mcp` (local machine, default port)
- **Transport**: `http`

### Custom Configuration (for different setups)

Edit `.env` file in skill root directory:

```bash
# If Zotero runs on different port
ZOTERO_MCP_URL="http://127.0.0.1:8080/mcp"

# If Zotero runs on different machine (e.g., remote server)
ZOTERO_MCP_URL="http://192.168.1.100:23120/mcp"

# Transport protocol (currently only http is supported)
ZOTERO_MCP_TRANSPORT="http"
```

### Common Scenarios

1. **Standard local setup**: Use defaults (no changes needed)
2. **Different port**: Change only the port number in URL
3. **Remote Zotero**: Update IP address and ensure network connectivity
4. **Docker/container**: Use container name or host IP instead of localhost

### Troubleshooting

If auto-repair fails:
1. Check if Zotero is running
2. Verify the configured URL matches your Zotero MCP setup
3. Test connection manually: `curl $ZOTERO_MCP_URL`
4. Check firewall settings for remote connections

## Detailed Guidance (Restored)

- This preflight is mandatory even when users claim Zotero is already connected.
- General web search is not a default branch; it is allowed only after script-chain failure is explicitly reported.
- If Zotero remains unavailable after auto-repair, continue script workflow but carry `missing_tools` and failure reason into final deliverables.
