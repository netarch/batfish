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

Ks=(4 6 8 10 12 14)

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

commands_header_template="
add-batfish-option haltonconverterror
add-batfish-option haltonparseerror
add-batfish-option loglevel fatal
add-batfish-option initinfo false
set-loglevel info
init-testrig <EXPERIMENT> smt-test"
commands_template="get smt-reachability failures=<FAIL>, useAbstraction=True, ingressNodeRegex=\"r<IN>\", finalNodeRegex=\"r<FIN>\", dstIps=[<DEST_IP>]"

## Run the experiments
## check reachability from the first edge node to all other edge nodes
for k in ${Ks[@]}; do
	e="fat-tree.${k}-ary"
	first_edge_node=$((3 * $k ** 2 / 4))
	second_edge_node=$(($first_edge_node + 1))
	last_edge_node=$((5 * $k ** 2 / 4 - 1))

	## Build the list of destination IPs
	DEST_IPS=""
	# 10.A.B.C
	A=0
	B=0
	C=1
	D=0
	while [ 1 ]; do
		DEST_IP="10.$A.$B.$C"
		NODE=$(basename "$(grep -rE "ip\s+address\s+\<$DEST_IP\>" \
			$e/configs | awk -F ':' '{print $1}')" \
			| sed -e 's/\.cfg//' -e 's/R//')
		[ -z "$NODE" ] && break

		[ $NODE -ge $second_edge_node -a $NODE -le $last_edge_node ] && {
			[ -n "$DEST_IPS" ] && DEST_IPS="$DEST_IPS, "
			DEST_IPS="$DEST_IPS\"$DEST_IP\""
		}

		D=$(($D + 1))
		[ $(($D % 2)) -eq 0 ] && C=$(($C + 2))
		C=$(($C + 1))
		[ $C -ge 256 ] && C=$(($C - 256)) && B=$(($B + 1))
		[ $B -ge 256 ] && B=$(($B - 256)) && A=$(($A + 1))
		[ $A -ge 256 ] && (echo 'error: IP out of range' >&2; exit 1)
	done

	## Build the regex for egress nodes (all other edge nodes)
	dest_nodes="($second_edge_node"
	for i in $(seq $(($second_edge_node + 1)) $last_edge_node); do
		dest_nodes="$dest_nodes|$i"
	done
	dest_nodes="$dest_nodes)"

	## Build commands
	echo "$commands_header_template" | sed \
		-e "s/<EXPERIMENT>/$e/" > commands
	echo "$commands_template" | sed \
		-e "s/<FAIL>/$max_fail/" \
		-e "s/<IN>/$first_edge_node/" \
		-e "s/<FIN>/$dest_nodes/" \
		-e "s/<DEST_IP>/$DEST_IPS/" >> commands

	echo -n "[+] Verifying $e... "
	allinone -cmdfile commands >$e/verify.reachability.bonsai.${max_fail}-failures.log 2>&1
	exit_code=$?
	if [ $exit_code -eq 0 ]; then
		echo 'Done'
	else
		echo "Failed (exit code: $exit_code)"
	fi
	rm -f commands
done
