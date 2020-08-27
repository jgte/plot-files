#!/bin/bash -ue

DIR=$(cd $(dirname $BASH_SOURCE);pwd)
DAT=$DIR/test.dat

# std test
# NOTICE: the std values below were derived with:
# file-stats.awk test.dat | grep std: | awk '{print $6,$7,$8}'
STDx=5.29369e-09
STDy=8.47663e-09
STDz=9.18032e-09
DAT2=$DIR/test2.dat
awk '{print $3,$5,'$STDx',$6,'$STDy',$7,'$STDz'}' $DAT > $DAT2
ARGS=(
  --files $DAT2
  --labels t,x,std,y,std,z,std
  --title "Calibrated acc GRACE-A 2008-08-01 arc-01"
  --x-label "seconds of day"
  --y-label "[m/s^2]"
  --grid
  $@
)
#NOTICE: need to retrieve the automatic file name because $@ can include --demean,
#        which would be ignored since --out is set explicitly to make sure this plot
#        is not over-written by further tests
OUT=$($(dirname $DIR)/plot-files.py "${ARGS[@]}" --out-name)
$(dirname $DIR)/plot-files.py "${ARGS[@]}" \
  --debug \
  --timing \
  --out ${OUT%.png}.std.png

# --psa test
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

# --diff test
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


# --html test
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
  $@

  # --demean \
  # --point-size 0 \
  # --xticks integer \
