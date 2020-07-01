#!/bin/bash -ue 

DIR=$(cd $(dirname $BASH_SOURCE);pwd)

DAT=$DIR/test2.dat
$(dirname $DIR)/plot-files.sh \
  --files $DAT \
  --labels "t,$(head -n1 $DAT | awk '{for(i=2;i<=NF-1;i++){printf("%s,",$i)};printf("%s",$NF);}' )" \
  --title "$DAT" \
  --out $DIR/$(basename ${DAT%.dat})-plot-files \
  --force \
  --point-size 1 \
  --set-key rmargin \
  --plot-style points \
  --xticks dates --x-date-data %Y/%m --x-date-format %y-%m \
  --y-label "count" \
  $@

exit

DAT=$DIR/test.dat
$(dirname $DIR)/plot-files.sh \
  --files $DAT \
  --labels "-,-,t,-,x,y,z,-" \
  --title "Calibrated acc GRACE-A 2008-08-01 arc-01" \
  --out $DIR/$(basename ${DAT%.dat})-plot-files \
  --demean \
  --force \
  --point-size 0 \
  --xticks integer \
  --x-label "seconds of day" \
  --y-label "[m/s^2]" \
  $@