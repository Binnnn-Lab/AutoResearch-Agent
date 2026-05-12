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
VISUALIZER_STATUS_FILE="${VISUALIZER_STATUS_FILE:-$PAPER_DISCOVERY_SKILL_ROOT/status.json}"
VISUALIZER_HISTORY_FILE="${VISUALIZER_HISTORY_FILE:-$PAPER_DISCOVERY_SKILL_ROOT/status-history.jsonl}"

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
        if printf '%s' "$payload" | grep -q '"run_id"'; then
            printf '%s\n' "$payload" >>"$VISUALIZER_HISTORY_FILE"
        else
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
