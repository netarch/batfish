#!/bin/bash

[ $UID -eq 0 ] && (echo '[!] Please run this script without root privilege' >&2; exit 1)
cd "$(dirname ${BASH_SOURCE[0]})"
. ../tools/batfish_functions.sh

usage() {
	echo "[!] Usage: $0 [OPTION]..." >&2
	echo "    Options:" >&2
	echo "        -h         display this message and exit" >&2
}

Ks=(4 6 8 10 12 14)

while getopts h op; do
	case $op in
		h)
			usage
			exit 0
			;;
		*)
			usage
			exit 1
			;;
	esac
done
experiments=()
for k in ${Ks[@]}; do experiments+=("fat-tree.fixed-static-route.${k}-ary"); done

commands_template="
add-batfish-option haltonconverterror
add-batfish-option haltonparseerror
add-batfish-option loglevel fatal
add-batfish-option initinfo false
set-loglevel info
init-testrig <EXPERIMENT> smt-test
get smt-routing-loop fullModel=True"

## Run the experiments
for e in ${experiments[@]}; do
	echo "$commands_template" | sed \
		-e "s/<EXPERIMENT>/$e/" > commands
	echo -n "[+] Verifying $e... "
	allinone -cmdfile commands >$e/verify.log 2>&1
	exit_code=$?
	if [ $exit_code -eq 0 ]; then
		echo 'Done'
	else
		echo "Faied (exit code: $exit_code)"
	fi
	rm -f commands
done
