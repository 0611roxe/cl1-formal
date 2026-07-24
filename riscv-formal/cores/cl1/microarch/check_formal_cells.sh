#!/bin/sh
set -eu

assert_il=${1:--}
cover_il=${2:--}
policy=${3:-default}

assert_pattern='^[[:space:]]*parameter[[:space:]]+\\FLAVOR[[:space:]]+"assert"|^[[:space:]]*cell[[:space:]]+\$assert([[:space:]]|$)'
cover_pattern='^[[:space:]]*parameter[[:space:]]+\\FLAVOR[[:space:]]+"cover"|^[[:space:]]*cell[[:space:]]+\$cover([[:space:]]|$)'
forbidden_arith_pattern='^[[:space:]]*cell[[:space:]]+\$(mul|macc|div|mod|divfloor|modfloor)([[:space:]]|$)'

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
	check_cells assertion "$assert_il" "$assert_pattern"
fi

if [ "$cover_il" != "-" ]; then
	check_cells cover "$cover_il" "$cover_pattern"
fi

case $policy in
	default)
		;;
	no-arith)
		model_il=$assert_il
		if [ "$model_il" = "-" ]; then
			model_il=$cover_il
		fi
		if [ "$model_il" = "-" ] || [ ! -f "$model_il" ]; then
			echo "ERROR: no-arith policy requires a formal model" >&2
			exit 1
		fi
		if grep -Eq "$forbidden_arith_pattern" "$model_il"; then
			echo "ERROR: forbidden arithmetic cells found in '$model_il'" >&2
			exit 1
		fi
		echo "no forbidden arithmetic cells found ($model_il)"
		;;
	*)
		echo "ERROR: unknown formal-cell policy '$policy'" >&2
		exit 1
		;;
esac
