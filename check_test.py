#!/usr/bin/env python3
import subprocess
import sys
import os

os.chdir('/home/engine/project')

# 设置 PATH
env = os.environ.copy()
env['PATH'] = os.path.expanduser('~/.moon/bin') + ':' + env.get('PATH', '')

# 等待已经完成，现在运行测试
print("Running moon test...")
result = subprocess.run(
    ['moon', 'test'],
    env=env,
    capture_output=True,
    text=True,
    timeout=180
)

output = result.stdout + result.stderr

# 检查结果
has_error = any(word in output.lower() for word in ['error', 'fatal', 'panic'])

if has_error or result.returncode != 0:
    print("FAILED")
    sys.exit(1)
else:
    print("PASSED")
    sys.exit(0)
