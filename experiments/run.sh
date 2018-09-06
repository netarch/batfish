#!/bin/bash

set -e

[ $UID -eq 0 ] && (echo '[!] Please run this script without root privilege' >&2; exit 1)
cd "$(dirname ${BASH_SOURCE[0]})"
. ../tools/batfish_functions.sh

usage() {
	echo "[!] Usage: $0 [OPTION]..." >&2
	echo "    Options:" >&2
	echo "        -h         display this message and exit" >&2
	echo "        -a         run all experiments (ignore option '-o')" >&2
	echo "        -o <1|2>   the number of iBGP origins (default: 1)" >&2
	echo "        -s <1-20>  the number of source nodes (default: 1)" >&2
}

ASes=(1221 1239 1755 3257 3967 6461)

origins=1
source_nodes=1
while getopts hao:s:t op; do
	case $op in
		a)
			all=1
			;;
		o)
			origins=$OPTARG
			[ $origins -ne 1 -a $origins -ne 2 ] && (usage; exit 1)
			;;
		s)
			source_nodes=$OPTARG
			[ $source_nodes -lt 1 -o $source_nodes -gt 20 ] && (usage; exit 1)
			;;
		t)
			test_exp=1
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
[ ${all:="0"} -eq 1 ] && origins=(1 2)
experiments=()
for o in ${origins[@]}; do
	[ $o -eq 1 ] && for AS in ${ASes[@]}; do experiments+=("rocketfuel-ibgp.AS-${AS}.single-origin"); done
	[ $o -eq 2 ] && for AS in ${ASes[@]}; do experiments+=("rocketfuel-ibgp.AS-${AS}.double-origin"); done
done
[ ${test_exp:="0"} -eq 1 ] && experiments=('simple-ibgp-test')

commands_template="
add-batfish-option haltonconverterror\n
add-batfish-option haltonparseerror\n
add-batfish-option loglevel fatal\n
add-batfish-option initinfo false\n
set-loglevel info\n
init-testrig <EXPERIMENT> smt-test\n
get smt-reachability ingressNodeRegex=\"R<IN>\", finalNodeRegex=\"R<FIN>\", dstIps=[\"8.0.0.1\"]"

## Run the experiments
for e in ${experiments[@]}; do
	nodes=$(ls $e/configs/ | wc -l)
	interval=$(($nodes / ($source_nodes + 1)))
	for i in $(seq 1 $source_nodes); do
		source_node=$(($interval * $i))
		echo -e "$commands_template" | sed -e "s/<EXPERIMENT>/$e/" -e "s/<IN>/$source_node/" -e "s/<FIN>/0/" > commands
		echo -n "[+] Verifying $e... "
		allinone -cmdfile commands >$e/verify.log 2>&1
		echo 'Done'
		rm -f commands
	done
done
