#!/bin/bash -ue 

DIR=$(cd $(dirname $BASH_SOURCE);pwd)
DAT=$DIR/test.dat

$(dirname $DIR)/plot-hist.sh \
  --files <(awk '{print $5}' $DAT) \
  --title "Calibrated x-axis acc GRACE-A 2008-08-01 arc-01" \
  --out $DIR/$(basename ${DAT%.dat})-plot-hist \
  --force \
  --logy \
  --x-label "[m/s^2]" \
  $@