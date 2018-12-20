#!/bin/bash -e

[ $UID -eq 0 ] && (echo '[!] Please run this script without root privilege' >&2; exit 1)
cd "$(dirname ${BASH_SOURCE[0]})/.."
. tools/batfish_functions.sh

batfish_build_all
