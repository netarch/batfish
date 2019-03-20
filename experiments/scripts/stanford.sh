#!/bin/bash

[ $UID -eq 0 ] && (echo '[!] Please run this script without root privilege' >&2; exit 1)
cd "$(dirname ${BASH_SOURCE[0]})/.."
. ../tools/batfish_functions.sh

usage() {
	echo "[!] Usage: $0 [OPTION]..." >&2
	echo "    Options:" >&2
	echo "        -h         display this message and exit" >&2
	echo "        -f N       maximum number of failures (default: 0)" >&2
	echo "        -t         tested policy (\"loop\" or \"reachability\" or \"path-length\", default: \"loop\")" >&2
	echo "        -b         enable bonsai (default: off)" >&2
}

max_fail=0
question="loop"
bonsai=false
while getopts hf:t:b op; do
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
	commands_template+="get smt-bounded-length failures=<FAIL>, bound=4, fullModel=True, ingressNodeRegex=\"<IN>\", finalNodeRegex=\"<FIN>\", dstIps=[<DEST_IP>]"
else
	commands_template+="get smt-reachability failures=<FAIL>, ingressNodeRegex=\"<IN>\", finalNodeRegex=\"<FIN>\", dstIps=[<DEST_IP>]"
fi
if $bonsai; then
	commands_template+=", useAbstraction=True"
fi

## Run the experiments
experiment="stanford"

if [ "$question" = "reachability" ] || [ "$question" = "path-length" ]; then
	ingress_node="boza_rtr_config"
	egress_node="bbra_rtr_config"
	DEST_IPS="171.64.1.52"
fi

## Build commands
echo "$commands_template" | sed \
	-e "s/<EXPERIMENT>/$experiment/g" \
	-e "s/<FAIL>/$max_fail/" \
	-e "s/<IN>/$ingress_node/" \
	-e "s/<FIN>/$egress_node/" \
	-e "s/<DEST_IP>/$DEST_IPS/" > "$experiment/commands"

## Run commands
echo -n "[+] Verifying $experiment... "
if [ "$question" = "loop" ]; then
	log_file="$experiment/verify.loop"
elif [ "$question" = "path-length" ]; then
	log_file="$experiment/verify.path-length"
	log_file+=".single-destination"
else
	log_file="$experiment/verify.reachability"
	log_file+=".single-destination"
fi
if $bonsai; then log_file+=".bonsai"; fi
log_file+=".${max_fail}-failures.log"
allinone -cmdfile "$experiment/commands" >"$log_file" 2>&1
exit_code=$?
if [ $exit_code -eq 0 ]; then
	echo 'Done'
else
	echo "Failed (exit code: $exit_code)"
fi
