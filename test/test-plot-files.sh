#!/bin/bash -ue 

DIR=$(cd $(dirname $BASH_SOURCE);pwd)
DAT=$DIR/test.dat

$(dirname $DIR)/plot-files.sh $DAT -labels="-,-,t,-,x,y,z,-" \
  -title="Calibrated acc GRACE-A 2008-08-01 arc-01" \
  -out=$DIR/$(basename ${DAT%.dat}) demean force -point-size=0 \
  -xticks=integer -xlabel="seconds of day" -ylabel="[m/s^2]" $@