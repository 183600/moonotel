#!/usr/bin/env python3
"""
完全自动化脚本，严格按照指定流程执行任务
"""
import subprocess
import os
import sys
import time
from pathlib import Path

# 配置
PROJECT_DIR = Path('/home/engine/project')
MOON_BIN = Path.home() / '.moon/bin'
OUTPUT_FILE = Path('/tmp/moon_automation_output.txt')
LOG_FILE = Path('/tmp/moon_automation.log')

def log(message):
    """记录日志"""
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - {message}\n")
    print(message)

def run_command(cmd, cwd=PROJECT_DIR, timeout=120):
    """运行命令并返回结果"""
    env = os.environ.copy()
    env['PATH'] = str(MOON_BIN) + ':' + env.get('PATH', '')

    result = subprocess.run(
        cmd,
        shell=True,
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env
    )

    return result.stdout, result.stderr, result.returncode

def main():
    log("=" * 80)
    log("开始执行自动化任务")
    log("=" * 80)

    # 清空输出文件
    OUTPUT_FILE.write_text('', encoding='utf-8')

    # 第一步：Git pull（已经在开始时完成）
    log("\n[第一步] Git pull - 已完成")

    # 第二步：配置 moonbit 环境
    log("\n[第二步] 配置 moonbit 环境...")

    # 检查 moon 是否已安装
    log("检查 moon 是否已安装...")
    stdout, stderr, code = run_command('which moon')
    moon_exists = code == 0 and stdout.strip()

    if not moon_exists:
        log("Moon 未安装，正在安装...")
        install_cmd = 'curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash'
        stdout, stderr, code = run_command(install_cmd, timeout=60)
        log(f"安装输出:\n{stdout}")
        if stderr:
            log(f"安装错误:\n{stderr}")
    else:
        log(f"Moon 已安装在: {stdout.strip()}")

    # 检查 moon 版本
    log("\n检查 Moon 版本...")
    stdout, stderr, code = run_command('moon --version')
    if code == 0:
        log(f"Moon 版本: {stdout.strip()}")
    else:
        log(f"无法获取 Moon 版本: {stderr}")

    # 第三步：执行 moon test
    log("\n[第三步] 执行 moon test...")
    log("等待测试完成（可能需要一些时间）...")

    stdout, stderr, code = run_command('moon test', timeout=180)

    # 保存输出
    full_output = f"Exit Code: {code}\n\nSTDOUT:\n{stdout}\n\nSTDERR:\n{stderr}"
    OUTPUT_FILE.write_text(full_output, encoding='utf-8')

    log(f"\n测试退出码: {code}")
    log(f"测试输出长度: {len(stdout) + len(stderr)} 字符")

    # 第四步：分析结果
    log("\n[第四步] 分析测试结果...")

    combined_output = (stdout + stderr).lower()
    error_keywords = ['error', 'fatal', 'panic']
    found_keywords = [kw for kw in error_keywords if kw in combined_output]

    test_failed = code != 0 or found_keywords

    if test_failed:
        log("=" * 80)
        log("=== 分支 A：测试失败 ===")
        log("=" * 80)

        if found_keywords:
            log(f"在输出中找到关键词: {', '.join(found_keywords)}")
        if code != 0:
            log(f"测试返回非零退出码: {code}")

        log("\n接下来的操作：")
        log("1. 检查并消除代码中的死循环")
        log("2. 修复导致失败的问题（只修改业务代码，不修改测试代码）")
        log("3. 运行 python3 scripts/guard_bad_paths.py 清理乱码路径")

        log("\n" + "=" * 80)
        log("需要在代码中查找和修复问题")
        log("=" * 80)

        # 输出前500行的测试输出，帮助定位问题
        log("\n=== 测试输出（前500行）===")
        lines = (stdout + stderr).split('\n')
        for i, line in enumerate(lines[:500]):
            log(f"{i+1:4d}: {line}")

        return 1  # 返回1表示测试失败

    else:
        log("=" * 80)
        log("=== 分支 B：测试通过 ===")
        log("=" * 80)

        log("\n接下来的操作：")
        log("1. 运行 python3 scripts/guard_bad_paths.py")
        log("2. 编写新的测试用例（不超过200行）")
        log("3. 如果有文件变动，git commit 提交信息为 '测试通过'")

        log("\n执行步骤1：运行 guard_bad_paths.py...")
        stdout, stderr, code = run_command('python3 scripts/guard_bad_paths.py')
        log(f"guard_bad_paths.py 输出:\n{stdout}")
        if stderr:
            log(f"guard_bad_paths.py 错误:\n{stderr}")

        log("\n" + "=" * 80)
        log("测试通过！需要编写新测试用例...")
        log("=" * 80)

        return 0  # 返回0表示测试通过

if __name__ == '__main__':
    try:
        exit_code = main()
        sys.exit(exit_code)
    except Exception as e:
        log(f"\n!!! 脚本执行异常: {e} !!!")
        import traceback
        log(traceback.format_exc())
        sys.exit(2)
