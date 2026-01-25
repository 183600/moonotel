#!/usr/bin/env python3
import subprocess
import sys

print("=== Running guard_bad_paths.py ===")
result = subprocess.run(
    ['python3', '/home/engine/project/scripts/guard_bad_paths.py'],
    cwd='/home/engine/project',
    capture_output=True,
    text=True
)
print(result.stdout)
if result.stderr:
    print("Stderr:", result.stderr)
print(f"Exit code: {result.returncode}")
sys.exit(result.returncode)
