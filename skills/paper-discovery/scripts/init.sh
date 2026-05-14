#!/usr/bin/env bash
# 初始化脚本 - 加载配置和设置路径变量
# 用法: source scripts/init.sh

# 获取 Skill 根目录
if [[ -n "${CLAUDE_SKILL_ROOT:-}" ]]; then
    # 由 Claude Code 自动设置
    SKILL_ROOT="${CLAUDE_SKILL_ROOT}"
else
    # 手动运行时推导
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
fi

# 避免污染调用方会话：不在这里强制导出/覆盖 CLAUDE_SKILL_ROOT
# 内部统一使用 PAPER_DISCOVERY_SKILL_ROOT。
export PAPER_DISCOVERY_SKILL_ROOT="$SKILL_ROOT"

# 加载 .env 文件（如果存在）
if [[ -f "$SKILL_ROOT/.env" ]]; then
    set -a
    source "$SKILL_ROOT/.env"
    set +a
fi

# 设置数据目录
export SKILL_DATA_DIR="$SKILL_ROOT/data"

# 统一 python 解释器选择（优先 python3）
if command -v python3 >/dev/null 2>&1; then
    export PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    export PYTHON_BIN="python"
else
    export PYTHON_BIN=""
fi

# Rate limit 配置（兼容无 /tmp 的环境）
if [[ -d "${TMPDIR:-}" ]]; then
    export S2_RATE_LIMIT_FILE="${TMPDIR}/.s2_rate_limit"
elif [[ -d "/tmp" ]]; then
    export S2_RATE_LIMIT_FILE="/tmp/.s2_rate_limit"
else
    mkdir -p "$SKILL_ROOT/.tmp"
    export S2_RATE_LIMIT_FILE="$SKILL_ROOT/.tmp/.s2_rate_limit"
fi
export S2_MIN_INTERVAL="${S2_MIN_INTERVAL:-1}"  # 默认 1 秒

# 颜色输出（可选）
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m' # No Color

# 辅助函数：打印错误
error_msg() {
    echo -e "${RED}Error:${NC} $1" >&2
}

# 辅助函数：打印警告
warn_msg() {
    echo -e "${YELLOW}Warning:${NC} $1" >&2
}

# 辅助函数：打印成功
success_msg() {
    echo -e "${GREEN}✓${NC} $1"
}

# --- Visualizer 状态写入支持 ---
# 默认将状态写入当前 skill 目录下的 status.json，
# 可通过环境变量 VISUALIZER_STATUS_FILE 覆盖。
VISUALIZER_STATUS_FILE="${VISUALIZER_STATUS_FILE:-$PAPER_DISCOVERY_SKILL_ROOT/../paper-visualizer/status.json}"
VISUALIZER_HISTORY_FILE="${VISUALIZER_HISTORY_FILE:-$PAPER_DISCOVERY_SKILL_ROOT/../paper-visualizer/status-history.jsonl}"

# 为单次执行生成稳定 run_id（可由外部预设覆盖）
if [[ -z "${VISUALIZER_RUN_ID:-}" ]]; then
    if date +%s >/dev/null 2>&1; then
        VISUALIZER_RUN_ID="run-$(date +%s)-$$"
    else
        VISUALIZER_RUN_ID="run-$$"
    fi
fi

