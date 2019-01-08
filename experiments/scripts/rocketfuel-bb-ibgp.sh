#!/bin/bash

[ $UID -eq 0 ] && (echo '[!] Please run this script without root privilege' >&2; exit 1)
cd "$(dirname ${BASH_SOURCE[0]})/.."
. ../tools/batfish_functions.sh

usage() {
	echo "[!] Usage: $0 [OPTION]..." >&2
	echo "    Options:" >&2
	echo "        -h         display this message and exit" >&2
	echo "        -f N       maximum number of failures (default: 0)" >&2
	echo "        -s <1-20>  the number of source nodes (default: 1)" >&2
}

ASes=(1221 1239 1755 3257 3967 6461)

max_fail=0
source_nodes=1
while getopts hf:s: op; do
	case $op in
		f)
			max_fail=$OPTARG
			;;
		s)
			source_nodes=$OPTARG
			[ $source_nodes -lt 1 -o $source_nodes -gt 20 ] && (usage; exit 1)
			;;
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
for AS in ${ASes[@]}; do
	experiments+=("rocketfuel-ibgp.AS-${AS}.single-origin");
done

commands_template="
add-batfish-option haltonconverterror
add-batfish-option haltonparseerror
add-batfish-option loglevel fatal
add-batfish-option initinfo false
set-loglevel info
init-testrig <EXPERIMENT> <EXPERIMENT>
get smt-reachability failures=<FAIL>, ingressNodeRegex=\"r<IN>\", finalNodeRegex=\"r<FIN>\", dstIps=[\"<DEST_IP>\"]"

## Run the experiments
for e in ${experiments[@]}; do
	## Build commands
	nodes=$(ls $e/configs/ | wc -l)
	interval=$(($nodes / ($source_nodes + 1)))
	ingress_regex="($interval"
	for i in $(seq 2 $source_nodes); do
		source_node=$(($interval * $i))
		ingress_regex+="|$source_node"
	done
	ingress_regex+=")"
	echo "$commands_template" | sed \
		-e "s/<EXPERIMENT>/$e/g" \
		-e "s/<FAIL>/$max_fail/" \
		-e "s/<IN>/$ingress_regex/" \
		-e "s/<FIN>/0/" \
		-e "s/<DEST_IP>/8.0.0.1/" > "$e/commands" # r0 is the single ibgp origin

	## Run commands
	echo -n "[+] Verifying $e... "
	allinone -cmdfile "$e/commands" >"$e/verify.${source_nodes}-sources.${max_fail}-failures.log" 2>&1
	exit_code=$?
	if [ $exit_code -eq 0 ]; then
		echo 'Done'
	else
		echo "Failed (exit code: $exit_code)"
	fi
done
