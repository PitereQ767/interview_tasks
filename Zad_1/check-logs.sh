#!/bin/bash

set -euo pipefail

dir="${1:-.}"

if [ ! -d "$dir" ]; then
  echo "Directory doesn't exist: $dir" >&2
  exit 2
fi

matches=""
grep_status=0

matches=$(grep -r -h --include='*.log' 'ERROR' "$dir") || grep_status=$?

if (( grep_status == 1 )); then
  count_errors=0
elif (( grep_status != 0 )); then
  echo "grep failed with exit code: $grep_status" >&2
  exit "$grep_status"
else
  count_errors=$(printf '%s\n' "$matches" | wc -l)
fi

echo "ERROR lines found: $count_errors"

if (( count_errors > 0 )); then
  exit 1
fi

exit 0
