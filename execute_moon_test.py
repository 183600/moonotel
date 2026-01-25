#!/usr/bin/env python3
import subprocess
import os
import sys

def run_command(cmd, shell=False, timeout=None, cwd=None, env=None):
    """运行命令并返回结果"""
    if shell:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=cwd,
            env=env
        )
    else:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=cwd,
            env=env
        )
    return result.stdout, result.stderr, result.returncode

def main():
    project_dir = '/home/engine/project'
    moon_bin = os.path.expanduser('~/.moon/bin')
    
    # 设置环境变量
    env = os.environ.copy()
    env['PATH'] = moon_bin + ':' + env.get('PATH', '')
    env['PAGER'] = ''  # 禁用分页器
    
    # 步骤1：检查并安装moon（如果需要）
    print("\n" + "="*60)
    print("步骤1: 检查 Moon 安装")
    print("="*60)
    
    stdout, stderr, code = run_command(['which', 'moon'], env=env)
    
    if code == 0:
        print(f"✓ Moon 已安装: {stdout.strip()}")
    else:
        print("✗ Moon 未安装，正在安装...")
        install_cmd = 'curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash'
        stdout, stderr, code = run_command(install_cmd, shell=True, timeout=60, env=env)
        if code != 0:
            print(f"安装失败: {stderr}")
            return 2
        print("✓ Moon 安装完成")
    
    # 显示moon版本
    stdout, stderr, code = run_command(['moon', '--version'], timeout=30, env=env)
    if code == 0:
        print(f"Moon 版本: {stdout.strip()}")
    else:
        print(f"警告: 无法获取 Moon 版本: {stderr}")
    
    # 步骤2：运行 moon test
    print("\n" + "="*60)
    print("步骤2: 运行 Moon 测试")
    print("="*60)
    print("（这可能需要一些时间...）\n")
    
    stdout, stderr, code = run_command(
        ['moon', 'test'],
        timeout=180,
        cwd=project_dir,
        env=env
    )
    
    # 合并输出
    full_output = stdout + stderr
    
    # 保存完整输出到文件
    with open('/tmp/moon_test_full_output.txt', 'w', encoding='utf-8') as f:
        f.write(f"退出码: {code}\n")
        f.write(f"\n{'='*60}\n")
        f.write("STDOUT:\n")
        f.write(f"{'='*60}\n")
        f.write(stdout)
        f.write(f"\n{'='*60}\n")
        f.write("STDERR:\n")
        f.write(f"{'='*60}\n")
        f.write(stderr)
    
    # 显示摘要
    lines = stdout.split('\n')
    
    # 查找测试结果
    test_lines = [line for line in lines if 'test' in line.lower() or 'pass' in line.lower() or 'fail' in line.lower()]
    
    if test_lines:
        print("\n测试相关输出:")
        for line in test_lines[:50]:  # 显示前50行
            print(line)
    else:
        print("\n前100行输出:")
        for line in lines[:100]:
            print(line)
    
    if len(lines) > 100:
        print(f"\n... (总共 {len(lines)} 行)")
    
    # 步骤3：分析结果
    print("\n" + "="*60)
    print("步骤3: 分析测试结果")
    print("="*60)
    
    has_error_keywords = any(
        keyword in full_output.lower()
        for keyword in ['error', 'fatal', 'panic']
    )
    
    print(f"退出码: {code}")
    print(f"包含 error/fatal/panic: {'是' if has_error_keywords else '否'}")
    print(f"输出文件: /tmp/moon_test_full_output.txt")
    
    # 决定分支
    if has_error_keywords or code != 0:
        print("\n" + "="*60)
        print("分支 A: 测试失败")
        print("="*60)
        print("\n需要执行以下步骤:")
        print("1. 检查并消除代码中的死循环")
        print("2. 修复导致失败的问题（只修改业务代码，不修改测试代码）")
        print("3. 修复后运行: python3 scripts/guard_bad_paths.py")
        return 1
    else:
        print("\n" + "="*60)
        print("分支 B: 测试通过")
        print("="*60)
        print("\n需要执行以下步骤:")
        print("1. 运行: python3 scripts/guard_bad_paths.py")
        print("2. 编写新的测试用例（不超过200行）")
        print("3. 如果有文件变动，git commit 提交信息为 '测试通过'")
        return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except subprocess.TimeoutExpired:
        print("\n错误: moon test 超时（180秒）")
        sys.exit(2)
    except Exception as e:
        print(f"\n错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(2)
