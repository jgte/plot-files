#!/bin/bash -ue

DIR=$(cd $(dirname $BASH_SOURCE);pwd)

DAT=$DIR/test.dat
$(dirname $DIR)/plot-files.py \
  --files $DAT \
  --labels "\-,-,t,-,x,y,z,-" \
  --title "Calibrated acc GRACE-A 2008-08-01 arc-01" \
  --x-label "seconds of day" \
  --y-label "[m/s^2]" \
  --grid \
  --debug \
  --timing \
  --psa \
  --logy \
  $@

$(dirname $DIR)/plot-files.py \
  --files $DAT \
  --labels "\-,-,t,-,x,y,z,-" \
  --title "Calibrated acc GRACE-A 2008-08-01 arc-01" \
  --x-label "seconds of day" \
  --y-label "[m/s^2]" \
  --grid \
  --debug \
  --timing \
  --diff \
  $@

#NOTICE: the std values below were derived with:
# file-stats.awk test.dat | grep std: | awk '{print $6,$7,$8}'
STDx=5.29369e-09
STDy=8.47663e-09
STDz=9.18032e-09
DAT2=$DIR/test2.dat
awk '{print $3,$5,'$STDx',$6,'$STDy',$7,'$STDz'}' $DAT > $DAT2
$(dirname $DIR)/plot-files.py \
  --files $DAT2 \
  --labels "t,x,std,y,std,z,std" \
  --title "Calibrated acc GRACE-A 2008-08-01 arc-01" \
  --x-label "seconds of day" \
  --y-label "[m/s^2]" \
  --grid \
  --debug \
  --timing \
  $@


$(dirname $DIR)/plot-files.py \
  --files $DAT \
  --labels "\-,-,t,-,x,y,z,-" \
  --title "Calibrated acc GRACE-A 2008-08-01 arc-01" \
  --x-label "seconds of day" \
  --y-label "[m/s^2]" \
  --grid \
  --debug \
  --timing \
  --html \
  --force \
  $@

  # --demean \
  # --point-size 0 \
  # --xticks integer \
