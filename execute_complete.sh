#!/bin/bash

# 设置环境变量
export PATH="$HOME/.moon/bin:$PATH"
export PAGER=cat
export GIT_PAGER=cat
export LESS=
export MORE=

cd /home/engine/project

# 日志文件
LOG_FILE="/tmp/moon_task.log"
OUTPUT_FILE="/tmp/moon_test_output.txt"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "============================================================"
log "开始执行 MoonBit 测试任务"
log "============================================================"

# 第一步：Git pull（已完成）
log ""
log "[第一步] Git pull - 已完成（等待1分钟后执行）"

# 第二步：配置 moonbit 环境
log ""
log "[第二步] 配置 moonbit 环境"

# 检查 moon
if ! command -v moon >/dev/null 2>&1; then
    log "Moon 未安装，正在安装..."
    curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
    if [ $? -eq 0 ]; then
        log "✓ Moon 安装成功"
    else
        log "✗ Moon 安装失败"
        exit 2
    fi
else
    log "✓ Moon 已安装"
fi

# 显示 moon 版本
MOON_VERSION=$(moon --version 2>/dev/null || echo "无法获取版本")
log "Moon 版本: $MOON_VERSION"

# 第三步：执行 moon test
log ""
log "[第三步] 执行 moon test"
log "（这可能需要 1-3 分钟...）"

# 运行测试并保存输出
moon test 2>&1 | tee "$OUTPUT_FILE"
EXIT_CODE=${PIPESTATUS[0]}

log ""
log "测试退出码: $EXIT_CODE"

# 第四步：分析结果
log ""
log "[第四步] 分析测试结果"

# 检查是否包含关键词
if grep -qiE 'error|fatal|panic' "$OUTPUT_FILE"; then
    HAS_ERROR=1
    log "✓ 检测到关键词: error/fatal/panic"
else
    HAS_ERROR=0
    log "✗ 未检测到错误关键词"
fi

# 判断测试是否失败
if [ $HAS_ERROR -eq 1 ] || [ $EXIT_CODE -ne 0 ]; then
    # 分支A：测试失败
    log ""
    log "============================================================"
    log "分支 A：测试失败（或日志包含 error/fatal/panic）"
    log "============================================================"

    if [ $HAS_ERROR -eq 1 ]; then
        log "✓ 检测到关键词: error/fatal/panic"
    fi
    if [ $EXIT_CODE -ne 0 ]; then
        log "✓ 退出码非零: $EXIT_CODE"
    fi

    log ""
    log "接下来的操作:"
    log "1. 检查并消除代码中的死循环"
    log "2. 修复导致失败的问题（只修改业务代码，不修改测试代码）"
    log "3. 运行 python3 scripts/guard_bad_paths.py 清理乱码路径"

    log ""
    log "============================================================"
    log "任务完成：测试失败"
    log "============================================================"

    exit 1
else
    # 分支B：测试通过
    log ""
    log "============================================================"
    log "分支 B：测试通过"
    log "============================================================"

    log ""
    log "接下来的操作:"
    log "1. 运行 python3 scripts/guard_bad_paths.py"
    log "2. 编写新的测试用例（不超过200行）"
    log "3. 如果有文件变动，git commit 提交信息为 '测试通过'"

    # 执行步骤1：运行 guard_bad_paths.py
    log ""
    log "执行步骤1: python3 scripts/guard_bad_paths.py"
    python3 scripts/guard_bad_paths.py 2>&1 | tee -a "$LOG_FILE"

    log ""
    log "============================================================"
    log "任务完成：测试通过"
    log "============================================================"
    log ""
    log "下一步需要："
    log "- 编写新的测试用例（不超过200行）"
    log "- 如果有文件变动，git commit 提交信息为 '测试通过'"

    exit 0
fi
