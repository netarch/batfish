#!/bin/bash

[ $UID -eq 0 ] && (echo '[!] Please run this script without root privilege' >&2; exit 1)
cd "$(dirname ${BASH_SOURCE[0]})"
. ../tools/batfish_functions.sh

usage() {
	echo "[!] Usage: $0 [OPTION]..." >&2
	echo "    Options:" >&2
	echo "        -h         display this message and exit" >&2
	echo "        -f N       maximum number of failures (default: 1)" >&2
}

ASes=(1221 1239 1755 3257 3967 6461)

max_fail=1
while getopts hf: op; do
	case $op in
		f)
			max_fail=$OPTARG
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
for AS in ${ASes[@]}; do experiments+=("rocketfuel.AS-${AS}"); done

commands_header_template="
add-batfish-option haltonconverterror
add-batfish-option haltonparseerror
add-batfish-option loglevel fatal
add-batfish-option initinfo false
set-loglevel info
init-testrig <EXPERIMENT> smt-test"
commands_template="get smt-reachability failures=<FAIL>, ingressNodeRegex=\"R<IN>\", finalNodeRegex=\"R<FIN>\", dstIps=[\"<DEST_IP>\"]"

## Run the experiments
for e in ${experiments[@]}; do
	echo "$commands_header_template" | sed \
		-e "s/<EXPERIMENT>/$e/" > commands
	# 10.A.B.C
	A=0
	B=0
	C=1
	D=0
	while [ 1 ]; do
		DEST_IP="10.$A.$B.$C"
		NODE=$(basename "$(grep -rE "\<$DEST_IP\>" $e | awk -F ':' '{print $1}')" | sed -e 's/\.cfg//' -e 's/R//')
		[ -z "$NODE" ] && break
		echo "$commands_template" | sed \
			-e "s/<FAIL>/$max_fail/" \
			-e "s/<IN>/*/" \
			-e "s/<FIN>/$NODE/" \
			-e "s/<DEST_IP>/$DEST_IP/" >> commands
		D=$(($D + 1))
		[ $(($D % 2)) -eq 0 ] && C=$(($C + 2))
		C=$(($C + 1))
		[ $C -ge 256 ] && C=$(($C - 256)) && B=$(($B + 1))
		[ $B -ge 256 ] && B=$(($B - 256)) && A=$(($A + 1))
		[ $A -ge 256 ] && (echo 'error: IP out of range' >&2; exit 1)
	done
	echo -n "[+] Verifying $e... "
	allinone -cmdfile commands >$e/verify.${max_fail}-failures.log 2>&1
	exit_code=$?
	if [ $exit_code -eq 0 ]; then
		echo 'Done'
	else
		echo "Faied (exit code: $exit_code)"
	fi
	rm -f commands
done
