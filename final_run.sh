#!/bin/bash
cd /home/engine/project

# 设置PATH
export PATH="$HOME/.moon/bin:$PATH"

# 检查moon
if ! command -v moon &> /dev/null; then
    echo "Installing moon..."
    curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
fi

echo "Running moon test..."
moon test 2>&1 | tee /tmp/moon_test_output.txt
EXIT_CODE=$?

echo "Exit code: $EXIT_CODE"

# 检查关键词
if grep -qiE 'error|fatal|panic' /tmp/moon_test_output.txt; then
    echo "FAILED: Contains error/fatal/panic"
    exit 1
fi

exit $EXIT_CODE
