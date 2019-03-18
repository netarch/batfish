#!/bin/bash

[ $UID -eq 0 ] && (echo '[!] Please run this script without root privilege' >&2; exit 1)
cd "$(dirname ${BASH_SOURCE[0]})/.."
. ../tools/batfish_functions.sh

usage() {
	echo "[!] Usage: $0 [OPTION]..." >&2
	echo "    Options:" >&2
	echo "        -h         display this message and exit" >&2
	echo "        -f N       maximum number of failures (default: 1)" >&2
	echo "        -t         tested policy (\"loop\" or \"reachability\" or \"path-length\", default: \"loop\")" >&2
	echo "        -s         single destination (only for \"reachability\" or \"path-length\" tests, default: off)" >&2
	echo "        -b         enable bonsai (default: off)" >&2
}

Ks=(4 6 8 10 12 14 20)

max_fail=1
question="loop"
single_dest=false
bonsai=false
while getopts hf:t:sb op; do
	case $op in
		f)
			max_fail=$OPTARG
			;;
		t)
			question="$OPTARG"
			[ "$question" != "loop" -a \
				"$question" != "reachability" -a \
                                        "$question" != "path-length" ] && {
				usage
				exit 1
			}
			;;
		s)
			single_dest=true
			;;
		b)
			bonsai=true
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

commands_template="
add-batfish-option haltonconverterror
add-batfish-option haltonparseerror
add-batfish-option loglevel fatal
add-batfish-option initinfo false
set-loglevel info
init-testrig <EXPERIMENT> <EXPERIMENT>
"
if [ "$question" = "loop" ]; then
	commands_template+="get smt-routing-loop failures=<FAIL>, fullModel=True"
elif [ "$question" = "path-length" ]; then
	commands_template+="get smt-bounded-length failures=<FAIL>, bound=4, fullModel=True, ingressNodeRegex=\"r<IN>\", finalNodeRegex=\"r<FIN>\", dstIps=[<DEST_IP>]"
else
	commands_template+="get smt-reachability failures=<FAIL>, ingressNodeRegex=\"r<IN>\", finalNodeRegex=\"r<FIN>\", dstIps=[<DEST_IP>]"
fi
if $bonsai; then
	commands_template+=", useAbstraction=True"
fi

## Run the experiments
for k in ${Ks[@]}; do
	e="fat-tree.${k}-ary"

	if [ "$question" = "reachability" ] || [ "$question" = "path-length" ]; then
		first_edge_node=$((3 * $k ** 2 / 4))
		second_edge_node=$(($first_edge_node + 1))
		last_edge_node=$((5 * $k ** 2 / 4 - 1))

		## Build the regex for egress nodes
		if $single_dest; then
			## the last edge node
			dest_nodes="$last_edge_node"
		else
			## all other edge nodes
			dest_nodes="($second_edge_node"
			for i in $(seq $(($second_edge_node + 1)) $last_edge_node); do
				dest_nodes="$dest_nodes|$i"
			done
			dest_nodes="$dest_nodes)"
		fi

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

			if $single_dest; then
				## match the last edge node
				[ $NODE -eq $last_edge_node ] && {
					[ -n "$DEST_IPS" ] && DEST_IPS="$DEST_IPS, "
					DEST_IPS="$DEST_IPS\"$DEST_IP\""
				}
			else
				## match all the other edge nodes
				[ $NODE -ge $second_edge_node -a $NODE -le $last_edge_node ] && {
					[ -n "$DEST_IPS" ] && DEST_IPS="$DEST_IPS, "
					DEST_IPS="$DEST_IPS\"$DEST_IP\""
				}
			fi

			D=$(($D + 1))
			[ $(($D % 2)) -eq 0 ] && C=$(($C + 2))
			C=$(($C + 1))
			[ $C -ge 256 ] && C=$(($C - 256)) && B=$(($B + 1))
			[ $B -ge 256 ] && B=$(($B - 256)) && A=$(($A + 1))
			[ $A -ge 256 ] && (echo 'error: IP out of range' >&2; exit 1)
		done
	fi

	## Build commands
	echo "$commands_template" | sed \
		-e "s/<EXPERIMENT>/$e/g" \
		-e "s/<FAIL>/$max_fail/" \
		-e "s/<IN>/$first_edge_node/" \
		-e "s/<FIN>/$dest_nodes/" \
		-e "s/<DEST_IP>/$DEST_IPS/" > "$e/commands"

	## Run commands
	echo -n "[+] Verifying $e... "
	if [ "$question" = "loop" ]; then
		log_file="$e/verify.loop"
	elif [ "$question" = "path-length" ]; then
		log_file="$e/verify.path-length"
		if $single_dest; then log_file+=".single_destination"; fi
	else
		log_file="$e/verify.reachability"
		if $single_dest; then log_file+=".single_destination"; fi
	fi
	if $bonsai; then log_file+=".bonsai"; fi
	log_file+=".${max_fail}-failures.log"
	allinone -cmdfile "$e/commands" >"$log_file" 2>&1
	exit_code=$?
	if [ $exit_code -eq 0 ]; then
		echo 'Done'
	else
		echo "Failed (exit code: $exit_code)"
	fi
done
