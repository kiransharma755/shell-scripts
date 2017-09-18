#!/bin/bash
FN="$1"

[[ -z ${FN} ]] && echo "specify a file " && exit 1

scp $FN oracle@10.183.122.64:/home/oracle/icob
scp $FN oracle@10.183.122.65:/home/oracle/icob
scp $FN oracle@10.183.122.66:/home/oracle/icob
scp $FN oracle@10.183.122.67:/home/oracle/icob
scp $FN oracle@192.168.9.102:/cellone/icob

