#!/usr/bin/env bash
# Fail on placeholder metadata or throwaway agent/probe files.
set -euo pipefail

bad="$(
  git ls-files |
    grep -E '(^|/)(zz_|tmp_|_scratch_|dbg_|probe_)' || true
)"
if [[ -n "$bad" ]]; then
  echo "error: scratch/probe files must not be committed:" >&2
  echo "$bad" >&2
  exit 1
fi

if grep -q 'yourname/otel' README.md moon.mod PLAN.md 2>/dev/null; then
  echo "error: scaffold placeholder 'yourname/otel' remains in the metadata/docs" >&2
  exit 1
fi

if grep -q '^# yourname/' README.md; then
  echo "error: README still uses the scaffold title" >&2
  exit 1
fi

echo "repository hygiene: ok"
