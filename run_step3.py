#!/usr/bin/env python3
import os
import subprocess
import sys

# 切换到项目目录
os.chdir('/home/engine/project')

# 设置 PATH
os.environ['PATH'] = os.path.expanduser('~/.moon/bin') + ':' + os.environ.get('PATH', '')

print("=== 第一步：Git pull（已完成）===\n")

print("=== 第二步：配置 moonbit 环境 ===")
# 检查 moon
try:
    result = subprocess.run(
        ['moon', '--version'],
        capture_output=True,
        text=True,
        timeout=30,
        env=os.environ
    )
    print(f"Moon 版本: {result.stdout}")
except FileNotFoundError:
    print("安装 Moon...")
    subprocess.run(
        'curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash',
        shell=True,
        capture_output=True,
        text=True,
        timeout=60
    )

print("\n=== 第三步：执行 moon test ===")
result = subprocess.run(
    ['moon', 'test'],
    capture_output=True,
    text=True,
    timeout=180,
    env=os.environ
)

output = result.stdout + result.stderr

# 保存输出
with open('/tmp/moon_test_output.txt', 'w', encoding='utf-8') as f:
    f.write(f"Exit code: {result.returncode}\n\n")
    f.write(output)

# 显示输出（限制行数以避免过长的输出）
lines = output.split('\n')
if len(lines) > 200:
    print(f"（输出共 {len(lines)} 行，显示前200行）")
    for line in lines[:200]:
        print(line)
    print(f"\n...（剩余 {len(lines)-200} 行未显示）...")
else:
    print(output)

print(f"\n测试退出码: {result.returncode}")

# 第四步：分析结果
print("\n=== 第四步：分析结果 ===")
has_error = any(word in output.lower() for word in ['error', 'fatal', 'panic'])

if has_error or result.returncode != 0:
    print("=" * 60)
    print("分支A: 测试失败")
    print("=" * 60)
    if has_error:
        print("✗ 输出中包含 error/fatal/panic 关键词")
    if result.returncode != 0:
        print(f"✗ 测试返回非零退出码: {result.returncode}")
    print("\n需要执行:")
    print("1. 检查并消除代码中的死循环")
    print("2. 修复导致失败的问题（只修改业务代码）")
    print("3. 运行 python3 scripts/guard_bad_paths.py")
    sys.exit(1)
else:
    print("=" * 60)
    print("分支B: 测试通过")
    print("=" * 60)
    print("需要执行:")
    print("1. 运行 python3 scripts/guard_bad_paths.py")
    print("2. 编写新的测试用例（不超过200行）")
    print("3. git commit 提交信息为 '测试通过'")
    sys.exit(0)
