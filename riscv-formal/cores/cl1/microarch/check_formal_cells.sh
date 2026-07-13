#!/bin/sh
set -eu

assert_il=${1:--}
cover_il=${2:--}
assert_pattern='^[[:space:]]*parameter[[:space:]]+\\FLAVOR[[:space:]]+"assert"|^[[:space:]]*cell[[:space:]]+\$assert([[:space:]]|$)'
cover_pattern='^[[:space:]]*parameter[[:space:]]+\\FLAVOR[[:space:]]+"cover"|^[[:space:]]*cell[[:space:]]+\$cover([[:space:]]|$)'

check_cells() {
    kind=$1
    il_file=$2
    pattern=$3

    if [ ! -f "$il_file" ]; then
        echo "ERROR: missing formal model '$il_file'" >&2
        return 1
    fi

    count=$(grep -E "$pattern" "$il_file" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -eq 0 ]; then
        echo "ERROR: no formal $kind cells found in '$il_file'" >&2
        return 1
    fi

    echo "formal $kind cells found: $count ($il_file)"
}

if [ "$assert_il" != "-" ]; then
    # Newer Yosys versions use a generic $check cell for every formal flavor.
    # Match its FLAVOR parameter, not $check itself, or assume/cover-only models
    # would be misreported as containing assertions.
    check_cells assertion "$assert_il" "$assert_pattern"
fi

if [ "$cover_il" != "-" ]; then
    check_cells cover "$cover_il" "$cover_pattern"
fi
