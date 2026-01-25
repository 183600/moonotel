#!/usr/bin/env python3
"""
任务流程执行脚本
严格按照以下逻辑执行：
1. 等待1分钟，然后运行git pull（已在开始前完成）
2. 配置moonbit环境
3. 执行命令 moon test
4. 根据结果进入分支A或分支B
"""

import subprocess
import os
import sys
import time

def log(message):
    """输出带时间戳的日志"""
    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] {message}")

def run_command(cmd, timeout=180, cwd=None, env=None):
    """运行命令并返回stdout, stderr, returncode"""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=cwd,
            env=env
        )
        return result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired as e:
        return e.stdout or '', e.stderr or '', -1

def main():
    log("="*70)
    log("开始执行任务")
    log("="*70)
    
    # 设置环境
    env = os.environ.copy()
    moon_bin = os.path.expanduser('~/.moon/bin')
    env['PATH'] = moon_bin + ':' + env.get('PATH', '')
    
    project_dir = '/home/engine/project'
    
    # 第一步：Git pull（已在开始前等待1分钟并执行）
    log("\n[第一步] Git pull - 已完成（等待1分钟后执行）")
    
    # 第二步：配置 moonbit 环境
    log("\n[第二步] 配置 moonbit 环境")
    
    # 检查moon是否安装
    stdout, stderr, code = run_command(['which', 'moon'], env=env)
    if code == 0:
        log(f"✓ Moon 已安装在: {stdout.strip()}")
    else:
        log("Moon 未安装，正在安装...")
        stdout, stderr, code = run_command(
            'curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash',
            shell=True,
            timeout=60,
            env=env
        )
        if code == 0:
            log("✓ Moon 安装成功")
        else:
            log(f"✗ Moon 安装失败: {stderr}")
            return 2
    
    # 显示moon版本
    stdout, stderr, code = run_command(['moon', '--version'], timeout=30, env=env)
    if code == 0:
        log(f"Moon 版本: {stdout.strip()}")
    
    # 第三步：执行 moon test
    log("\n[第三步] 执行 moon test")
    log("（这可能需要一些时间...）")
    
    stdout, stderr, code = run_command(
        ['moon', 'test'],
        timeout=180,
        cwd=project_dir,
        env=env
    )
    
    # 合并输出
    full_output = stdout + stderr
    
    # 保存完整输出
    output_file = '/tmp/moon_test_output.txt'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(f"退出码: {code}\n")
        f.write(f"\n{'='*70}\nSTDOUT:\n{'='*70}\n")
        f.write(stdout)
        f.write(f"\n{'='*70}\nSTDERR:\n{'='*70}\n")
        f.write(stderr)
    
    log(f"\n测试退出码: {code}")
    log(f"完整输出已保存到: {output_file}")
    
    # 显示前100行输出
    lines = stdout.split('\n')
    log(f"\n测试输出（前100行）:")
    for i, line in enumerate(lines[:100], 1):
        print(f"{i:4d}: {line}")
    
    if len(lines) > 100:
        log(f"... (总共 {len(lines)} 行)")
    
    # 第四步：分析结果
    log("\n[第四步] 分析测试结果")
    
    # 检查是否包含error/fatal/panic
    has_error_keywords = any(
        keyword in full_output.lower()
        for keyword in ['error', 'fatal', 'panic']
    )
    
    test_failed = has_error_keywords or code != 0
    
    if test_failed:
        # 分支A：测试失败
        log("="*70)
        log("分支 A：测试失败（或日志包含 error/fatal/panic）")
        log("="*70)
        
        if has_error_keywords:
            log("✓ 检测到关键词: error/fatal/panic")
        if code != 0:
            log(f"✓ 退出码非零: {code}")
        
        log("\n接下来的操作:")
        log("1. 检查并消除代码中的死循环")
        log("2. 修复导致失败的问题（只修改业务代码，不修改测试代码）")
        log("3. 运行 python3 scripts/guard_bad_paths.py 清理乱码路径")
        
        return 1
    else:
        # 分支B：测试通过
        log("="*70)
        log("分支 B：测试通过")
        log("="*70)
        
        log("\n接下来的操作:")
        log("1. 运行 python3 scripts/guard_bad_paths.py")
        log("2. 编写新的测试用例（不超过200行）")
        log("3. 如果有文件变动，git commit 提交信息为 '测试通过'")
        
        # 执行步骤1：运行 guard_bad_paths.py
        log("\n执行步骤1: python3 scripts/guard_bad_paths.py")
        stdout, stderr, code = run_command(
            ['python3', 'scripts/guard_bad_paths.py'],
            cwd=project_dir,
            env=env
        )
        
        log(stdout)
        if stderr:
            log(f"警告: {stderr}")
        
        return 0

if __name__ == '__main__':
    try:
        exit_code = main()
        log(f"\n任务完成，退出码: {exit_code}")
        sys.exit(exit_code)
    except Exception as e:
        log(f"!!! 错误: {e} !!!")
        import traceback
        log(traceback.format_exc())
        sys.exit(2)
