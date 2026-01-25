#!/bin/bash

# 设置环境
export PATH="$HOME/.moon/bin:$PATH"

# 检查 moon 是否存在
if ! command -v moon &> /dev/null; then
    echo "Moon not found, installing..."
    curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
fi

echo "=== Moon version ==="
moon --version

echo ""
echo "=== Running moon test ==="
cd /home/engine/project
moon test 2>&1 | tee /tmp/moon_test_output.log
