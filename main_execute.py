#!/usr/bin/env python3
"""
严格按照指定逻辑执行的脚本
"""
import subprocess
import os
import sys
import time

def set_env():
    """设置环境变量"""
    env = os.environ.copy()
    moon_bin = os.path.expanduser('~/.moon/bin')
    env['PATH'] = moon_bin + ':' + env.get('PATH', '')
    env['PAGER'] = 'cat'  # 避免分页器
    env['GIT_PAGER'] = 'cat'
    return env

def run_cmd(cmd, shell=False, timeout=180, cwd=None):
    """运行命令"""
    result = subprocess.run(
        cmd,
        shell=shell,
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=cwd,
        env=set_env()
    )
    return result.stdout, result.stderr, result.returncode

def log(msg):
    """输出日志"""
    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] {msg}")

def main():
    log("="*70)
    log("开始执行任务")
    log("="*70)
    
    project_dir = '/home/engine/project'
    
    # 第一步：等待1分钟，然后运行git pull
    # 这个步骤已经在脚本开始前完成了（等待1分钟）
    log("\n[第一步] Git pull - 已完成")
    
    # 第二步：配置 moonbit 环境
    log("\n[第二步] 配置 moonbit 环境")
    
    # 检查 moon
    stdout, stderr, code = run_cmd(['which', 'moon'])
    if code == 0:
        log(f"Moon 已安装: {stdout.strip()}")
    else:
        log("Moon 未安装，正在安装...")
        stdout, stderr, code = run_cmd(
            'curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash',
            shell=True,
            timeout=60
        )
        if code == 0:
            log("Moon 安装成功")
        else:
            log(f"Moon 安装失败: {stderr}")
            return 2
    
    # 显示 moon 版本
    stdout, stderr, code = run_cmd(['moon', '--version'], timeout=30)
    if code == 0:
        log(f"Moon 版本: {stdout.strip()}")
    
    # 第三步：执行命令 moon test
    log("\n[第三步] 执行 moon test")
    log("（这可能需要一些时间...）")
    
    stdout, stderr, code = run_cmd(['moon', 'test'], timeout=180, cwd=project_dir)
    
    full_output = stdout + stderr
    
    # 保存输出
    output_file = '/tmp/moon_test_output.txt'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(f"退出码: {code}\n")
        f.write(f"\n{'='*70}\nSTDOUT:\n{'='*70}\n")
        f.write(stdout)
        f.write(f"\n{'='*70}\nSTDERR:\n{'='*70}\n")
        f.write(stderr)
    
    # 显示部分输出
    lines = stdout.split('\n')
    log(f"\n测试输出（前100行）:")
    for i, line in enumerate(lines[:100], 1):
        print(f"{i:4d}: {line}")
    
    if len(lines) > 100:
        log(f"... (共 {len(lines)} 行)")
    
    log(f"\n完整输出已保存到: {output_file}")
    
    # 第四步：分支逻辑
    log("\n[第四步] 分析测试结果")
    
    has_error = any(kw in full_output.lower() for kw in ['error', 'fatal', 'panic'])
    test_failed = has_error or code != 0
    
    if test_failed:
        # 分支 A：测试失败
        log("="*70)
        log("分支 A：测试失败（或日志包含 error/fatal/panic）")
        log("="*70)
        
        if has_error:
            log(f"✓ 检测到关键词: error/fatal/panic")
        if code != 0:
            log(f"✓ 退出码非零: {code}")
        
        log("\n需要执行:")
        log("1. 检查并消除代码中的死循环")
        log("2. 修复导致失败的问题（只修改业务代码，不修改测试代码）")
        log("3. 运行 python3 scripts/guard_bad_paths.py 清理乱码路径")
        
        return 1
    else:
        # 分支 B：测试通过
        log("="*70)
        log("分支 B：测试通过")
        log("="*70)
        
        log("\n需要执行:")
        log("1. 运行 python3 scripts/guard_bad_paths.py")
        log("2. 编写新测试用例（不超过200行）")
        log("3. 如果有文件变动，git commit 提交信息为 '测试通过'")
        
        # 执行步骤1：运行 guard_bad_paths.py
        log("\n执行步骤1: python3 scripts/guard_bad_paths.py")
        stdout, stderr, code = run_cmd(['python3', 'scripts/guard_bad_paths.py'], cwd=project_dir)
        log(stdout)
        if stderr:
            log(f"警告: {stderr}")
        
        return 0

if __name__ == '__main__':
    try:
        exit_code = main()
        log(f"\n任务完成，退出码: {exit_code}")
        sys.exit(exit_code)
    except subprocess.TimeoutExpired:
        log("错误: 命令执行超时")
        sys.exit(2)
    except Exception as e:
        log(f"错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(2)