# 写入 JSON 内容到可视化状态文件。
# 用法：
#   write_status_json '{"state":"running","main_step":"多源检索","sub_steps":[]}'
# 或通过标准输入：
#   echo '{...}' | write_status_json
write_status_json() {
    local dest="${VISUALIZER_STATUS_FILE}"
    local payload
    if [[ -z "$1" ]]; then
        # read from stdin
        payload="$(cat -)"
        printf '%s\n' "$payload" >"$dest"
    else
        payload="$1"
        printf '%s\n' "$payload" >"$dest"
    fi

    mkdir -p "$(dirname "$VISUALIZER_HISTORY_FILE")" 2>/dev/null || true
    if [[ -n "$payload" ]]; then
        # Try to normalize payload JSON and map known ids to friendly names using Python if available.
        if [[ -n "${PYTHON_BIN:-}" ]] && command -v "$PYTHON_BIN" >/dev/null 2>&1; then
            mapped="$(printf '%s' "$payload" | "$PYTHON_BIN" -c '
import sys, json, re
s = sys.stdin.read()
try:
    d = json.loads(s)
except Exception:
    print(s)
    sys.exit(0)

idmap = {
    "zotero-mcp": "检查 Zotero 可用性",
    "zotero": "Zotero 操作",
    "openalex": "OpenAlex 检索",
    "semantic_scholar": "Semantic Scholar 检索",
    "google_scholar": "Google Scholar 检索",
    "arxiv": "arXiv 检索",
    "merge": "合并与去重",
    "dedupe": "去重",
}

def slug_to_label(x):
    if not x: return x
    x = re.sub(r"[\-_\.]+", " ", x)
    parts = [p.capitalize() for p in x.split() if p]
    return " ".join(parts)

def id_to_label(x):
    if not x: return x
    k = x.lower()
    if k in idmap:
        return idmap[k]
    for key in idmap:
        if key in k:
            return idmap[key]
    return slug_to_label(x)

# Normalize sub_steps
if isinstance(d, dict):
    if "sub_steps" in d and isinstance(d["sub_steps"], list):
        new_sub = []
        for item in d["sub_steps"]:
            if isinstance(item, str):
                new_sub.append({"id": item, "name": id_to_label(item)})
            elif isinstance(item, dict):
                if ("name" not in item or not item.get("name")) and item.get("id"):
                    item["name"] = id_to_label(item.get("id"))
                new_sub.append(item)
            else:
                new_sub.append(item)
        d["sub_steps"] = new_sub

    for listkey in ("available_tools", "missing_tools"):
        if listkey in d and isinstance(d[listkey], list):
            new_list = []
            for t in d[listkey]:
                if isinstance(t, str):
                    new_list.append({"id": t, "name": id_to_label(t)})
                elif isinstance(t, dict):
                    if ("name" not in t or not t.get("name")) and t.get("id"):
                        t["name"] = id_to_label(t.get("id"))
                    new_list.append(t)
                else:
                    new_list.append(t)
            d[listkey] = new_list

    
    try:
        out = json.dumps(d, ensure_ascii=False)
        print(out)
    except Exception:
        print(s)
')"
            # If python produced output, replace payload
            if [[ -n "$mapped" ]]; then
                payload="$mapped"
            fi
        fi

        # Ensure run_id present in payload JSON when appending to history
        if printf '%s' "$payload" | grep -q '"run_id"'; then
            printf '%s\n' "$payload" >>"$VISUALIZER_HISTORY_FILE"
        else
            # Inject run_id field at the start of JSON object
            payload="$(printf '%s' "$payload" | sed 's/^{/{"run_id":"'"$VISUALIZER_RUN_ID"'",/')"
            printf '%s\n' "$payload" >"$dest"
            printf '%s\n' "$payload" >>"$VISUALIZER_HISTORY_FILE"
        fi
    fi
}

# 简单构造状态并写入（最小字段）。
# 用法： write_status STATE MAIN_STEP
# 例如： write_status running "多源检索"
write_status() {
    local state="$1"
    local main_step="$2"
    local ts
    if date --iso-8601=seconds >/dev/null 2>&1; then
        ts=$(date --iso-8601=seconds)
    else
        ts=$(date +%s)
    fi
    cat >"${VISUALIZER_STATUS_FILE}" <<EOF
{
  "run_id": "${VISUALIZER_RUN_ID}",
  "state": "${state}",
  "main_step": "${main_step}",
  "updated": "${ts}"
}
EOF

    mkdir -p "$(dirname "$VISUALIZER_HISTORY_FILE")" 2>/dev/null || true
    cat >>"${VISUALIZER_HISTORY_FILE}" <<EOF
{"run_id":"${VISUALIZER_RUN_ID}","state":"${state}","main_step":"${main_step}","updated":"${ts}"}
EOF
}

# 结束 Visualizer 支持
