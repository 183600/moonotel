#!/usr/bin/env bash
set -euo pipefail

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIBE_CODING_SCRIPT="${SCRIPT_DIR}/scripts/vibe_coding.sh"

# 检查 vibe_coding.sh 是否存在
if [[ ! -f "$VIBE_CODING_SCRIPT" ]]; then
  echo "ERROR: vibe_coding.sh not found at: $VIBE_CODING_SCRIPT"
  exit 1
fi

# 使 vibe_coding.sh 可执行
chmod +x "$VIBE_CODING_SCRIPT"

# 日志函数
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

log "Starting vibe_coding.sh..."

# 反复运行 vibe_coding.sh
# 由于 vibe_coding.sh 内部已经有无限循环，这里只需要启动一次
# 如果需要在脚本异常退出时重启，可以加上外层循环
while true; do
  log "Launching vibe_coding.sh..."
  
  # 运行 vibe_coding.sh
  bash "$VIBE_CODING_SCRIPT" || {
    exit_code=$?
    log "WARNING: vibe_coding.sh exited with code $exit_code"
    log "Restarting in 60 seconds..."
    sleep 60
  }
done
