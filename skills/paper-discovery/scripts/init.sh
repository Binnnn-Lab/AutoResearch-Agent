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
