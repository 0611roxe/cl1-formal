#!/usr/bin/env bash

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_DIR="${SCRIPT_DIR}/checks"

if [[ ! -d "$CHECK_DIR" ]]; then
  echo "ERROR: checks dir not found: $CHECK_DIR" >&2
  echo "       Run 'python3 ../../checks/genchecks.py' first." >&2
  exit 2
fi

filter="${1:-.}"

pass=0; fail=0; unknown=0; missing=0
rows=()

shopt -s nullglob
for d in "$CHECK_DIR"/*/; do
  name="$(basename "$d")"
  [[ "$name" =~ $filter ]] || continue

  if [[ -f "$d/status" ]]; then
    read -r st _ secs _ < "$d/status" || true
    secs="${secs:--}"
  else
    st="--"; secs="-"
  fi

  case "$st" in
    PASS)    pass=$((pass+1)) ;;
    FAIL)    fail=$((fail+1)) ;;
    UNKNOWN) unknown=$((unknown+1)) ;;
    *)       missing=$((missing+1)); st="--" ;;
  esac

  rows+=("$(printf '%-8s %8s  %s' "$st" "$secs" "$name")")
done

if [[ ${#rows[@]} -eq 0 ]]; then
  echo "No checks match filter: $filter"
  exit 2
fi

printf '%-8s %8s  %s\n' STATUS TIME CHECK
printf '%-8s %8s  %s\n' ------ ---- -----
printf '%s\n' "${rows[@]}" | sort

total=${#rows[@]}
echo
printf 'Total: %d   PASS: %d   FAIL: %d   UNKNOWN: %d   (never ran): %d\n' \
  "$total" "$pass" "$fail" "$unknown" "$missing"

[[ $fail -eq 0 && $unknown -eq 0 && $missing -eq 0 ]]
