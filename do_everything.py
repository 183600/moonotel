#!/usr/bin/env python3
import subprocess
import os
import sys

os.chdir('/home/engine/project')
os.environ['PATH'] = os.path.expanduser('~/.moon/bin:') + os.environ.get('PATH', '')

# 第一步：已经等待1分钟并执行了git pull

# 第二步：配置 moonbit 环境
print("\n=== 配置 moonbit 环境 ===")
try:
    result = subprocess.run(['moon', '--version'], capture_output=True, text=True, timeout=30)
    print(f"Moon 版本: {result.stdout}")
except:
    print("安装 moon...")
    subprocess.run('curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash', shell=True, timeout=60)

# 第三步：执行 moon test
print("\n=== 执行 moon test ===")
result = subprocess.run(['moon', 'test'], capture_output=True, text=True, timeout=180)

output = result.stdout + result.stderr
with open('/tmp/moon_test_output.txt', 'w') as f:
    f.write(output)

print(output)
print(f"\n退出码: {result.returncode}")

# 第四步：分析结果
print("\n=== 分析结果 ===")
has_error = any(word in output.lower() for word in ['error', 'fatal', 'panic'])

if has_error or result.returncode != 0:
    print("分支A: 测试失败")
    print("需要检查和修复代码中的死循环，然后运行 guard_bad_paths.py")
    sys.exit(1)
else:
    print("分支B: 测试通过")
    print("需要运行 guard_bad_paths.py，编写新测试，提交代码")
    sys.exit(0)
