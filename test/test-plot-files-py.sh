#!/bin/bash -ue 

DIR=$(cd $(dirname $BASH_SOURCE);pwd)

DAT=$DIR/test.dat
$(dirname $DIR)/plot-files.py \
  --files $DAT \
  --labels "\-,-,t,-,x,y,z,-" \
  --title "Calibrated acc GRACE-A 2008-08-01 arc-01" \
  --out $DIR/$(basename ${DAT%.dat})-plot-files-py \
  --x-label "seconds of day" \
  --y-label "[m/s^2]" \
  --grid \
  --debug \
  --psa \
  --logy \
  $@

  # --demean \
  # --force \
  # --point-size 0 \
  # --xticks integer \
