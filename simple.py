#!/usr/bin/env python3
import subprocess
import os
import sys

os.chdir('/home/engine/project')
env = os.environ.copy()
env['PATH'] = os.path.expanduser('~/.moon/bin') + ':' + env.get('PATH', '')

# 安装 moon 如果需要
try:
    subprocess.run(['moon', '--version'], env=env, capture_output=True, text=True, timeout=30)
except:
    subprocess.run('curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash', shell=True, env=env, capture_output=True)

# 运行测试
result = subprocess.run(['moon', 'test'], env=env, capture_output=True, text=True, timeout=180)

output = result.stdout + result.stderr
has_error = any(word in output.lower() for word in ['error', 'fatal', 'panic'])

# 保存结果
with open('/tmp/result.txt', 'w') as f:
    f.write(f'exit_code={result.returncode}\n')
    f.write(f'has_error={has_error}\n')
    f.write(f'output_length={len(output)}\n')

# 显示前200行
lines = output.split('\n')
for i, line in enumerate(lines[:200], 1):
    print(f"{i:3d}: {line}")

if has_error or result.returncode != 0:
    print("\nFAILED")
    sys.exit(1)
else:
    print("\nPASSED")
    sys.exit(0)
