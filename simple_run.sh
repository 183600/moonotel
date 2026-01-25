#!/bin/bash
export PATH="$HOME/.moon/bin:$PATH"
cd /home/engine/project

# 检查并安装 moon
if ! command -v moon &> /dev/null 2>&1; then
    curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
fi

# 运行 moon test 并保存输出
moon test > /tmp/moon_output.txt 2>&1
exit_code=$?

# 输出结果
cat /tmp/moon_output.txt

# 检查是否包含 error/fatal/panic
if grep -iqE "error|fatal|panic" /tmp/moon_output.txt; then
    echo "FAILED: Contains error/fatal/panic"
    exit 1
fi

exit $exit_code
