#!/usr/bin/env python3
"""
最终任务执行脚本
"""
import subprocess
import os
import sys
import time
from pathlib import Path

def setup_environment():
    """设置环境变量"""
    env = os.environ.copy()
    moon_bin = str(Path.home() / '.moon' / 'bin')
    env['PATH'] = moon_bin + ':' + env.get('PATH', '')
    # 禁用所有分页器
    env['PAGER'] = 'cat'
    env['GIT_PAGER'] = 'cat'
    env['LESS'] = ''
    env['MORE'] = ''
    return env

def run_subprocess(cmd, shell=False, cwd=None, env=None, timeout=180):
    """运行子进程并返回结果"""
    try:
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
    except subprocess.TimeoutExpired:
        return '', 'Command timed out', -1

def log(message):
    """输出日志"""
    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] {message}")

def main():
    # 设置日志文件
    log_file = Path('/tmp/moon_task_log.txt')
    
    def log_to_file(msg):
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(msg + '\n')
        print(msg)
    
    log_to_file("="*70)
    log_to_file("开始执行 MoonBit 测试任务")
    log_to_file("="*70)
    
    # 设置环境
    env = setup_environment()
    project_dir = Path('/home/engine/project')
    
    # ===== 第一步：Git pull（已在开始前等待1分钟并执行） =====
    log_to_file("\n[第一步] Git pull - 已完成（等待1分钟后执行）")
    
    # ===== 第二步：配置 moonbit 环境 =====
    log_to_file("\n[第二步] 配置 moonbit 环境")
    
    # 检查moon是否安装
    stdout, stderr, code = run_subprocess(['which', 'moon'], env=env)
    if code == 0:
        log_to_file(f"✓ Moon 已安装在: {stdout.strip()}")
    else:
        log_to_file("Moon 未安装，正在安装...")
        stdout, stderr, code = run_subprocess(
            'curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash',
            shell=True,
            timeout=60,
            env=env
        )
        if code == 0:
            log_to_file("✓ Moon 安装成功")
        else:
            log_to_file(f"✗ Moon 安装失败: {stderr}")
            return 2
    
    # 获取moon版本
    stdout, stderr, code = run_subprocess(['moon', '--version'], timeout=30, env=env)
    if code == 0:
        log_to_file(f"Moon 版本: {stdout.strip()}")
    
    # ===== 第三步：执行 moon test =====
    log_to_file("\n[第三步] 执行 moon test")
    log_to_file("（这可能需要 1-3 分钟...）")
    
    stdout, stderr, code = run_subprocess(
        ['moon', 'test'],
        timeout=180,
        cwd=project_dir,
        env=env
    )
    
    full_output = stdout + stderr
    
    # 保存完整输出
    output_file = Path('/tmp/moon_test_output.txt')
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(f"退出码: {code}\n")
        f.write(f"\n{'='*70}\nSTDOUT ({len(stdout)} 字符):\n{'='*70}\n")
        f.write(stdout)
        if stderr:
            f.write(f"\n{'='*70}\nSTDERR ({len(stderr)} 字符):\n{'='*70}\n")
            f.write(stderr)
    
    log_to_file(f"\n测试退出码: {code}")
    log_to_file(f"STDOUT 长度: {len(stdout)} 字符")
    if stderr:
        log_to_file(f"STDERR 长度: {len(stderr)} 字符")
    log_to_file(f"完整输出已保存到: {output_file}")
    
    # 显示前150行
    lines = stdout.split('\n')
    log_to_file(f"\n测试输出（前150行）:")
    for i, line in enumerate(lines[:150], 1):
        print(f"{i:4d}: {line}")
    if len(lines) > 150:
        log_to_file(f"... (总共 {len(lines)} 行)")
    
    # ===== 第四步：分析结果 =====
    log_to_file("\n[第四步] 分析测试结果")
    
    # 检查关键词
    keywords = ['error', 'fatal', 'panic']
    found_keywords = [kw for kw in keywords if kw in full_output.lower()]
    
    has_error = len(found_keywords) > 0
    test_failed = has_error or code != 0
    
    if test_failed:
        # ===== 分支A：测试失败 =====
        log_to_file("="*70)
        log_to_file("分支 A：测试失败（或日志包含 error/fatal/panic）")
        log_to_file("="*70)
        
        if found_keywords:
            log_to_file(f"✓ 检测到关键词: {', '.join(found_keywords)}")
        if code != 0:
            log_to_file(f"✓ 退出码非零: {code}")
        
        log_to_file("\n接下来的操作:")
        log_to_file("1. 检查并消除代码中的死循环")
        log_to_file("2. 修复导致失败的问题（只修改业务代码，不修改测试代码）")
        log_to_file("3. 运行 python3 scripts/guard_bad_paths.py 清理乱码路径")
        
        log_to_file("\n" + "="*70)
        log_to_file("任务完成：测试失败")
        log_to_file("="*70)
        
        return 1
    else:
        # ===== 分支B：测试通过 =====
        log_to_file("="*70)
        log_to_file("分支 B：测试通过")
        log_to_file("="*70)
        
        log_to_file("\n接下来的操作:")
        log_to_file("1. 运行 python3 scripts/guard_bad_paths.py")
        log_to_file("2. 编写新的测试用例（不超过200行）")
        log_to_file("3. 如果有文件变动，git commit 提交信息为 '测试通过'")
        
        # 执行步骤1：运行 guard_bad_paths.py
        log_to_file("\n执行步骤1: python3 scripts/guard_bad_paths.py")
        stdout, stderr, code = run_subprocess(
            ['python3', 'scripts/guard_bad_paths.py'],
            cwd=project_dir,
            env=env
        )
        
        log_to_file("guard_bad_paths.py 输出:")
        log_to_file(stdout)
        if stderr:
            log_to_file(f"警告: {stderr}")
        
        log_to_file("\n" + "="*70)
        log_to_file("任务完成：测试通过")
        log_to_file("="*70)
        log_to_file("\n下一步需要：")
        log_to_file("- 编写新的测试用例（不超过200行）")
        log_to_file("- 如果有文件变动，git commit 提交信息为 '测试通过'")
        
        return 0

if __name__ == '__main__':
    try:
        exit_code = main()
        log_to_file(f"\n任务完成，退出码: {exit_code}")
        sys.exit(exit_code)
    except Exception as e:
        log_to_file(f"\n!!! 错误: {e} !!!")
        import traceback
        log_to_file(traceback.format_exc())
        sys.exit(2)
